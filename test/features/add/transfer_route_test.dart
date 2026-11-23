import 'dart:async';

import 'package:contour/app/router.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/add/x20_add_payment.dart';
import 'package:contour/features/add/x26_transfer.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_payments_gateway.dart';
import 'fake_transfer_gateway.dart';

Widget _app(ContourRouter router) => MaterialApp.router(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router.build(),
    );

void main() {
  testWidgets('the X26 route opens the transfer form in the Spending section',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      transfers: FakeTransferGateway(),
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x26'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X26Transfer), findsOneWidget);
    expect(find.text('Save transfer'), findsOneWidget);
    final context = tester.element(find.byType(X26Transfer));
    expect(SectionScope.of(context), Section.spending);
  });

  testWidgets('the X20 Transfer segment opens X26 when it is released',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      payments: FakePaymentsGateway(),
      transfers: FakeTransferGateway(),
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x20');
    await tester.pumpAndSettle();
    expect(find.byType(X20AddPayment), findsOneWidget);

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    expect(find.byType(X26Transfer), findsOneWidget);
  });

  testWidgets('a confirmed transfer returns to the caller', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeTransferGateway();
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      payments: FakePaymentsGateway(),
      transfers: gateway,
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x20'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    for (final digit in <String>['1', '2', '4', '0']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(AppButton, r'Save $1,240.00'));
    await tester.pumpAndSettle();

    expect(gateway.saved, hasLength(1));
    expect(find.byType(X26Transfer), findsNothing);
    expect(find.byType(X20AddPayment), findsNothing);
    expect(find.text('Get started'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
