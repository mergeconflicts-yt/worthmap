import 'dart:convert';

import 'package:contour/core/ids.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/drafts.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _draft = '00000000-0000-7000-8000-0000000000d1';
const String _category = '00000000-0000-7000-8000-0000000000c1';

String _payload() => jsonEncode(<String, Object?>{
      'amountMinor': 2400,
      'currency': 'USD',
      'date': '2026-10-13',
      'categoryId': _category,
    });

void main() {
  late Vault vault;
  late CommandRepository commands;
  late DraftRepository drafts;
  var nowMs = 1700000000000;
  var nextId = 0;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newOperationId: () {
        nextId += 1;
        return '00000000-0000-7000-8000-0000000000b$nextId';
      },
    );
    drafts = DraftRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    nextId = 0;
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<void> insertCategory() async {
    await vault.database.customInsert(
      'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
      'revision, name, parent_id, kind, sort_order, archived) '
      'VALUES (?, ?, ?, NULL, 1, ?, NULL, ?, 0, 0)',
      variables: [
        const Variable(_category),
        Variable(nowMs),
        Variable(nowMs),
        const Variable('Test category'),
        const Variable('expense'),
      ],
    );
  }

  Future<CommandOutcome> saveDraft({bool validEffects = true}) =>
      commands.saveDraft(
        draftId: _draft,
        commandType: 'payment.create',
        payloadJson: _payload(),
        payloadVersion: 1,
        codecVersion: 1,
        changes: const <ChangeLogEntry>[
          ChangeLogEntry(
            entityId: _category,
            toRevision: 1,
            changeKind: 'create',
            afterJson: '{"name":"Test category"}',
            schemaVersion: 1,
          ),
        ],
        effects: () async {
          if (validEffects) {
            await insertCategory();
          }
        },
        resultJson: '{"created":["$_category"]}',
      );

  Future<String> intentStateForDraft() async {
    final row = await vault.database.customSelect(
      'SELECT operation_id, state FROM operation_intents WHERE draft_id = ?',
      variables: [const Variable(_draft)],
    ).getSingle();
    return row.data['state'] as String;
  }

  Future<int> count(String sql) async {
    final row = await vault.database.customSelect(sql).getSingle();
    return row.data['n'] as int;
  }

  test('a Save commits one event, seals the draft and clears its payload',
      () async {
    await drafts.save(
      id: _draft,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(),
    );

    final outcome = await saveDraft();

    expect(outcome.commitSequence, 1);
    expect(outcome.readRevision, 1);
    final receipt = await commands.receiptOf(outcome.operationId);
    expect(receipt, isNotNull);

    final draft = await drafts.byId(_draft);
    expect(draft?.status, DraftStatus.committed);
    expect(draft?.committedOperationId, outcome.operationId);
    expect(draft?.payloadJson, isNull);
    expect(
      await count('SELECT count(*) AS n FROM draft_payloads'),
      0,
    );
    expect(
      await count(
        'SELECT count(*) AS n FROM change_log WHERE operation_id = '
        "'${outcome.operationId}'",
      ),
      1,
    );
  });

  test('a repeated tap returns the recorded receipt and runs nothing twice',
      () async {
    await drafts.save(
      id: _draft,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(),
    );
    var effects = 0;
    final first = await commands.saveDraft(
      draftId: _draft,
      commandType: 'payment.create',
      payloadJson: _payload(),
      payloadVersion: 1,
      codecVersion: 1,
      changes: const <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: _category,
          toRevision: 1,
          changeKind: 'create',
          afterJson: '{}',
          schemaVersion: 1,
        ),
      ],
      effects: () async {
        effects += 1;
        await insertCategory();
      },
      resultJson: '{"done":true}',
    );

    final second = await commands.saveDraft(
      draftId: _draft,
      commandType: 'payment.create',
      payloadJson: _payload(),
      payloadVersion: 1,
      codecVersion: 1,
      changes: const <ChangeLogEntry>[],
      effects: () async {
        effects += 1;
      },
      resultJson: '{"done":false}',
    );

    expect(effects, 1);
    expect(second.commitSequence, first.commitSequence);
    expect(second.resultJson, '{"done":true}');
    expect(
      await count('SELECT count(*) AS n FROM operation_intents'),
      1,
    );
  });

  test('a crashed Save resumes its one intent', () async {
    await drafts.save(
      id: _draft,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(),
    );
    await commands.prepare(
      operationId: '00000000-0000-7000-8000-0000000000aa',
      commandType: 'payment.create',
      draftId: _draft,
      formType: 'payment',
      payloadJson: _payload(),
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );

    final outcome = await saveDraft();

    expect(outcome.commitSequence, 1);
    expect(
      await count('SELECT count(*) AS n FROM operation_intents'),
      1,
    );
    expect(
      await count('SELECT count(*) AS n FROM operation_receipts'),
      1,
    );
    expect((await drafts.byId(_draft))?.status, DraftStatus.committed);
  });

  test('a changed payload with an active attempt is rejected', () async {
    await drafts.save(
      id: _draft,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(),
    );
    await commands.prepare(
      operationId: '00000000-0000-7000-8000-0000000000aa',
      commandType: 'payment.create',
      draftId: _draft,
      formType: 'payment',
      payloadJson: _payload(),
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );

    await expectLater(
      commands.saveDraft(
        draftId: _draft,
        commandType: 'payment.create',
        payloadJson: jsonEncode(<String, Object?>{'amountMinor': 9999}),
        payloadVersion: 1,
        codecVersion: 1,
        changes: const <ChangeLogEntry>[],
        effects: () async {},
        resultJson: '{}',
      ),
      throwsA(
        isA<CommandError>()
            .having((e) => e.code, 'code', CommandErrorCode.digestMismatch),
      ),
    );
    expect(
      await count('SELECT count(*) AS n FROM operation_receipts'),
      0,
    );
    expect(
      await count('SELECT count(*) AS n FROM operation_intents'),
      1,
    );
  });

  test('a missing draft is a typed command error', () async {
    await expectLater(
      saveDraft(),
      throwsA(
        isA<CommandError>()
            .having((e) => e.code, 'code', CommandErrorCode.draftNotFound),
      ),
    );
  });

  test('a discarded draft cannot be saved', () async {
    await drafts.save(
      id: _draft,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(),
    );
    await drafts.discard(_draft);
    await expectLater(
      saveDraft(),
      throwsA(
        isA<CommandError>()
            .having((e) => e.code, 'code', CommandErrorCode.invalidState),
      ),
    );
  });

  test('a failed attempt is released and the next Save is a new one', () async {
    await drafts.save(
      id: _draft,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(),
    );
    await expectLater(saveDraft(validEffects: false), throwsA(anything));
    expect(await intentStateForDraft(), 'submitted');

    final operation = await vault.database.customSelect(
      'SELECT operation_id FROM operation_intents WHERE draft_id = ?',
      variables: [const Variable(_draft)],
    ).getSingle();
    await commands.releaseUncommitted(
      operation.data['operation_id'] as String,
    );

    expect(await intentStateForDraft(), 'rejected');
    expect((await drafts.byId(_draft))?.status, DraftStatus.editing);

    final outcome = await saveDraft();
    expect(outcome.commitSequence, 1);
    expect(
      await count('SELECT count(*) AS n FROM operation_intents'),
      2,
    );
    expect(
      await count('SELECT count(*) AS n FROM operation_receipts'),
      1,
    );
  });

  test('a committed attempt cannot be released', () async {
    await drafts.save(
      id: _draft,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(),
    );
    final outcome = await saveDraft();
    await expectLater(
      commands.releaseUncommitted(outcome.operationId),
      throwsA(
        isA<CommandError>()
            .having((e) => e.code, 'code', CommandErrorCode.invalidState),
      ),
    );
  });

  test('a repeated prepare is a no-op and conflicts are typed', () async {
    await drafts.save(
      id: _draft,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(),
    );
    Future<void> prepare(String operation, {String? payload}) =>
        commands.prepare(
          operationId: operation,
          commandType: 'payment.create',
          draftId: _draft,
          formType: 'payment',
          payloadJson: payload ?? _payload(),
          payloadVersion: 1,
          codecVersion: 1,
          schemaVersion: 1,
        );

    await prepare('00000000-0000-7000-8000-0000000000aa');
    await prepare('00000000-0000-7000-8000-0000000000aa');
    expect(
      await count('SELECT count(*) AS n FROM operation_intents'),
      1,
    );
    await expectLater(
      prepare('00000000-0000-7000-8000-0000000000bb'),
      throwsA(
        isA<CommandError>()
            .having((e) => e.code, 'code', CommandErrorCode.invalidState),
      ),
    );
    await expectLater(
      prepare(
        '00000000-0000-7000-8000-0000000000aa',
        payload: jsonEncode(<String, Object?>{'amountMinor': 1}),
      ),
      throwsA(
        isA<CommandError>()
            .having((e) => e.code, 'code', CommandErrorCode.digestMismatch),
      ),
    );
  });

  test('a repository without an injected id generates a UUIDv7', () async {
    final generated = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    await drafts.save(
      id: _draft,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(),
    );
    final outcome = await generated.saveDraft(
      draftId: _draft,
      commandType: 'payment.create',
      payloadJson: _payload(),
      payloadVersion: 1,
      codecVersion: 1,
      changes: const <ChangeLogEntry>[],
      effects: () async {},
      resultJson: '{}',
    );
    expect(UuidV7.tryParse(outcome.operationId), isNotNull);
    await generated.dispose();
  });

  test('command errors carry a safe code only', () {
    const error = CommandError(CommandErrorCode.digestMismatch);
    expect(error.toString(), 'CommandError(digestMismatch)');
  });
}
