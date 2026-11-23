import 'dart:async';

import 'package:contour/app/router.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/add/x20_add_payment.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_payments_gateway.dart';

void main() {
  testWidgets('the X20 route opens the payment form in the Spending section',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      payments: FakePaymentsGateway(),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.build(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x20'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X20AddPayment), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    final context = tester.element(find.byType(X20AddPayment));
    expect(SectionScope.of(context), Section.spending);
  });

  testWidgets('a confirmed Save returns to the caller', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakePaymentsGateway();
    final router =
        ContourRouter(gate: const AlwaysOpenGate(), payments: gateway);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.build(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x20'),
    );
    await tester.pumpAndSettle();

    for (final digit in <String>['2', '4']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(PillPicker, 'Choose account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Paid with'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paid with'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, r'Save $24.00'));
    await tester.pumpAndSettle();

    expect(gateway.saved, hasLength(1));
    expect(find.byType(X20AddPayment), findsNothing);
    expect(find.text('Get started'), findsOneWidget);
    // The 5 s toast outlives the popped form; let its timer finish.
    await tester.pump(const Duration(seconds: 6));
  });
}
