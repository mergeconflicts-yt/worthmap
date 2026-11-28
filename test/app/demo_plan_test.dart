// X50 with the demo composition: the real occurrence reads.
import 'package:contour/app/app.dart';
import 'package:contour/app/demo/demo_composition.dart';
import 'package:contour/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Plan shows the demo occurrences on the calendar and the list',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await DemoComposition.build();
    await tester.pumpWidget(ContourApp(router: router));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppTabBar),
        matching: find.text('Plan'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLAN'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    // The demo seeds Netflix and Rent schedules; there is no income schedule,
    // so the card names the whole window.
    expect(find.text('Next 45 days'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
  });
}
