import 'package:contour/design/design.dart';
import 'package:contour/features/wealth/x40_wealth.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_wealth_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.wealth, child: child),
    );

void main() {
  testWidgets('X40 shows the net worth, the change and the own/owe card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(X40Wealth(gateway: FakeWealthGateway())),
    );
    await tester.pumpAndSettle();

    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.textContaining('187,900'), findsWidgets);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('1Y'), findsOneWidget);
    expect(find.text('5Y'), findsOneWidget);
    expect(find.text('You own / You owe'), findsOneWidget);
    expect(find.text('Cash and bank'), findsOneWidget);
    expect(find.text('Investments'), findsWidgets);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.textContaining('1,000,000'), findsOneWidget);
  });

  testWidgets('X40 shows Missing for a period with no start reading',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(X40Wealth(gateway: FakeWealthGateway())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('5Y'));
    await tester.pumpAndSettle();
    expect(find.text('Missing'), findsWidgets);
  });

  testWidgets('X40 shows the load failure state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(X40Wealth(gateway: FakeWealthGateway(fail: true))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load Wealth.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
