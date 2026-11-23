// P17: ConfirmInboxBatch admission, all-or-none commit, receipt retry and
// whole-batch Undo (flow F07 steps 4-5; checks F07-B to F07-D).

import 'dart:convert';

import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/inbox.dart';
import 'package:contour/data/repositories/payments.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _account = '00000000-0000-7000-8000-0000000000a1';
const String _savings = '00000000-0000-7000-8000-0000000000a2';
const String _groceries = '00000000-0000-7000-8000-0000000000c1';

String _id(int n) => '00000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

Map<String, Object?> _proposal({
  int amountMinor = -3175,
  String currency = 'USD',
  String date = '2026-10-10',
  String accountId = _account,
  String kind = 'expense',
  String? merchant = 'PX Market',
  String? categoryId = _groceries,
  String? match,
}) =>
    <String, Object?>{
      'v': 1,
      'amountMinor': amountMinor,
      'currency': currency,
      'date': date,
      'accountId': accountId,
      'kind': kind,
      if (merchant != null) 'merchantName': merchant,
      if (categoryId != null) 'categoryId': categoryId,
      'splits': <Object?>[],
      'tagIds': <String>[],
      if (match != null) 'matchTransactionId': match,
    };

void main() {
  late Vault vault;
  late CommandRepository commands;
  late InboxRepository inbox;
  late PaymentRepository payments;
  var nowMs = 1700000000000;
  var entity = 0;
  var paymentIndex = 0;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newOperationId: () => _id(750 + paymentIndex),
    );
    inbox = InboxRepository(
      db: vault.database,
      commands: commands,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newEntityId: () {
        entity += 1;
        return _id(1000 + entity);
      },
    );
    payments = PaymentRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    entity = 0;
    paymentIndex = 0;
    await _seedReference(vault);
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  InboxRepository repositoryWith(InboxAdmissionLimits limits) =>
      InboxRepository(
        db: vault.database,
        commands: commands,
        clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
        newEntityId: () {
          entity += 1;
          return _id(1000 + entity);
        },
        limits: limits,
      );

  Future<int> seedItem({
    required int sourceId,
    required int receivedAt,
    Map<String, Object?>? proposal,
    String suggestionType = 'new',
    bool draftClaim = false,
    bool published = true,
    String batchStatus = 'review',
    String claimStatus = 'staged',
  }) async {
    final db = vault.database;
    await db.customStatement(
      'INSERT INTO source_identities (id, namespace, account_scope, '
      'source_record_id, identity_version, first_seen_at) '
      'VALUES (?, ?, ?, ?, 1, ?)',
      <Object?>[sourceId, 'localFile', 'acct', 'row-$sourceId', receivedAt],
    );
    int? stagedRowId;
    if (draftClaim) {
      final draftId = _id(500 + sourceId);
      await db.customStatement(
        'INSERT INTO draft_headers (id, form_type, schema_version, db_epoch, '
        'created_at, updated_at, edit_revision, status) '
        "VALUES (?, 'capture', 1, (SELECT db_epoch FROM db_state "
        "WHERE singleton = 1), ?, ?, 1, 'editing')",
        <Object?>[draftId, nowMs, nowMs],
      );
      await db.customStatement(
        'INSERT INTO source_claims (source_identity_id, batch_id, draft_id, '
        'status) VALUES (?, NULL, ?, ?)',
        <Object?>[sourceId, draftId, claimStatus],
      );
    } else {
      final batchId = 'batch-$sourceId';
      await db.customStatement(
        'INSERT INTO import_batches (id, parse_config_id, source, '
        'file_digest, parser_id, parser_version, template_version, created_at, '
        'status, row_count, parsed_cursor, safe_error_code, '
        'payload_schema_version, inbox_published) '
        "VALUES (?, 'config', 'localFile', NULL, 'csv', 1, NULL, 1, ?, "
        '0, NULL, NULL, 1, ?)',
        <Object?>[batchId, batchStatus, published ? 1 : 0],
      );
      stagedRowId = 1000 + sourceId;
      await db.customStatement(
        'INSERT INTO staged_rows (id, batch_id, row_ordinal, '
        'source_identity_id, payload_json, payload_schema_version) '
        'VALUES (?, ?, ?, ?, ?, 1)',
        <Object?>[stagedRowId, batchId, sourceId, sourceId, '{}'],
      );
      await db.customStatement(
        'INSERT INTO source_claims (source_identity_id, batch_id, draft_id, '
        'status) VALUES (?, ?, NULL, ?)',
        <Object?>[sourceId, batchId, claimStatus],
      );
    }
    await db.customStatement(
      'INSERT INTO inbox_items (source_identity_id, staged_row_id, '
      'received_at, suggestion_type, payload_schema_version, proposed_json, '
      'decision, edit_revision) VALUES (?, ?, ?, ?, 1, ?, ?, 1)',
      <Object?>[
        sourceId,
        stagedRowId,
        receivedAt,
        suggestionType,
        jsonEncode(proposal ?? _proposal()),
        'pending',
      ],
    );
    final row = await db.customSelect(
      'SELECT id FROM inbox_items WHERE source_identity_id = ?',
      variables: <Variable<Object>>[Variable(sourceId)],
    ).getSingle();
    return row.data['id'] as int;
  }

  Future<String> createPayment({
    required int amountMinor,
    String accountId = _account,
    String kind = 'expense',
  }) async {
    paymentIndex += 1;
    final id = _id(20 + paymentIndex);
    final event = _id(40 + paymentIndex);
    final plan = payments.planCreate(
      NewPayment(
        id: id,
        eventId: event,
        accountId: accountId,
        date: '2026-10-05',
        amountMinor: amountMinor,
        currency: 'USD',
        kind: kind,
        merchantName: 'Existing',
        categoryId: _groceries,
      ),
    );
    final operation = _id(700 + paymentIndex);
    await commands.prepare(
      operationId: operation,
      commandType: 'payment.create',
      draftId: _id(600 + paymentIndex),
      formType: 'payment',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    await commands.execute(
      operationId: operation,
      changes: plan.changes,
      effects: plan.apply,
      resultJson: '{}',
    );
    return id;
  }

  Future<InboxConfirmResult> confirm(
    List<int> ids, {
    String operation = 'op-1',
    String batch = 'batch-1',
  }) =>
      inbox.confirmBatch(
        operationId: operation,
        selectedIds: ids.toSet(),
        batchId: batch,
      );

  Future<int> count(String table, {String where = ''}) async {
    final row = await vault.database
        .customSelect(
          'SELECT count(*) AS n FROM $table ${where.isEmpty ? '' : 'WHERE $where'}',
        )
        .getSingle();
    return row.data['n'] as int;
  }

  test('a Confirm writes every selected effect in one command', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    final two = await seedItem(
      sourceId: 2,
      receivedAt: 200,
      proposal: _proposal(amountMinor: -8045),
    );

    final result = await confirm(<int>[one, two]);

    expect(result.created, 2);
    expect(result.linked, 0);
    expect(result.selection.count, 2);
    expect(result.selection.byCurrency['USD']!.netMinor, -11220);
    expect(result.selection.byCurrency['USD']!.outMinor, 11220);
    expect(result.commitSequence, 1);
    expect(result.readRevision, 1);

    expect(await count('transactions'), 2);
    expect(await count('financial_events'), 2);
    expect(await count('change_log'), 4);
    expect(await count('staged_rows'), 0);
    expect(await count('source_event_links'), 0);

    final items = await vault.database
        .customSelect(
          'SELECT decision, operation_id, proposed_json, staged_row_id '
          'FROM inbox_items',
        )
        .get();
    for (final row in items) {
      expect(row.data['decision'], 'accepted');
      expect(row.data['operation_id'], 'op-1');
      expect(row.data['proposed_json'], isNull);
      expect(row.data['staged_row_id'], isNull);
    }
    final claims = await vault.database
        .customSelect('SELECT status, decided_operation_id FROM source_claims')
        .get();
    for (final row in claims) {
      expect(row.data['status'], 'accepted');
      expect(row.data['decided_operation_id'], 'op-1');
    }
    final revision = await vault.database
        .customSelect('SELECT revision FROM dependency_revisions')
        .getSingle();
    expect(revision.data['revision'], 1);
    expect(await inbox.pendingCount(), 0);
  });

  test('F07-C: one invalid row rolls back the whole batch', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    final two = await seedItem(
      sourceId: 2,
      receivedAt: 200,
      proposal: _proposal(amountMinor: -8045, accountId: _id(999)),
    );

    await expectLater(
      confirm(<int>[one, two]),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.invalidProposal,
        ),
      ),
    );

    expect(await count('transactions'), 0);
    expect(await count('financial_events'), 0);
    expect(await count('change_log'), 0);
    expect(await count('operation_receipts'), 0);
    expect(await count('operation_intents'), 1);
    expect(await count('staged_rows'), 2);
    expect(await inbox.pendingCount(), 2);
    final claims = await vault.database
        .customSelect('SELECT status FROM source_claims')
        .get();
    for (final row in claims) {
      expect(row.data['status'], 'staged');
    }
    final revision = await vault.database
        .customSelect('SELECT read_revision FROM db_state')
        .getSingle();
    expect(revision.data['read_revision'], 0);
  });

  test('F07-D: a repeated Confirm returns its receipt', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    final two = await seedItem(sourceId: 2, receivedAt: 200);

    final first = await confirm(<int>[one, two]);
    final second = await confirm(<int>[one, two]);

    expect(second.commitSequence, first.commitSequence);
    expect(second.selection.count, first.selection.count);
    expect(second.created, first.created);
    expect(await count('transactions'), 2);
    expect(await count('operation_receipts'), 1);
    expect(await count('operation_intents'), 1);

    await expectLater(
      confirm(<int>[one], operation: 'op-1'),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.replayMismatch,
        ),
      ),
    );
    expect(await count('transactions'), 2);
  });

  test('a new operation on decided items writes no second event', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    await confirm(<int>[one]);

    await expectLater(
      confirm(<int>[one], operation: 'op-2'),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.notEligible,
        ),
      ),
    );
    expect(await count('transactions'), 1);
    expect(await count('operation_receipts'), 1);
  });

  test('unticked rows stay pending', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    final two = await seedItem(sourceId: 2, receivedAt: 200);

    await confirm(<int>[one]);

    expect(await inbox.pendingCount(), 1);
    final item = await inbox.item(two);
    expect(item, isNotNull);
    final claim = await vault.database
        .customSelect(
          'SELECT status FROM source_claims WHERE source_identity_id = 2',
        )
        .getSingle();
    expect(claim.data['status'], 'staged');
    expect(await count('staged_rows'), 1);
  });

  test('over-limit keeps every draft and changes nothing', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    final two = await seedItem(sourceId: 2, receivedAt: 200);

    final rows = repositoryWith(
      const InboxAdmissionLimits(maxSelectedRows: 1),
    );
    await expectLater(
      rows.confirmBatch(operationId: 'op-rows', selectedIds: <int>{one, two}),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.admissionRows,
        ),
      ),
    );

    final effects = repositoryWith(
      const InboxAdmissionLimits(maxLogicalEffects: 5),
    );
    await expectLater(
      effects.confirmBatch(operationId: 'op-effects', selectedIds: <int>{one}),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.admissionEffects,
        ),
      ),
    );

    final plan = repositoryWith(
      const InboxAdmissionLimits(maxPlanBytes: 10),
    );
    await expectLater(
      plan.confirmBatch(operationId: 'op-plan', selectedIds: <int>{one}),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.admissionPlan,
        ),
      ),
    );

    expect(await count('transactions'), 0);
    expect(await count('operation_intents'), 0);
    expect(await count('operation_receipts'), 0);
    expect(await inbox.pendingCount(), 2);
    final claims = await vault.database
        .customSelect('SELECT status FROM source_claims')
        .get();
    for (final row in claims) {
      expect(row.data['status'], 'staged');
    }
  });

  test('a lost reply resolves through the recorded receipt', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    await confirm(<int>[one]);

    final receipt = await commands.receiptOf('op-1');

    expect(receipt, isNotNull);
    expect(receipt!.resultJson, contains('inbox.confirmBatch'));
    expect(receipt.commitSequence, 1);
    expect(await count('transactions'), 1);
  });

  test('Undo reverses the whole batch and repeats from its receipt', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    final two = await seedItem(
      sourceId: 2,
      receivedAt: 200,
      proposal: _proposal(amountMinor: -8045),
    );
    await confirm(<int>[one, two]);

    final undo = await inbox.undoBatch(
      operationId: 'undo-1',
      originalOperationId: 'op-1',
      undoDraftId: 'undo-draft-1',
    );

    expect(undo.reversed, 2);
    expect(undo.commitSequence, 2);
    final transactions = await vault.database
        .customSelect('SELECT deleted_at, revision FROM transactions')
        .get();
    for (final row in transactions) {
      expect(row.data['deleted_at'], isNotNull);
      expect(row.data['revision'], 2);
    }
    final events = await vault.database
        .customSelect('SELECT deleted_at FROM financial_events')
        .get();
    for (final row in events) {
      expect(row.data['deleted_at'], isNotNull);
    }
    final claims = await vault.database
        .customSelect('SELECT status, decided_operation_id FROM source_claims')
        .get();
    for (final row in claims) {
      expect(row.data['status'], 'undone');
      expect(row.data['decided_operation_id'], 'undo-1');
    }
    expect(await count('change_log', where: "change_kind = 'compensate'"), 4);
    expect(await inbox.pendingCount(), 0);

    final repeated = await inbox.undoBatch(
      operationId: 'undo-1',
      originalOperationId: 'op-1',
      undoDraftId: 'undo-draft-1',
    );
    expect(repeated.commitSequence, undo.commitSequence);
    expect(repeated.reversed, undo.reversed);
    expect(await count('change_log', where: "change_kind = 'compensate'"), 4);
    expect(await count('operation_receipts'), 2);

    await expectLater(
      inbox.undoBatch(operationId: 'undo-2', originalOperationId: 'op-1'),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.undoBlocked,
        ),
      ),
    );
  });

  test('a settlement blocks the batch Undo and writes nothing', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    await confirm(<int>[one]);
    final transaction = await vault.database
        .customSelect('SELECT id FROM transactions')
        .getSingle();
    final transactionId = transaction.data['id'] as String;
    await vault.database.customStatement(
      'INSERT INTO obligations (id, created_at, updated_at, deleted_at, '
      'revision, account_id, date, direction, amount_minor, currency, '
      "amount_state, status) VALUES (?, 1, 1, NULL, 1, ?, '2026-10-10', "
      "'out', 3175, 'USD', 'known', 'open')",
      <Object?>[_id(300), _account],
    );
    await vault.database.customStatement(
      'INSERT INTO settlement_allocations (id, created_at, updated_at, '
      'deleted_at, revision, obligation_id, transaction_id, amount_minor, '
      "currency) VALUES (?, 1, 1, NULL, 1, ?, ?, 3175, 'USD')",
      <Object?>[_id(301), _id(300), transactionId],
    );

    await expectLater(
      inbox.undoBatch(operationId: 'undo-1', originalOperationId: 'op-1'),
      throwsA(
        isA<InboxError>()
            .having((error) => error.code, 'code', InboxErrorCode.undoBlocked)
            .having(
              (error) => error.blockedIds,
              'blockedIds',
              contains(transactionId),
            ),
      ),
    );

    final live = await vault.database.customSelect(
      'SELECT deleted_at FROM transactions WHERE id = ?',
      variables: <Variable<Object>>[Variable(transactionId)],
    ).getSingle();
    expect(live.data['deleted_at'], isNull);
    expect(await count('operation_receipts'), 1);
    final claim = await vault.database
        .customSelect('SELECT status FROM source_claims')
        .getSingle();
    expect(claim.data['status'], 'accepted');
  });

  test('a merge item links the source and creates no payment', () async {
    final existing = await createPayment(amountMinor: -3175);
    final item = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      suggestionType: 'merge',
      proposal: _proposal(amountMinor: -3175, match: existing),
    );

    final result = await confirm(<int>[item]);

    expect(result.created, 0);
    expect(result.linked, 1);
    expect(await count('transactions'), 1);
    expect(await count('source_event_links'), 1);
    final link = await vault.database
        .customSelect('SELECT operation_id FROM source_event_links')
        .getSingle();
    expect(link.data['operation_id'], 'op-1');

    await inbox.undoBatch(
      operationId: 'undo-1',
      originalOperationId: 'op-1',
    );
    expect(await count('source_event_links'), 0);
    final live = await vault.database.customSelect(
      'SELECT deleted_at FROM transactions WHERE id = ?',
      variables: <Variable<Object>>[Variable(existing)],
    ).getSingle();
    expect(live.data['deleted_at'], isNull);
  });

  test('a rejected merge becomes its own payment', () async {
    final existing = await createPayment(amountMinor: -3175);
    final item = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      suggestionType: 'merge',
      proposal: _proposal(amountMinor: -3175, match: existing),
    );
    await inbox.stageDecision(
      itemId: item,
      expectedRevision: 1,
      decision: InboxMatchDecision.reject,
    );

    final result = await confirm(<int>[item]);

    expect(result.created, 1);
    expect(result.linked, 0);
    expect(await count('transactions'), 2);
    expect(await count('source_event_links'), 0);
  });

  test('a refund item creates the refund and its link', () async {
    final original = await createPayment(amountMinor: -3175);
    final item = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      suggestionType: 'refund',
      proposal: _proposal(
        amountMinor: 3175,
        kind: 'refund',
        match: original,
      ),
    );

    await confirm(<int>[item]);

    final refund = await vault.database
        .customSelect(
          "SELECT amount_minor, kind FROM transactions WHERE kind = 'refund'",
        )
        .getSingle();
    expect(refund.data['amount_minor'], 3175);
    final link = await vault.database
        .customSelect(
          'SELECT amount_minor, original_transaction_id FROM refund_links',
        )
        .getSingle();
    expect(link.data['amount_minor'], 3175);
    expect(link.data['original_transaction_id'], original);

    await inbox.undoBatch(
      operationId: 'undo-1',
      originalOperationId: 'op-1',
    );
    final refundRow = await vault.database
        .customSelect(
          "SELECT deleted_at FROM transactions WHERE kind = 'refund'",
        )
        .getSingle();
    expect(refundRow.data['deleted_at'], isNotNull);
    final linkRow = await vault.database
        .customSelect('SELECT deleted_at FROM refund_links')
        .getSingle();
    expect(linkRow.data['deleted_at'], isNotNull);
    final originalRow = await vault.database.customSelect(
      'SELECT deleted_at FROM transactions WHERE id = ?',
      variables: <Variable<Object>>[Variable(original)],
    ).getSingle();
    expect(originalRow.data['deleted_at'], isNull);
  });

  test('a transfer item links the staged side to the existing side', () async {
    final existing = await createPayment(amountMinor: -124000);
    final item = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      suggestionType: 'transfer',
      proposal: _proposal(
        amountMinor: 124000,
        accountId: _savings,
        kind: 'transfer',
        categoryId: null,
        match: existing,
      ),
    );

    await confirm(<int>[item]);

    final staged = await vault.database
        .customSelect(
          "SELECT id FROM transactions WHERE kind = 'transfer'",
        )
        .getSingle();
    final stagedId = staged.data['id'] as String;
    final link = await vault.database
        .customSelect(
          'SELECT sending_transaction_id, receiving_transaction_id '
          'FROM transfer_links',
        )
        .getSingle();
    expect(link.data['sending_transaction_id'], existing);
    expect(link.data['receiving_transaction_id'], stagedId);

    await inbox.undoBatch(
      operationId: 'undo-1',
      originalOperationId: 'op-1',
    );
    expect(await count('transfer_links', where: 'deleted_at IS NOT NULL'), 1);
  });

  test('a draft claim confirms with its capture source', () async {
    final item = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      draftClaim: true,
    );

    await confirm(<int>[item]);

    final row = await vault.database
        .customSelect('SELECT source FROM transactions')
        .getSingle();
    expect(row.data['source'], 'captured');
    expect(await count('staged_rows'), 0);
    final claim = await vault.database
        .customSelect('SELECT status FROM source_claims')
        .getSingle();
    expect(claim.data['status'], 'accepted');
  });

  test('a malformed proposal keeps the batch unconfirmed', () async {
    final good = await seedItem(sourceId: 1, receivedAt: 100);
    final bad = await seedItem(
      sourceId: 2,
      receivedAt: 200,
      proposal: <String, Object?>{'v': 1},
    );

    await expectLater(
      confirm(<int>[good, bad]),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.invalidProposal,
        ),
      ),
    );
    expect(await count('transactions'), 0);
    expect(await inbox.pendingCount(), 2);
  });

  test('a rejected transfer keeps the whole batch unconfirmed', () async {
    final existing = await createPayment(amountMinor: -124000);
    final item = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      suggestionType: 'transfer',
      proposal: _proposal(
        amountMinor: 124000,
        accountId: _savings,
        kind: 'transfer',
        categoryId: null,
        match: existing,
      ),
    );
    await inbox.stageDecision(
      itemId: item,
      expectedRevision: 1,
      decision: InboxMatchDecision.reject,
    );

    await expectLater(
      confirm(<int>[item]),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.unsupportedSuggestion,
        ),
      ),
    );
    expect(await count('transactions'), 1);
    expect(await inbox.pendingCount(), 1);
  });

  test('an unknown original operation cannot be undone', () async {
    await expectLater(
      inbox.undoBatch(
        operationId: 'undo-x',
        originalOperationId: 'missing-op',
      ),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.undoNotFound,
        ),
      ),
    );
  });

  test('an unsupported suggestion keeps the whole batch unconfirmed', () async {
    final one = await seedItem(sourceId: 1, receivedAt: 100);
    final two = await seedItem(
      sourceId: 2,
      receivedAt: 200,
      suggestionType: 'recurring',
    );

    await expectLater(
      confirm(<int>[one, two]),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.unsupportedSuggestion,
        ),
      ),
    );
    expect(await count('transactions'), 0);
    expect(await inbox.pendingCount(), 2);
  });
}

Future<void> _seedReference(Vault vault) async {
  final db = vault.database;
  await db.customStatement(
    "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
  );
  for (final (index, id) in <String>[_account, _savings].indexed) {
    await db.customStatement(
      'INSERT INTO accounts (id, created_at, updated_at, deleted_at, revision, '
      'name, type, currency, institution, is_liability, is_liquid, '
      'include_in_net_worth, archived) '
      "VALUES (?, 1, 1, NULL, 1, ?, 'bank', 'USD', NULL, 0, 1, 1, 0)",
      <Object?>[id, 'Account $index'],
    );
  }
  await db.customStatement(
    'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
    'revision, name, parent_id, kind, sort_order, archived) '
    "VALUES (?, 1, 1, NULL, 1, 'Groceries', NULL, 'expense', 0, 0)",
    <Object?>[_groceries],
  );
  await db.customStatement(
    'INSERT INTO import_parse_configs (id, parser_id, parser_version, '
    'identity_version, config_version, config_json, content_digest) '
    "VALUES ('config', 'csv', 1, 1, 1, '{}', zeroblob(32))",
  );
}
