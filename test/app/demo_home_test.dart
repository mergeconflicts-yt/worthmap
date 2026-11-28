// X10 with the demo composition: real balances, payments and limits.
import 'package:contour/app/app.dart';
import 'package:contour/app/demo/demo_composition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home shows the demo data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await DemoComposition.build();
    await tester.pumpWidget(ContourApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.text('Quick look'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    // A real number, not the Missing dash of the first-run Home.
    expect(find.textContaining('Add an account balance'), findsNothing);
    // The This month tile and the timeline legend both say "Money in".
    expect(find.text('Money in'), findsWidgets);
    expect(find.text('Spent'), findsOneWidget);
  });
}
