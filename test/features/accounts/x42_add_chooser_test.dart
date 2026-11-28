// X42 (SPEC 6.6; SCREENS X42): Add, choose a type.
//
// The chooser lists the groups the forms cover, shows the count per group and
// returns the chosen type. It writes nothing.

import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/accounts/x42_add_chooser.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Fake implements AccountsGateway {
  _Fake(this.rows);

  final List<AccountSummary> rows;

  @override
  Future<List<AccountSummary>> listAccounts() async => rows;

  @override
  Future<AccountSummary> createAccount(AccountSetup setup) async =>
      throw UnimplementedError();
}

AccountSummary _account(String id, AccountKind kind) => AccountSummary(
      id: id,
      name: id,
      kind: kind,
      currencyCode: 'USD',
      balanceMinor: 100,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.wealth, child: child),
    );

void main() {
  testWidgets('X42 lists the groups with their counts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X42AddChooser(
          gateway: _Fake(<AccountSummary>[
            _account('a', AccountKind.bank),
            _account('b', AccountKind.cash),
            _account('c', AccountKind.card),
          ]),
          onClose: () {},
          onPick: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ADD · CHOOSE A TYPE'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Something you own or owe'), findsOneWidget);
    expect(find.text('Cash'), findsWidgets);
    expect(find.text('Things'), findsOneWidget);
    expect(find.text('You owe'), findsOneWidget);
    expect(find.text('Other'), findsWidgets);
    expect(find.text('2 ACCOUNTS'), findsOneWidget);
    expect(find.text('1 ACCOUNT'), findsOneWidget);
    expect(find.text('NONE YET'), findsWidgets);
    expect(find.text('Property'), findsOneWidget);
    expect(find.text('Credit card'), findsOneWidget);
    expect(find.text('Money lent'), findsOneWidget);
  });

  testWidgets('X42 returns the chosen type and closes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AccountKind? picked;
    var closed = false;
    await tester.pumpWidget(
      _wrap(
        X42AddChooser(
          gateway: _Fake(const <AccountSummary>[]),
          onClose: () => closed = true,
          onPick: (kind) => picked = kind,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Property'));
    expect(picked, AccountKind.property);

    await tester.tap(find.byType(AppIconButton));
    expect(closed, isTrue);
  });
}
