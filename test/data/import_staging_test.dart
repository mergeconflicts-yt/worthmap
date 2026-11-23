// P3-16 (SPEC 8.6; flow F06 steps 4-6): staging, publication and withdrawal.
//
// The tests use a real in-memory vault and the P17 Inbox reads. They assert
// that staging writes no payment and that a withdrawal removes every staged
// row in one step.
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/imports.dart';
import 'package:contour/data/repositories/inbox.dart';
import 'package:flutter_test/flutter_test.dart';

const String _account = '00000000-0000-7000-8000-0000000000a1';

String _id(int n) => '00000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

List<int> _digest(int seed) => List<int>.generate(32, (i) => (i + seed) & 0xFF);

ImportRowDraft _row(int n, {int amount = -1250}) => ImportRowDraft(
      sourceKey: 'pdf:1:${n + 10}:$n',
      date: '2026-10-${(10 + n).toString().padLeft(2, '0')}',
      amountMinor: amount,
      currencyCode: 'USD',
      merchantName: 'Shop $n',
    );

void main() {
  late Vault vault;
  late CommandRepository commands;
  late InboxRepository inbox;
  late ImportStagingRepository imports;
  var entity = 0;
  final now = DateTime.utc(2026, 10, 20, 12);

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => now,
    );
    inbox = InboxRepository(
      db: vault.database,
      commands: commands,
      clockUtc: () => now,
      newEntityId: () {
        entity += 1;
        return _id(3000 + entity);
      },
    );
    imports = ImportStagingRepository(
      db: vault.database,
      clockUtc: () => now,
      newEntityId: () {
        entity += 1;
        return _id(4000 + entity);
      },
    );
    entity = 0;
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  ImportStageRequest request({
    int seed = 1,
    int rows = 2,
    bool allowReimport = false,
  }) =>
      ImportStageRequest(
        label: 'First Bank statement, October',
        fileDigest: _digest(seed),
        accountId: _account,
        templateFingerprint: 'fingerprint',
        allowReimport: allowReimport,
        rows: <ImportRowDraft>[for (var i = 0; i < rows; i++) _row(i)],
      );

  test('staging publishes the rows to the Inbox', () async {
    final result = await imports.stage(request());
    expect(result.staged, 2);
    expect(result.existing, 0);
    expect(await inbox.pendingCount(), 2);
    final page = await inbox.page();
    expect(page.rows.length, 2);
    final paymentCount = await vault.database
        .customSelect(
          'SELECT COUNT(*) AS n FROM transactions',
        )
        .getSingle();
    expect(paymentCount.data['n'], 0);
  });

  test('a second import of the same file asks first', () async {
    await imports.stage(request());
    expect(
      () => imports.stage(request()),
      throwsA(
        isA<ImportStageError>().having(
          (error) => error.code,
          'code',
          ImportStageErrorCode.duplicateFile,
        ),
      ),
    );
    final again = await imports.stage(request(allowReimport: true));
    expect(again.existing, 2);
    expect(again.staged, 0);
  });

  test('a known source key is never staged twice', () async {
    await imports.stage(request(rows: 2));
    final second = await imports.stage(request(seed: 2, rows: 3));
    expect(second.staged, 1);
    expect(second.existing, 2);
    expect(await inbox.pendingCount(), 3);
  });

  test('withdraw removes every staged row and keeps history out', () async {
    final result = await imports.stage(request());
    final withdrawn = await imports.withdraw(result.batchId);
    expect(withdrawn, 2);
    expect(await inbox.pendingCount(), 0);
    expect(await imports.history(), isEmpty);
    expect(
      () => imports.withdraw(result.batchId),
      throwsA(
        isA<ImportStageError>().having(
          (error) => error.code,
          'code',
          ImportStageErrorCode.withdrawn,
        ),
      ),
    );
  });

  test('withdraw is refused after one decided item', () async {
    final result = await imports.stage(request());
    await vault.database.customStatement(
      "UPDATE source_claims SET status = 'discarded' "
      'WHERE batch_id = ? AND source_identity_id = '
      '(SELECT MIN(source_identity_id) FROM source_claims WHERE batch_id = ?)',
      <Object?>[result.batchId, result.batchId],
    );
    expect(
      () => imports.withdraw(result.batchId),
      throwsA(
        isA<ImportStageError>().having(
          (error) => error.code,
          'code',
          ImportStageErrorCode.alreadyConfirmed,
        ),
      ),
    );
  });

  test('history carries the label and the counts', () async {
    await imports.stage(request());
    final rows = await imports.history();
    expect(rows.single.label, 'First Bank statement, October');
    expect(rows.single.staged, 2);
    expect(rows.single.status, 'review');
  });

  test('an empty import is a typed failure', () async {
    expect(
      () => imports.stage(request(rows: 0)),
      throwsA(
        isA<ImportStageError>().having(
          (error) => error.code,
          'code',
          ImportStageErrorCode.noRows,
        ),
      ),
    );
  });
}
