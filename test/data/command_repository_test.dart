import 'dart:convert';

import 'package:contour/data/db/db.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Vault vault;
  late CommandRepository repo;
  var nowMs = 1700000000000;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    repo = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
  });

  tearDown(() async {
    await repo.dispose();
    await vault.close();
  });

  // A neutral authored row: the categories table is not gated by a finance
  // gate, so it exercises the protocol without inventing financial rules.
  // The categories insert trigger registers the row in entity_registry, and
  // the ChangeLog FK proves that existence.
  Future<void> insertCategory(String id) async {
    await vault.database.customInsert(
      'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
      'revision, name, parent_id, kind, sort_order, archived) '
      'VALUES (?, ?, ?, NULL, 1, ?, NULL, ?, 0, 0)',
      variables: [
        Variable(id),
        Variable(nowMs),
        Variable(nowMs),
        const Variable('Test category'),
        const Variable('expense'),
      ],
    );
  }

  test('prepare persists draft, payload and intent before the writer runs',
      () async {
    const operation = '00000000-0000-7000-8000-00000000000a';
    const draft = '00000000-0000-7000-8000-00000000000b';
    await repo.prepare(
      operationId: operation,
      commandType: 'test.category.create',
      draftId: draft,
      formType: 'category',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );

    final intent = await vault.database.customSelect(
      'SELECT state, command_type, state_version FROM operation_intents '
      'WHERE operation_id = ?',
      variables: [const Variable(operation)],
    ).getSingle();
    expect(intent.data['state'], 'submitted');
    expect(intent.data['command_type'], 'test.category.create');

    final chunks = await vault.database.customSelect(
      'SELECT payload_json, total_bytes FROM operation_payload_chunks c, '
      'operation_payloads p WHERE c.operation_id = ? AND '
      'c.operation_id = p.operation_id AND c.chunk_index = 0',
      variables: [const Variable(operation)],
    ).getSingle();
    expect(chunks.data['payload_json'], '{"v":1}');
    expect(chunks.data['total_bytes'], 7);

    final draftRow = await vault.database.customSelect(
      'SELECT status FROM draft_headers WHERE id = ?',
      variables: [const Variable(draft)],
    ).getSingle();
    expect(draftRow.data['status'], 'editing');
  });

  test('a committed command advances sequence and revision and writes history',
      () async {
    const operation = '00000000-0000-7000-8000-00000000000a';
    const draft = '00000000-0000-7000-8000-00000000000b';
    const category = '00000000-0000-7000-8000-00000000000c';
    await repo.prepare(
      operationId: operation,
      commandType: 'test.category.create',
      draftId: draft,
      formType: 'category',
      payloadJson: '{"v":1,"name":"Test category"}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );

    final publications = <int>[];
    final subscription = repo.published.listen(publications.add);

    final outcome = await repo.execute(
      operationId: operation,
      changes: [
        const ChangeLogEntry(
          entityId: category,
          toRevision: 1,
          changeKind: 'create',
          afterJson: '{"v":1,"name":"Test category"}',
          schemaVersion: 1,
        ),
      ],
      effects: () => insertCategory(category),
      resultJson: '{"created":["$category"]}',
    );

    expect(outcome.commitSequence, 1);
    expect(outcome.readRevision, 1);

    final receipt = await repo.receiptOf(operation);
    expect(receipt, isNotNull);
    expect(receipt!.commitSequence, 1);
    expect(jsonDecode(receipt.resultJson), isA<Map<String, dynamic>>());

    final log = await vault.database.customSelect(
      'SELECT entity_id, to_revision, change_kind, ordinal FROM change_log '
      'WHERE operation_id = ?',
      variables: [const Variable(operation)],
    ).get();
    expect(log, hasLength(1));
    expect(log.first.data['entity_id'], category);
    expect(log.first.data['to_revision'], 1);
    expect(log.first.data['change_kind'], 'create');

    final state = await vault.database
        .customSelect(
          'SELECT commit_sequence, read_revision FROM db_state '
          'WHERE singleton = 1',
        )
        .getSingle();
    expect(state.data['commit_sequence'], 1);
    expect(state.data['read_revision'], 1);

    final draftRow = await vault.database.customSelect(
      'SELECT status, committed_operation_id FROM draft_headers '
      'WHERE id = ?',
      variables: [const Variable(draft)],
    ).getSingle();
    expect(draftRow.data['status'], 'committed');
    expect(draftRow.data['committed_operation_id'], operation);

    await Future<void>.delayed(Duration.zero);
    expect(publications, [1]);
    await subscription.cancel();
  });

  test('receipt-first retry returns the recorded outcome without re-running',
      () async {
    const operation = '00000000-0000-7000-8000-00000000000a';
    await repo.prepare(
      operationId: operation,
      commandType: 'test.category.create',
      draftId: '00000000-0000-7000-8000-00000000000b',
      formType: 'category',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    final first = await repo.execute(
      operationId: operation,
      changes: const [],
      effects: () async {},
      resultJson: '{"done":true}',
    );

    var effectsRan = 0;
    final second = await repo.execute(
      operationId: operation,
      changes: const [],
      effects: () async => effectsRan++,
      resultJson: '{"done":false}', // different result must be ignored
    );

    expect(effectsRan, 0);
    expect(second.commitSequence, first.commitSequence);
    expect(second.resultJson, '{"done":true}');
    final state = await vault.database
        .customSelect('SELECT commit_sequence FROM db_state')
        .getSingle();
    expect(state.data['commit_sequence'], 1); // no second commit
  });

  test('an unknown operation id fails with a typed code', () async {
    await expectLater(
      repo.execute(
        operationId: '00000000-0000-7000-8000-0000000000f0',
        changes: const [],
        effects: () async {},
        resultJson: '{}',
      ),
      throwsA(
        isA<CommandError>().having(
          (e) => e.code,
          'code',
          CommandErrorCode.unknownOperation,
        ),
      ),
    );
  });

  test('stored input is immutable; tampering is rejected by the schema',
      () async {
    const operation = '00000000-0000-7000-8000-00000000000a';
    await repo.prepare(
      operationId: operation,
      commandType: 'test.category.create',
      draftId: '00000000-0000-7000-8000-00000000000b',
      formType: 'category',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    // The reference schema guards the durable command input: an UPDATE on
    // the frozen payload aborts (DATABASE_DESIGN 6, immutable payload). The
    // digest check in `execute` is the second layer for the same invariant.
    await expectLater(
      vault.database.customStatement(
        'UPDATE operation_payload_chunks SET payload_json = ? '
        'WHERE operation_id = ? AND chunk_index = 0',
        ['{"v":1,"name":"changed"}', operation],
      ),
      throwsA(isA<Exception>()),
    );
    // The stored payload is unchanged.
    final chunk = await vault.database.customSelect(
      'SELECT payload_json FROM operation_payload_chunks '
      'WHERE operation_id = ? AND chunk_index = 0',
      variables: [const Variable(operation)],
    ).getSingle();
    expect(chunk.data['payload_json'], '{"v":1}');
  });

  test('a cancelled intent cannot execute', () async {
    const operation = '00000000-0000-7000-8000-00000000000a';
    await repo.prepare(
      operationId: operation,
      commandType: 'test.category.create',
      draftId: '00000000-0000-7000-8000-00000000000b',
      formType: 'category',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    await repo.cancel(operation);
    await expectLater(
      repo.execute(
        operationId: operation,
        changes: const [],
        effects: () async {},
        resultJson: '{}',
      ),
      throwsA(
        isA<CommandError>().having(
          (e) => e.code,
          'code',
          CommandErrorCode.invalidState,
        ),
      ),
    );
  });

  test('a failed effect rolls the whole transaction back', () async {
    const operation = '00000000-0000-7000-8000-00000000000a';
    const category = '00000000-0000-7000-8000-00000000000c';
    await repo.prepare(
      operationId: operation,
      commandType: 'test.category.create',
      draftId: '00000000-0000-7000-8000-00000000000b',
      formType: 'category',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    await expectLater(
      repo.execute(
        operationId: operation,
        changes: const [
          ChangeLogEntry(
            entityId: category,
            toRevision: 1,
            changeKind: 'create',
            afterJson: '{}',
            schemaVersion: 1,
          ),
        ],
        effects: () async {
          // No authored row is written, so the ChangeLog FK fails at commit.
        },
        resultJson: '{}',
      ),
      throwsA(anything),
    );

    // Nothing applied: no receipt, no sequence change, intent back at
    // submitted (the transaction rolled back the running state too).
    final state = await vault.database.customSelect(
      'SELECT (SELECT state FROM operation_intents WHERE operation_id = ?) '
      'AS intent, '
      '(SELECT count(*) FROM operation_receipts WHERE operation_id = ?) '
      'AS receipts, '
      '(SELECT commit_sequence FROM db_state) AS seq',
      variables: const [Variable(operation), Variable(operation)],
    ).getSingle();
    expect(state.data['intent'], 'submitted');
    expect(state.data['receipts'], 0);
    expect(state.data['seq'], 0);
  });
}
