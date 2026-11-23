import 'package:contour/core/dates.dart';
import 'package:contour/features/accounts/account_draft.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

AccountDraft _draft() => AccountDraft(
      name: 'Checking',
      kind: AccountKind.bank,
      currencyCode: 'USD',
      amountText: '6450',
      date: LocalDate(2026, 10, 13),
      countsAsCash: true,
      includeInNetWorth: true,
    );

void main() {
  test('a draft round-trips through the versioned JSON', () {
    final json = AccountDraftJson.encode(_draft());
    final decoded = AccountDraftJson.decode(json);
    expect(decoded, isNotNull);
    expect(decoded!.name, 'Checking');
    expect(decoded.kind, AccountKind.bank);
    expect(decoded.amountText, '6450');
    expect(decoded.date, LocalDate(2026, 10, 13));
    expect(decoded.countsAsCash, isTrue);
  });

  test('a null kind is a valid draft', () {
    final draft = AccountDraft(
      name: '',
      kind: null,
      currencyCode: 'USD',
      amountText: '',
      date: LocalDate(2026, 11, 22),
      countsAsCash: true,
      includeInNetWorth: true,
    );
    expect(
      AccountDraftJson.decode(AccountDraftJson.encode(draft))!.kind,
      isNull,
    );
  });

  test('another schema version is unsupported', () {
    final json = AccountDraftJson.encode(_draft());
    json['schema'] = 2;
    expect(AccountDraftJson.decode(json), isNull);
  });

  test('a bad date, kind or type is unsupported', () {
    final base = AccountDraftJson.encode(_draft());
    expect(
      AccountDraftJson.decode(<String, Object?>{...base, 'date': '2026-02-31'}),
      isNull,
    );
    expect(
      AccountDraftJson.decode(<String, Object?>{...base, 'kind': 'gold'}),
      isNull,
    );
    expect(
      AccountDraftJson.decode(<String, Object?>{...base, 'amount': 5}),
      isNull,
    );
  });
}
