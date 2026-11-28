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
    expect(find.textContaining('187,822'), findsWidgets);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('1Y'), findsOneWidget);
    expect(find.text('5Y'), findsOneWidget);
    expect(find.text('YOU OWN'), findsOneWidget);
    expect(find.text('YOU OWE'), findsOneWidget);
    expect(find.text('Cash and bank'), findsOneWidget);
    expect(find.text('Investments'), findsWidgets);
    expect(find.text('Retirement'), findsOneWidget);
    expect(find.textContaining('None recorded'), findsWidgets);
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

  testWidgets('X40 puts the share baseline on the net worth baseline',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(X40Wealth(gateway: FakeWealthGateway())),
    );
    await tester.pumpAndSettle();

    double baselineOf(String text) {
      final finder = find.text(text);
      final widget = tester.widget<Text>(finder);
      final context = tester.element(finder);
      final style = DefaultTextStyle.of(context).style.merge(widget.style);
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final distance =
          painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      painter.dispose();
      return tester.getTopLeft(finder).dy + distance;
    }

    expect(baselineOf('+9.9%'), closeTo(baselineOf('187,822'), 0.5));
    expect(
      tester.getRect(find.text('+9.9%')).top,
      greaterThan(tester.getRect(find.text(r'+$16,900')).top),
    );
  });

  testWidgets('X40 keeps the target line 4 pt under the hero, as X10',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(X40Wealth(gateway: FakeWealthGateway())),
    );
    await tester.pumpAndSettle();

    final hero = tester.getRect(find.byType(ObHero));
    final target = tester.getRect(find.byType(TargetProgressLine));
    expect(target.top - hero.bottom, Space.xs);
  });

  testWidgets('X40 type tiles share one width and height', (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(X40Wealth(gateway: FakeWealthGateway())),
    );
    await tester.pumpAndSettle();

    final tiles = find.byType(TypeTile);
    expect(tiles, findsNWidgets(9));
    final first = tester.getSize(tiles.first);
    for (var i = 1; i < 9; i++) {
      expect(tester.getSize(tiles.at(i)), first);
    }
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
