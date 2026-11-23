import 'package:contour/app/router.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/x42b_account_editor.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'x42b_account_editor_test.dart' show FakeAccountsGateway;

void main() {
  testWidgets('the C01 route opens the account editor in the Wealth section',
      (tester) async {
    final router = ContourRouter(gate: const AlwaysOpenGate());
    final config = router.build();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: config,
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your main account'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.byType(X42bAccountEditor), findsOneWidget);
    expect(find.text('ADD · ACCOUNT'), findsOneWidget);
    final context = tester.element(find.byType(X42bAccountEditor));
    expect(SectionScope.of(context), Section.wealth);
  });

  testWidgets('an injected gateway saves and returns to Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeAccountsGateway();
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      accounts: gateway,
    );
    final config = router.build();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: config,
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your main account'));
    await tester.pumpAndSettle();

    for (final digit in <String>['6', '4', '5', '0']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.enterText(find.byType(TextField).at(0), 'Checking');
    await tester.tap(find.text('Bank account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Save account'));
    await tester.pumpAndSettle();

    expect(gateway.calls, 1);
    expect(gateway.last!.openingBalanceMinor, 645000);
    expect(find.byType(X42bAccountEditor), findsNothing);
    expect(find.text('Get started'), findsOneWidget);
  });
}
