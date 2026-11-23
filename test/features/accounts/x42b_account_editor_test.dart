import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/account_date_sheet.dart';
import 'package:contour/features/accounts/account_draft.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/accounts/account_setup_controller.dart';
import 'package:contour/features/accounts/x42b_account_editor.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeAccountsGateway implements AccountsGateway {
  AccountSetup? last;
  int calls = 0;
  Object? failure;

  @override
  Future<List<AccountSummary>> listAccounts() async => <AccountSummary>[];

  @override
  Future<AccountSummary> createAccount(AccountSetup setup) async {
    calls += 1;
    last = setup;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return AccountSummary(
      id: 'account-1',
      name: setup.name,
      kind: setup.kind,
      currencyCode: setup.currencyCode,
      balanceMinor: setup.kind.isLiability
          ? -setup.openingBalanceMinor
          : setup.openingBalanceMinor,
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.wealth, child: child),
    );

class _Harness {
  _Harness({this.controller, this.drafts}) : gateway = FakeAccountsGateway();

  final FakeAccountsGateway gateway;
  final AccountSetupController? controller;
  final AccountDraftStore? drafts;
  AccountSummary? saved;
  int closed = 0;

  Widget build() => _wrap(
        X42bAccountEditor(
          gateway: gateway,
          today: LocalDate(2026, 11, 22),
          controller: controller,
          drafts: drafts,
          onClose: () => closed += 1,
          onSaved: (account) => saved = account,
        ),
      );
}

Future<void> _pump(WidgetTester tester, _Harness harness) async {
  await tester.binding.setSurfaceSize(const Size(600, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(harness.build());
  await tester.pumpAndSettle();
}

Future<void> _enterAmount(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.text(digit).last);
    await tester.pump();
  }
}

void main() {
  testWidgets('the fresh form shows Missing and a disabled Save',
      (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    expect(find.text('Missing'), findsOneWidget);
    expect(find.text('Balance today'), findsOneWidget);
    final save = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Save account'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('amount first, then one type choice, saves once', (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    await _enterAmount(tester, '6450');
    expect(find.text('6,450'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Checking');
    await tester.tap(find.text('Bank account'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Save account'));
    await tester.pumpAndSettle();

    expect(harness.gateway.calls, 1);
    expect(harness.gateway.last!.name, 'Checking');
    expect(harness.gateway.last!.openingBalanceMinor, 645000);
    expect(harness.saved, isNotNull);
    expect(harness.saved!.kind, AccountKind.bank);
  });

  testWidgets('an entered zero saves as a real balance', (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    await _enterAmount(tester, '0');
    expect(find.text('0'), findsWidgets);
    await tester.enterText(find.byType(TextField).at(0), 'Wallet');
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Save account'));
    await tester.pumpAndSettle();

    expect(harness.gateway.last!.openingBalanceMinor, 0);
    expect(harness.saved, isNotNull);
  });

  testWidgets('a card shows the owed amount as Owes', (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    await _enterAmount(tester, '1240');
    await tester.enterText(find.byType(TextField).at(0), 'Visa');
    await tester.tap(find.text('Credit card'));
    await tester.pumpAndSettle();
    // The chip sits below the fold; bring the amount block back.
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();

    expect(find.textContaining('Owes'), findsOneWidget);
    expect(find.textContaining(r'-$'), findsNothing);
    expect(find.textContaining('1,240'), findsWidgets);
  });

  testWidgets('a failed save keeps every entry and names the reason',
      (tester) async {
    final harness = _Harness();
    harness.gateway.failure = const AccountsError(AccountsErrorCode.notWired);
    await _pump(tester, harness);

    await _enterAmount(tester, '500');
    await tester.enterText(find.byType(TextField).at(0), 'Savings');
    await tester.tap(find.text('Bank account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Save account'));
    await tester.pumpAndSettle();

    expect(
      find.text('Account setup is not connected in this build.'),
      findsOneWidget,
    );
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('500'), findsWidgets);
    expect(harness.saved, isNull);
  });

  testWidgets('Close writes nothing', (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);
    await _enterAmount(tester, '500');
    await tester.tap(find.byType(AppIconButton).first);
    await tester.pumpAndSettle();
    expect(harness.closed, 1);
    expect(harness.gateway.calls, 0);
  });

  testWidgets('the date sheet sets a real inclusive date', (tester) async {
    final controller = AccountSetupController(
      gateway: FakeAccountsGateway(),
      today: LocalDate(2026, 11, 22),
    );
    final harness = _Harness(controller: controller);
    await _pump(tester, harness);

    await tester.tap(find.text('Balance date'));
    await tester.pumpAndSettle();
    expect(find.text('Use date'), findsOneWidget);

    final sheetFields = find.descendant(
      of: find.byType(AccountDateSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(sheetFields.at(0), '13');
    await tester.enterText(sheetFields.at(1), '10');
    await tester.enterText(sheetFields.at(2), '2026');
    await tester.tap(find.text('Use date'));
    await tester.pumpAndSettle();

    expect(controller.openingDate, LocalDate(2026, 10, 13));
    expect(find.text('Use date'), findsNothing);
    controller.dispose();
  });

  testWidgets('the date sheet rejects a day that does not exist',
      (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    await tester.tap(find.text('Balance date'));
    await tester.pumpAndSettle();
    final sheetFields = find.descendant(
      of: find.byType(AccountDateSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(sheetFields.at(0), '31');
    await tester.enterText(sheetFields.at(1), '2');
    await tester.enterText(sheetFields.at(2), '2026');
    await tester.tap(find.text('Use date'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a date as YYYY-MM-DD.'), findsOneWidget);
    expect(find.text('Use date'), findsOneWidget);
  });

  testWidgets('a prepared controller shows a known balance', (tester) async {
    final gateway = FakeAccountsGateway();
    final controller = AccountSetupController(
      gateway: gateway,
      today: LocalDate(2026, 11, 22),
      kind: AccountKind.bank,
    )
      ..setName('Checking')
      ..setDate(LocalDate(2026, 10, 13));
    for (final key in <String>['6', '4', '5', '0']) {
      controller.pressKey(key);
    }
    await _pump(tester, _Harness(controller: controller));

    expect(find.text('6,450'), findsOneWidget);
    expect(find.text('Checking'), findsOneWidget);
    expect(
      find.text('13 Oct 2026'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Save account'))
          .onPressed,
      isNotNull,
    );
    controller.dispose();
  });

  testWidgets('a stored draft resumes and Discard removes it', (tester) async {
    final store = MemoryAccountDraftStore()
      ..draft = AccountDraft(
        name: 'Savings',
        kind: AccountKind.bank,
        currencyCode: 'USD',
        amountText: '1200',
        date: LocalDate(2026, 10, 1),
        countsAsCash: true,
        includeInNetWorth: true,
      );
    final harness = _Harness(drafts: store);
    await _pump(tester, harness);

    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('1,200'), findsOneWidget);
    expect(find.text('1 Oct 2026'), findsOneWidget);

    await tester.ensureVisible(find.text('Discard draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();

    expect(store.draft, isNull);
    expect(harness.closed, 1);
  });

  testWidgets('an unsupported draft shows one factual line', (tester) async {
    final harness = _Harness(drafts: const _UnsupportedStore());
    await _pump(tester, harness);

    await tester.ensureVisible(find.textContaining('A saved draft'));
    expect(find.textContaining('A saved draft'), findsOneWidget);
    expect(find.text('Discard draft'), findsOneWidget);
  });
}

final class _UnsupportedStore implements AccountDraftStore {
  const _UnsupportedStore();

  @override
  Future<AccountDraftLoad> load() async => const UnsupportedAccountDraft();

  @override
  Future<void> save(AccountDraft draft) async {}

  @override
  Future<void> discard() async {}
}
