import 'dart:async';

import 'package:contour/app/router.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/spending/x30_spending.dart';
import 'package:contour/features/spending/x33_edit_limits.dart';
import 'package:contour/features/spending/x34_repeating.dart';
import 'package:contour/features/spending/x36_category_detail.dart';
import 'package:contour/features/spending/x37_all_payments.dart';
import 'package:contour/features/spending/x84_rules.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_payments_read_gateway.dart';
import 'fake_repeating_gateway.dart';
import 'fake_spending_gateway.dart';

Widget _app(ContourRouter router) => MaterialApp.router(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router.build(),
    );

void main() {
  testWidgets('the X30 route opens Spending in the Spending section',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      spending: FakeSpendingGateway(),
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x30'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X30Spending), findsOneWidget);
    final context = tester.element(find.byType(X30Spending));
    expect(SectionScope.of(context), Section.spending);
  });

  testWidgets('the X33 route opens the limits editor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      spending: FakeSpendingGateway(),
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x33'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X33EditLimits), findsOneWidget);
  });

  testWidgets('the X37 route opens all payments', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      spending: FakeSpendingGateway(),
      paymentsRead: FakePaymentsReadGateway(),
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x37'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X37AllPayments), findsOneWidget);
  });

  testWidgets('the X36 route opens one category', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      spending: FakeSpendingGateway(),
      paymentsRead: FakePaymentsReadGateway(),
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator)))
          .push('/x36', extra: 'cat-groceries'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X36CategoryDetail), findsOneWidget);
  });

  testWidgets('the X34 route opens repeating', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      spending: FakeSpendingGateway(),
      repeating: FakeRepeatingGateway(),
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x34'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X34Repeating), findsOneWidget);
  });

  testWidgets('the X84 route opens categories and rules', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      spending: FakeSpendingGateway(),
      repeating: FakeRepeatingGateway(),
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x84'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X84Rules), findsOneWidget);
  });
}
