@Tags(<String>['golden'])
library;

import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/account_date_sheet.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/accounts/account_picker_sheet.dart';
import 'package:contour/features/accounts/account_setup_controller.dart';
import 'package:contour/features/accounts/x42b_account_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

final class FakeAccountsGateway implements AccountsGateway {
  @override
  Future<List<AccountSummary>> listAccounts() async => <AccountSummary>[];

  @override
  Future<AccountSummary> createAccount(AccountSetup setup) async =>
      AccountSummary(
        id: 'a',
        name: setup.name,
        kind: setup.kind,
        currencyCode: setup.currencyCode,
        balanceMinor: setup.kind.isLiability
            ? -setup.openingBalanceMinor
            : setup.openingBalanceMinor,
      );
}

AccountSetupController _draft({
  required AccountKind kind,
  required String name,
  required String amount,
}) {
  final controller = AccountSetupController(
    gateway: FakeAccountsGateway(),
    today: LocalDate(2026, 11, 22),
    kind: kind,
  )
    ..setName(name)
    ..setDate(LocalDate(2026, 11, 22));
  for (final key in amount.split('')) {
    controller.pressKey(key);
  }
  return controller;
}

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('account editor ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1800 : 2400),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _draft(
          kind: AccountKind.bank,
          name: 'Checking',
          amount: '6450',
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.wealth,
            textScale: scale,
            child: X42bAccountEditor(
              gateway: FakeAccountsGateway(),
              today: LocalDate(2026, 11, 22),
              controller: controller,
              onClose: () {},
              onSaved: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x42b_account_editor_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('account card editor ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1800 : 2400),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _draft(
          kind: AccountKind.card,
          name: 'Visa',
          amount: '1240',
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.wealth,
            textScale: scale,
            child: X42bAccountEditor(
              gateway: FakeAccountsGateway(),
              today: LocalDate(2026, 11, 22),
              controller: controller,
              onClose: () {},
              onSaved: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x42b_account_card_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('account date sheet ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.wealth,
            textScale: scale,
            child: Material(
              color: theme.$2.extension<ContourTokens>()!.surfacePage,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AppSheet(
                  title: 'Balance date',
                  semanticLabel: 'Choose the balance date',
                  children: <Widget>[
                    AccountDateSheet(initial: LocalDate(2026, 11, 22)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x42b_account_date_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('account picker ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.wealth,
            textScale: scale,
            child: Material(
              color: theme.$2.extension<ContourTokens>()!.surfacePage,
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: AppSheet(
                  title: 'Choose an account',
                  semanticLabel: 'Choose an account',
                  children: <Widget>[
                    AccountPickerSheet(
                      accounts: <AccountSummary>[
                        AccountSummary(
                          id: 'a',
                          name: 'Checking',
                          kind: AccountKind.bank,
                          currencyCode: 'USD',
                          balanceMinor: 645000,
                        ),
                        AccountSummary(
                          id: 'b',
                          name: 'Visa',
                          kind: AccountKind.card,
                          currencyCode: 'USD',
                          balanceMinor: -124000,
                        ),
                        AccountSummary(
                          id: 'c',
                          name: 'Savings',
                          kind: AccountKind.bank,
                          currencyCode: 'USD',
                          balanceMinor: null,
                        ),
                      ],
                      onSelected: _noop,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x42b_account_picker_${theme.$1}_${scale}x.png',
          ),
        );
      });
    }
  }
}

void _noop(AccountSummary account) {}
