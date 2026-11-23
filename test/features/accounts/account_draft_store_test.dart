import 'package:contour/app/account_draft_store.dart';
import 'package:contour/core/dates.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/drafts.dart';
import 'package:contour/features/accounts/account_draft.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

String _id(int n) =>
    '00000000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

void main() {
  late Vault vault;
  late DraftRepository drafts;
  late SqlAccountDraftStore store;
  var nextId = 100;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    drafts = DraftRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    store = SqlAccountDraftStore(
      drafts: drafts,
      newId: () => _id(nextId++),
    );
  });

  tearDown(() async {
    await vault.close();
  });

  AccountDraft draft({String amount = '6450'}) => AccountDraft(
        name: 'Checking',
        kind: AccountKind.bank,
        currencyCode: 'USD',
        amountText: amount,
        date: LocalDate(2026, 10, 13),
        countsAsCash: true,
        includeInNetWorth: true,
      );

  test('a C01 draft saves, resumes and discards', () async {
    expect(await store.load(), isA<NoAccountDraft>());

    await store.save(draft());
    final loaded = await store.load();
    expect(loaded, isA<LoadedAccountDraft>());
    final resumed = (loaded as LoadedAccountDraft).draft;
    expect(resumed.name, 'Checking');
    expect(resumed.amountText, '6450');
    expect(resumed.date, LocalDate(2026, 10, 13));

    await store.save(draft(amount: '6451'));
    final again = await store.load();
    expect((again as LoadedAccountDraft).draft.amountText, '6451');

    await store.discard();
    expect(await store.load(), isA<NoAccountDraft>());
    expect(await drafts.list(formType: 'account'), isEmpty);
  });

  test('an older schema is unsupported and kept', () async {
    await drafts.save(
      id: _id(500),
      formType: 'account',
      schemaVersion: AccountDraftJson.schemaVersion + 1,
      payloadJson: '{}',
    );
    final loaded = await store.load();
    expect(loaded, isA<UnsupportedAccountDraft>());
    expect(await drafts.list(formType: 'account'), hasLength(1));

    await store.discard();
    expect(await drafts.list(formType: 'account'), isEmpty);
  });

  test('an unreadable payload is unsupported', () async {
    await drafts.save(
      id: _id(501),
      formType: 'account',
      schemaVersion: AccountDraftJson.schemaVersion,
      payloadJson: '{}',
    );
    expect(await store.load(), isA<UnsupportedAccountDraft>());
  });
}
