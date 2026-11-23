// P17: staged Inbox reads and decisions (Q13; flow F07 steps 1-3).
//
// The reads never write a ledger row. The exact selected count and total are
// computed from the stored proposals (F07-B). A source delete removes the
// staged item only.

import 'dart:convert';

import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/inbox.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _account = '00000000-0000-7000-8000-0000000000a1';
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
  var nowMs = 1700000000000;
  var entity = 0;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
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
    entity = 0;
    await _seedReference(vault);
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<int> seedItem({
    required int sourceId,
    required int receivedAt,
    Map<String, Object?>? proposal,
    String suggestionType = 'new',
    bool draftClaim = false,
    bool published = true,
    String batchStatus = 'review',
    String claimStatus = 'staged',
    String decision = 'pending',
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
        decision,
      ],
    );
    final row = await db.customSelect(
      'SELECT id FROM inbox_items WHERE source_identity_id = ?',
      variables: <Variable<Object>>[Variable(sourceId)],
    ).getSingle();
    return row.data['id'] as int;
  }

  test('the page returns pending visible rows only', () async {
    final published =
        await seedItem(sourceId: 1, receivedAt: 100, proposal: _proposal());
    final draft = await seedItem(
      sourceId: 2,
      receivedAt: 200,
      draftClaim: true,
      proposal: _proposal(amountMinor: -1200),
    );
    await seedItem(
      sourceId: 3,
      receivedAt: 300,
      published: false,
      proposal: _proposal(amountMinor: -1300),
    );
    await seedItem(
      sourceId: 4,
      receivedAt: 400,
      claimStatus: 'discarded',
      proposal: _proposal(amountMinor: -1400),
    );

    final page = await inbox.page();
    expect(page.rows.map((row) => row.id), <int>[published, draft]);
    expect(await inbox.pendingCount(), 2);
    expect(page.next, isNull);
  });

  test('a private candidate is consumed without hiding a visible row',
      () async {
    await seedItem(
      sourceId: 1,
      receivedAt: 100,
      published: false,
      proposal: _proposal(amountMinor: -100),
    );
    final visible =
        await seedItem(sourceId: 2, receivedAt: 200, proposal: _proposal());
    await seedItem(
      sourceId: 3,
      receivedAt: 300,
      proposal: _proposal(amountMinor: -200),
    );

    final first = await inbox.page(limit: 1);
    expect(first.rows.single.id, visible);
    final second = await inbox.page(limit: 1, after: first.next);
    expect(second.rows.single.id, isNot(visible));
  });

  test('a page cursor restarts after an Inbox revision change', () async {
    await seedItem(sourceId: 1, receivedAt: 100, proposal: _proposal());
    final second = await seedItem(
      sourceId: 2,
      receivedAt: 200,
      suggestionType: 'merge',
      proposal: _proposal(match: _id(900)),
    );

    final first = await inbox.page(limit: 1);
    expect(first.next, isNotNull);

    await inbox.stageDecision(
      itemId: second,
      expectedRevision: 1,
      decision: InboxMatchDecision.reject,
    );

    await expectLater(
      inbox.page(limit: 1, after: first.next),
      throwsA(
        isA<InboxError>()
            .having((error) => error.code, 'code', InboxErrorCode.cursorStale),
      ),
    );
  });

  test('the selected count and totals are exact (F07-B)', () async {
    final outOne = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      proposal: _proposal(amountMinor: -3175),
    );
    final outTwo = await seedItem(
      sourceId: 2,
      receivedAt: 200,
      proposal: _proposal(amountMinor: -8045),
    );
    final moneyIn = await seedItem(
      sourceId: 3,
      receivedAt: 300,
      proposal: _proposal(amountMinor: 500, kind: 'income'),
    );

    final selection = await inbox.selection(<int>{outOne, outTwo, moneyIn});

    expect(selection.count, 3);
    final usd = selection.byCurrency['USD'];
    expect(usd, isNotNull);
    expect(usd!.netMinor, -10720);
    expect(usd.outMinor, 11220);
    expect(usd.inMinor, 500);
    expect(await inbox.pendingCount(), 3);
  });

  test('a staged decision writes no ledger row and bumps the revision',
      () async {
    final item = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      suggestionType: 'merge',
      proposal: _proposal(amountMinor: -3175, match: _id(900)),
    );

    await inbox.stageDecision(
      itemId: item,
      expectedRevision: 1,
      decision: InboxMatchDecision.reject,
    );

    final current = await inbox.item(item);
    expect(current, isNotNull);
    expect(current!.proposal.decision, InboxMatchDecision.reject);
    expect(current.row.editRevision, 2);
    final transactions = await vault.database
        .customSelect('SELECT count(*) AS n FROM transactions')
        .getSingle();
    expect(transactions.data['n'], 0);
    final log = await vault.database
        .customSelect('SELECT count(*) AS n FROM change_log')
        .getSingle();
    expect(log.data['n'], 0);
  });

  test('a source delete removes the staged item only', () async {
    final item = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      proposal: _proposal(),
    );

    await inbox.deleteStaged(itemId: item, expectedRevision: 1);

    expect(await inbox.item(item), isNull);
    expect(await inbox.pendingCount(), 0);
    final claim = await vault.database
        .customSelect(
          'SELECT status FROM source_claims WHERE source_identity_id = 1',
        )
        .getSingle();
    expect(claim.data['status'], 'discarded');
    final staged = await vault.database
        .customSelect('SELECT count(*) AS n FROM staged_rows')
        .getSingle();
    expect(staged.data['n'], 0);
    final identity = await vault.database
        .customSelect('SELECT count(*) AS n FROM source_identities')
        .getSingle();
    expect(identity.data['n'], 1);
    final transactions = await vault.database
        .customSelect('SELECT count(*) AS n FROM transactions')
        .getSingle();
    expect(transactions.data['n'], 0);
    final log = await vault.database
        .customSelect('SELECT count(*) AS n FROM change_log')
        .getSingle();
    expect(log.data['n'], 0);
  });

  test('a wrong revision fails the staged decision', () async {
    final item = await seedItem(sourceId: 1, receivedAt: 100);

    await expectLater(
      inbox.stageDecision(
        itemId: item,
        expectedRevision: 9,
        decision: InboxMatchDecision.reject,
      ),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.revisionConflict,
        ),
      ),
    );
    final current = await inbox.item(item);
    expect(current!.proposal.decision, InboxMatchDecision.accept);
    expect(current.row.editRevision, 1);
  });

  test('an overflowing selected total is a typed failure', () async {
    final one = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      proposal: _proposal(amountMinor: 9223372036854775807),
    );
    final two = await seedItem(
      sourceId: 2,
      receivedAt: 200,
      proposal: _proposal(amountMinor: 9223372036854775807),
    );

    await expectLater(
      inbox.selection(<int>{one, two}),
      throwsA(
        isA<InboxError>().having(
          (error) => error.code,
          'code',
          InboxErrorCode.amountOverflow,
        ),
      ),
    );
  });

  test('the item sheet reads the stored proposal', () async {
    final item = await seedItem(
      sourceId: 1,
      receivedAt: 100,
      proposal: _proposal(amountMinor: -3175, merchant: 'PX Market'),
    );

    final current = await inbox.item(item);
    expect(current!.row.suggestionType, 'new');
    expect(current.proposal.amountMinor, -3175);
    expect(current.proposal.merchantName, 'PX Market');
    expect(current.proposal.currency, 'USD');
    expect(await inbox.item(999), isNull);
  });
}

Future<void> _seedReference(Vault vault) async {
  final db = vault.database;
  await db.customStatement(
    "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
  );
  await db.customStatement(
    'INSERT INTO accounts (id, created_at, updated_at, deleted_at, revision, '
    'name, type, currency, institution, is_liability, is_liquid, '
    'include_in_net_worth, archived) '
    "VALUES (?, 1, 1, NULL, 1, 'Checking', 'bank', 'USD', NULL, 0, 1, 1, 0)",
    <Object?>[_account],
  );
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
