// X40 with the demo composition: the real account reads.
import 'package:contour/app/app.dart';
import 'package:contour/app/demo/demo_composition.dart';
import 'package:contour/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Wealth shows the demo net worth and the own/owe card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await DemoComposition.build();
    await tester.pumpWidget(ContourApp(router: router));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppTabBar),
        matching: find.text('Wealth'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.textContaining('184,028'), findsWidgets);
    expect(find.text('You own / You owe'), findsOneWidget);
    expect(find.text('Cash and bank'), findsOneWidget);
    expect(find.text('Investments'), findsWidgets);
    expect(find.text('Cards'), findsOneWidget);
    // The demo history covers 12 months but not 5 years.
    expect(find.text('1Y'), findsOneWidget);
  });
}
