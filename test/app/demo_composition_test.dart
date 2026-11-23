import 'dart:async';

import 'package:contour/app/app.dart';
import 'package:contour/app/demo/demo_composition.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/history/c06_history.dart';
import 'package:contour/features/spending/x30_spending.dart';
import 'package:contour/features/spending/x37_all_payments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('the demo composition starts on the menu with live data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await DemoComposition.build();
    await tester.pumpWidget(ContourApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.text('Quick look'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Spending'));
    await tester.pumpAndSettle();

    expect(find.byType(X30Spending), findsOneWidget);
    expect(find.text('By category'), findsOneWidget);
    expect(find.text('Rent'), findsWidgets);
    expect(find.textContaining('4,900'), findsWidgets);
  });

  testWidgets('the demo shows the seeded payments and the history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await DemoComposition.build();
    await tester.pumpWidget(ContourApp(router: router));
    await tester.pumpAndSettle();

    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x37'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X37AllPayments), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);
    expect(find.text('Whole Foods'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(Navigator))).go('/c06');
    await tester.pumpAndSettle();

    expect(find.byType(C06History), findsOneWidget);
    expect(find.text('Payment added'), findsWidgets);
    expect(find.widgetWithText(AppButton, 'Undo'), findsWidgets);
  });
}
