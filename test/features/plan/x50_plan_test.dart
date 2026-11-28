import 'package:contour/design/design.dart';
import 'package:contour/features/plan/x50_plan.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_plan_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.plan, child: child),
    );

void main() {
  testWidgets('X50 shows the calendar, the glyphs and the payment lists',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(X50Plan(gateway: FakePlanGateway())));
    await tester.pumpAndSettle();

    expect(find.text('PLAN'), findsOneWidget);
    expect(find.text('Nov 2026'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('SUN'), findsOneWidget);
    expect(find.text('Before next income'), findsOneWidget);
    expect(find.text('From next income'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.textContaining('Investment'), findsOneWidget);
    expect(find.textContaining('Income'), findsWidgets);
  });

  testWidgets('X50 opens the day sheet from a day with events', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(X50Plan(gateway: FakePlanGateway())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30').first);
    await tester.pumpAndSettle();

    expect(find.text('30 November 2026'), findsOneWidget);
    expect(find.text('Rent'), findsWidgets);
  });

  testWidgets('X50 shows the load failure state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(X50Plan(gateway: FakePlanGateway(fail: true))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load Plan.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
