import 'package:contour/core/money.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/accounts/account_picker_sheet.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SectionScope(
          section: Section.wealth,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );

const _checking = AccountSummary(
  id: 'a',
  name: 'Checking',
  kind: AccountKind.bank,
  currencyCode: 'USD',
  balanceMinor: 645000,
);
const _visa = AccountSummary(
  id: 'b',
  name: 'Visa',
  kind: AccountKind.card,
  currencyCode: 'USD',
  balanceMinor: -124000,
);
const _noBalance = AccountSummary(
  id: 'c',
  name: 'Savings',
  kind: AccountKind.bank,
  currencyCode: 'USD',
  balanceMinor: null,
);

void main() {
  test('a card balance is owed and a Missing balance is null', () {
    expect(_visa.owes, isTrue);
    expect(_visa.balance, Money.fromMinor(-124000, Currency.usd));
    expect(_checking.owes, isFalse);
    expect(_noBalance.balance, isNull);
  });

  testWidgets('the picker shows exact balances, Owes and Missing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        AccountPickerSheet(
          accounts: const <AccountSummary>[_checking, _visa, _noBalance],
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('Checking'), findsOneWidget);
    expect(find.text(r'$6,450.00'), findsOneWidget);
    expect(find.text(r'Owes $1,240.00'), findsOneWidget);
    expect(find.text('Missing'), findsOneWidget);
    expect(find.text(r'-$1,240.00'), findsNothing);
  });

  testWidgets('a row returns the chosen account', (tester) async {
    AccountSummary? selected;
    await tester.pumpWidget(
      _wrap(
        AccountPickerSheet(
          accounts: const <AccountSummary>[_checking],
          onSelected: (account) => selected = account,
        ),
      ),
    );
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();
    expect(selected, _checking);
  });

  testWidgets('the empty picker is a known zero and offers Add',
      (tester) async {
    var added = 0;
    await tester.pumpWidget(
      _wrap(
        AccountPickerSheet(
          accounts: const <AccountSummary>[],
          onSelected: (_) {},
          onAdd: () => added += 1,
        ),
      ),
    );
    expect(find.text('None recorded'), findsOneWidget);
    await tester.tap(find.text('Add an account'));
    await tester.pumpAndSettle();
    expect(added, 1);
  });
}
