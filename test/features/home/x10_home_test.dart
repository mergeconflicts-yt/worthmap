// X10 (SCREENS X10): Home with a summary.
import 'package:contour/design/design.dart';
import 'package:contour/features/home/home_models.dart';
import 'package:contour/features/home/x10_home.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_home_gateway.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(
        section: Section.home,
        child: child,
      ),
    );

void main() {
  testWidgets('Home shows the summary values', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        X10Home(
          gateway: const FakeHomeGateway(),
          onInbox: () {},
          onSettings: () {},
          onSpending: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NET WORTH'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text &&
            (widget.data ?? '').replaceAll('\u200B', '').contains('187,822'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('18.8% of \$1,000,000 target · Dec 2040'),
      findsOneWidget,
    );
    expect(find.text(r'+$16,900'), findsOneWidget);
    expect(find.text('Quick look'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Card bill'), findsOneWidget);
    // The card tile's line is the card name, not an "Owes" prefix.
    expect(find.text('Visa card'), findsWidgets);
    expect(find.textContaining('Owes'), findsNothing);
    expect(find.text('+\$550 today'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('\$8,200'), findsOneWidget);
    expect(find.text('\$3,940'), findsOneWidget);
    expect(find.text('of \$5,200 limit · 76%'), findsOneWidget);
    // No number on X10 shows a decimal place.
    expect(find.text('35%'), findsOneWidget);
    expect(find.text('13%'), findsOneWidget);
    expect(find.text('52%'), findsOneWidget);
    expect(find.text('SHOW AS TABLE'), findsNothing);
    expect(find.text('Investments'), findsOneWidget);
    expect(find.text('Next 30 days'), findsOneWidget);
    expect(find.textContaining('Netflix'), findsWidgets);
  });

  testWidgets('This month tiles carry no icon and the meter stays inside', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        X10Home(
          gateway: const FakeHomeGateway(),
          onInbox: () {},
          onSettings: () {},
          onSpending: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('This month'),
      matching: find.byType(GlassCard),
    );
    expect(
      find.descendant(of: card, matching: find.byType(IconTile)),
      findsNothing,
    );
    final spentTile = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics &&
          (widget.properties.label ?? '').startsWith('Spent'),
    );
    expect(
      find.descendant(of: spentTile, matching: find.byType(CapsuleMeter)),
      findsOneWidget,
    );
    // The value keeps no cents and the share keeps no decimal place.
    expect(find.textContaining('.00'), findsNothing);
    expect(find.textContaining('76.0%'), findsNothing);
  });

  testWidgets('a missing balance is not zero', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final summary = demoSummary;
    await tester.pumpWidget(
      _app(
        X10Home(
          gateway: FakeHomeGateway(
            summary: HomeSummary(
              currencyCode: summary.currencyCode,
              month: summary.month,
              monthDay: summary.monthDay,
              monthDays: summary.monthDays,
              inboxCount: 0,
              repeatingCount: 0,
              accountCount: 0,
              netWorthSeries: const <HomeSeriesPoint>[],
              upcoming: const <HomeUpcomingItem>[],
            ),
          ),
          onInbox: () {},
          onSettings: () {},
          onSpending: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('—'),
      findsWidgets,
    );
    expect(
      find.text('No payments are due in the next 30 days.'),
      findsOneWidget,
    );
    expect(find.textContaining('target'), findsNothing);
    expect(find.text(r'$0.00'), findsNothing);
  });

  testWidgets('the target line masks its amount when amounts are hidden', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        HiddenAmountsScope(
          hidden: true,
          child: X10Home(
            gateway: const FakeHomeGateway(),
            onInbox: () {},
            onSettings: () {},
            onSpending: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('18.8% of \$······ target · Dec 2040'),
      findsOneWidget,
    );
    expect(find.textContaining(r'$1,000,000'), findsNothing);
  });
}
