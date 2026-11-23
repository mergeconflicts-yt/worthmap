import 'dart:convert';

import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/drafts.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _draftA = '00000000-0000-7000-8000-0000000000a1';
const String _draftB = '00000000-0000-7000-8000-0000000000a2';
const String _category = '00000000-0000-7000-8000-0000000000c1';

String _payload(int amount) => jsonEncode(<String, Object?>{
      'amountMinor': amount,
      'currency': 'USD',
      'date': '2026-10-13',
    });

void main() {
  late Vault vault;
  late DraftRepository drafts;
  var nowMs = 1700000000000;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    drafts = DraftRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
  });

  tearDown(() async {
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

  test('a new draft starts at revision 1 and keeps its payload', () async {
    final record = await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(2400),
    );
    expect(record.status, DraftStatus.editing);
    expect(record.editRevision, 1);
    expect(record.formType, 'payment');
    expect(record.schemaVersion, 1);
    expect(record.payloadJson, _payload(2400));
    expect(record.committedOperationId, isNull);
  });

  test('saving the same draft increments the revision', () async {
    await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(2400),
    );
    nowMs += 1000;
    final second = await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(2500),
    );
    expect(second.editRevision, 2);
    expect(second.payloadJson, _payload(2500));
  });

  test('find offers the newest editing draft of the type', () async {
    await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(100),
    );
    nowMs += 1000;
    await drafts.save(
      id: _draftB,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(200),
    );
    nowMs += 1000;
    await drafts.save(
      id: '00000000-0000-7000-8000-0000000000a3',
      formType: 'transfer',
      schemaVersion: 1,
      payloadJson: _payload(300),
    );

    final found = await drafts.find(formType: 'payment');
    expect(found?.id, _draftB);

    final list = await drafts.list(formType: 'payment');
    expect(list.map((draft) => draft.id), <String>[_draftB, _draftA]);
  });

  test('a submitted draft cannot be edited', () async {
    await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(100),
    );
    await vault.database.customStatement(
      'UPDATE draft_headers SET status = ? WHERE id = ?',
      ['submitted', _draftA],
    );
    await expectLater(
      drafts.save(
        id: _draftA,
        formType: 'payment',
        schemaVersion: 1,
        payloadJson: _payload(200),
      ),
      throwsA(
        isA<DraftError>()
            .having((e) => e.code, 'code', DraftErrorCode.invalidState),
      ),
    );
  });

  test('discard removes the payload and references and hides the draft',
      () async {
    await insertCategory();
    await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(100),
      references: const <DraftReference>[
        DraftReference(entityId: _category, expectedRevision: 1),
      ],
    );
    await drafts.discard(_draftA);

    final record = await drafts.byId(_draftA);
    expect(record?.status, DraftStatus.discarded);
    expect(record?.payloadJson, isNull);
    expect(await drafts.find(formType: 'payment'), isNull);
    final refs = await vault.database.customSelect(
      'SELECT count(*) AS n FROM draft_references WHERE draft_id = ?',
      variables: [const Variable(_draftA)],
    ).getSingle();
    expect(refs.data['n'], 0);
  });

  test('a referenced record and its revision are stored', () async {
    await insertCategory();
    await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(100),
      references: const <DraftReference>[
        DraftReference(entityId: _category, expectedRevision: 4),
      ],
    );
    final row = await vault.database.customSelect(
      'SELECT expected_revision FROM draft_references WHERE draft_id = ? '
      'AND entity_id = ?',
      variables: const [Variable(_draftA), Variable(_category)],
    ).getSingle();
    expect(row.data['expected_revision'], 4);
  });

  test('a submitted draft cannot be discarded before its outcome', () async {
    await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: _payload(100),
    );
    await vault.database.customStatement(
      'UPDATE draft_headers SET status = ? WHERE id = ?',
      ['submitted', _draftA],
    );
    await expectLater(
      drafts.discard(_draftA),
      throwsA(
        isA<DraftError>()
            .having((e) => e.code, 'code', DraftErrorCode.invalidState),
      ),
    );
  });

  test('an old generation draft is not offered and cannot be saved', () async {
    await vault.database.customStatement(
      'INSERT INTO draft_headers (id, form_type, schema_version, db_epoch, '
      'created_at, updated_at, edit_revision, status) '
      'VALUES (?, ?, 1, ?, ?, ?, 1, ?)',
      [_draftA, 'payment', 'old-epoch', nowMs, nowMs, 'editing'],
    );
    expect(await drafts.list(formType: 'payment'), isEmpty);
    await expectLater(
      drafts.save(
        id: _draftA,
        formType: 'payment',
        schemaVersion: 1,
        payloadJson: _payload(100),
      ),
      throwsA(
        isA<DraftError>()
            .having((e) => e.code, 'code', DraftErrorCode.epochMismatch),
      ),
    );
  });

  test('an unreadable payload is kept and shown as unsupported', () async {
    await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 9,
      payloadJson: _payload(100),
    );
    final record = await drafts.markUnsupported(_draftA);
    expect(record.status, DraftStatus.unsupported);
    expect(record.payloadJson, _payload(100));
    expect(await drafts.find(formType: 'payment'), isNull);
    await drafts.discard(_draftA);
    expect((await drafts.byId(_draftA))?.payloadJson, isNull);
  });

  test('rejects a schema version below one', () async {
    await expectLater(
      drafts.save(
        id: _draftA,
        formType: 'payment',
        schemaVersion: 0,
        payloadJson: _payload(100),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('the payload bound is 256 KiB', () async {
    final atBound = '{"x":"${'a' * (DraftRepository.maxPayloadBytes - 8)}"}';
    expect(utf8.encode(atBound).length, DraftRepository.maxPayloadBytes);
    await drafts.save(
      id: _draftA,
      formType: 'payment',
      schemaVersion: 1,
      payloadJson: atBound,
    );
    final overBound = '{"x":"${'a' * (DraftRepository.maxPayloadBytes - 7)}"}';
    await expectLater(
      drafts.save(
        id: _draftB,
        formType: 'payment',
        schemaVersion: 1,
        payloadJson: overBound,
      ),
      throwsA(
        isA<DraftError>()
            .having((e) => e.code, 'code', DraftErrorCode.payloadTooLarge),
      ),
    );
  });

  test('a missing draft is a typed error, with no payload in the text',
      () async {
    await expectLater(
      drafts.discard('00000000-0000-7000-8000-0000000000ff'),
      throwsA(
        isA<DraftError>()
            .having((e) => e.code, 'code', DraftErrorCode.notFound),
      ),
    );
    expect(
      const DraftError(DraftErrorCode.notFound).toString(),
      'DraftError(notFound)',
    );
  });
}
