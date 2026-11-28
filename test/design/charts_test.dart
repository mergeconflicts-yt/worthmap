import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/design/design.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool hidden = false}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SectionScope(
      section: Section.spending,
      child: HiddenAmountsScope(
        hidden: hidden,
        child: SingleChildScrollView(child: child),
      ),
    ),
  );
}

Money _money(int major) => Money.fromMinor(major * 100, Currency.usd);

void main() {
  group('P19 ChartFrame', () {
    testWidgets('a chart has one label and an exact table', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const ChartFrame(
            label: 'Spent, October. 1 Oct \$10. 2 Oct \$20',
            chart: SizedBox(height: 80),
            table: ChartTable(
              columns: <String>['Date', 'Amount'],
              rows: <List<String>>[
                <String>['1 Oct', r'$10'],
                <String>['2 Oct', r'$20'],
              ],
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Spent, October. 1 Oct \$10. 2 Oct \$20'),
        findsOneWidget,
      );
      expect(find.text('Show as table'.toUpperCase()), findsOneWidget);
      expect(find.text(r'$10'), findsNothing);

      await tester.tap(find.text('Show as table'.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(r'$10'), findsOneWidget);
      expect(find.text(r'$20'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a preview chart has no table', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ChartFrame(
            label: 'Net worth, 12 months: \$182,410',
            preview: true,
            chart: SizedBox(height: 80),
          ),
        ),
      );
      expect(find.text('Show as table'.toUpperCase()), findsNothing);
    });

    testWidgets('an empty table shows the empty phrase', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ChartFrame(
            label: 'Spent. None recorded',
            emptyLabel: 'None recorded',
            chart: SizedBox(height: 80),
            table: ChartTable(
              columns: <String>['Date', 'Amount'],
              rows: <List<String>>[],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show as table'.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('None recorded'), findsOneWidget);
    });
  });

  group('P19 PeriodBarChart', () {
    testWidgets('exact values appear in the label and the table',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          PeriodBarChart(
            title: 'Spent',
            period: '1–13 Oct 2026',
            columns: const <String>['Date', 'Amount'],
            bars: <PeriodBar>[
              PeriodBar(label: '1', amount: _money(20)),
              PeriodBar(label: '2', amount: _money(30), current: true),
            ],
            average: _money(25),
            limit: _money(40),
          ),
        ),
      );

      final label = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((widget) => widget.properties.label)
          .whereType<String>()
          .join(' ');
      expect(label, contains(r'$20'));
      expect(label, contains(r'$30'));
      expect(label, contains(r'$25'));
      expect(label, contains(r'$40'));

      await tester.tap(find.text('Show as table'.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(r'$20'), findsOneWidget);
      expect(find.text(r'$30'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('hidden keeps the shape and masks text and label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          hidden: true,
          PeriodBarChart(
            title: 'Spent',
            period: '1–13 Oct 2026',
            columns: const <String>['Date', 'Amount'],
            bars: <PeriodBar>[
              PeriodBar(label: '1', amount: _money(20)),
            ],
          ),
        ),
      );

      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((widget) => widget.properties.label)
          .whereType<String>();
      expect(labels.join(' '), isNot(contains(r'$20')));
      expect(labels.join(' '), contains(hiddenMask));

      await tester.tap(find.text('Show as table'.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(r'$20'), findsNothing);
      expect(find.text('\$$hiddenMask'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('an incomplete period is named in the label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          PeriodBarChart(
            title: 'Spent',
            period: 'October',
            columns: const <String>['Date', 'Amount'],
            incompleteLabel: 'October is not closed yet',
            bars: <PeriodBar>[
              PeriodBar(
                label: 'Oct',
                amount: _money(20),
                incomplete: true,
              ),
            ],
          ),
        ),
      );
      final label = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((widget) => widget.properties.label)
          .whereType<String>()
          .join(' ');
      expect(label, contains('October is not closed yet'));
      semantics.dispose();
    });
  });

  group('P19 SplitBar', () {
    testWidgets('shares come from Percent.split and add to 100',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SplitBar(
            title: 'Needs and wants',
            period: 'October',
            columns: const <String>['Part', 'Amount', 'Share'],
            parts: <SplitBarPart>[
              SplitBarPart(
                name: 'Needs',
                amount: _money(2890),
                mark: ChartMark.needs,
              ),
              SplitBarPart(
                name: 'Wants',
                amount: _money(1050),
                mark: ChartMark.wants,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Show as table'.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('73.4%'), findsAtLeastNWidgets(1));
      expect(find.text('26.6%'), findsAtLeastNWidgets(1));
    });

    testWidgets('a known zero total has zero shares', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SplitBar(
            title: 'Needs and wants',
            period: 'October',
            columns: const <String>['Part', 'Amount', 'Share'],
            parts: <SplitBarPart>[
              SplitBarPart(
                name: 'Needs',
                amount: Money.zero(Currency.usd),
                mark: ChartMark.needs,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Show as table'.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('0%'), findsAtLeastNWidgets(1));
    });
  });

  group('P19 RingMeter and BillingStrip', () {
    testWidgets('a ring speaks the exact amount and limit', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          RingMeter(
            name: 'Groceries',
            value: _money(620),
            limit: _money(1200),
            leftLabel: 'left',
          ),
        ),
      );
      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((widget) => widget.properties.label)
          .whereType<String>()
          .join(' ');
      expect(labels, contains(r'Groceries, $620, $1,200, $580 left'));
      semantics.dispose();
    });

    testWidgets('a hidden ring masks the amount and keeps the name',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          hidden: true,
          RingMeter(
            name: 'Groceries',
            value: _money(620),
            limit: _money(1200),
            leftLabel: 'left',
          ),
        ),
      );
      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((widget) => widget.properties.label)
          .whereType<String>()
          .join(' ');
      expect(labels, contains('Groceries'));
      expect(labels, contains(hiddenMask));
      expect(labels, isNot(contains(r'$620')));
      semantics.dispose();
    });

    testWidgets('the billing strip states paid and due in the table',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          BillingStrip(
            title: 'Repeating',
            period: 'October',
            daysInMonth: 31,
            today: 13,
            paidLabel: 'Paid',
            dueLabel: 'Due',
            columns: const <String>['Date', 'Payment', 'Amount', 'State'],
            marks: <BillingMark>[
              BillingMark(
                day: 1,
                name: 'Rent',
                amount: _money(1800),
                paid: true,
              ),
              BillingMark(day: 18, name: 'Netflix', amount: _money(17)),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Show as table'.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
    });
  });

  test('the axis short form rounds through Decimal', () {
    expect(chartShortAmount(_money(303)), r'$303');
    expect(chartShortAmount(_money(150000)), r'$150K');
    expect(chartShortAmount(_money(1200000)), r'$1.2M');
  });

  group('GlyphTimeline', () {
    final start = LocalDate(2026, 10, 13);

    Widget timeline({
      bool hidden = false,
      int? incomeDayIndex,
      List<TimelineItem>? items,
    }) {
      return _wrap(
        SizedBox(
          width: 380,
          child: GlyphTimeline(
            title: 'Next 30 days',
            windowLabel: '13 Oct to 12 Nov',
            start: start,
            incomeDayIndex: incomeDayIndex,
            hidden: hidden,
            items: items ??
                <TimelineItem>[
                  TimelineItem(
                    dayIndex: 5,
                    dateLabel: '18 Oct',
                    name: 'Netflix',
                    amount: Money.fromMinor(1799, Currency.usd),
                    mark: ChartMark.spending,
                  ),
                  TimelineItem(
                    dayIndex: 7,
                    dateLabel: '20 Oct',
                    name: 'Phone',
                    amount: Money.fromMinor(4500, Currency.usd),
                    mark: ChartMark.spending,
                  ),
                  TimelineItem(
                    dayIndex: 9,
                    dateLabel: '22 Oct',
                    name: 'Visa card',
                    amount: Money.fromMinor(124000, Currency.usd),
                    mark: ChartMark.spending,
                  ),
                ],
          ),
        ),
        hidden: hidden,
      );
    }

    testWidgets('shows today, the day scale and the item labels', (
      tester,
    ) async {
      await tester.pumpWidget(timeline());
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('13 OCT'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text(r'$17.99'), findsOneWidget);
      expect(find.text(r'$45'), findsOneWidget);
      expect(find.text(r'$1,240'), findsOneWidget);
    });

    testWidgets('the legend names the flow groups', (tester) async {
      await tester.pumpWidget(timeline());
      await tester.pumpAndSettle();

      expect(find.text('Spending'), findsOneWidget);
      expect(find.text('Investing'), findsOneWidget);
      expect(find.text('Money in'), findsOneWidget);
    });

    testWidgets('hidden amounts mask the labels, names and days stay', (
      tester,
    ) async {
      await tester.pumpWidget(timeline(hidden: true));
      await tester.pumpAndSettle();

      expect(find.text('\$······'), findsNWidgets(3));
      expect(find.text(r'$17.99'), findsNothing);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('13 OCT'), findsOneWidget);
    });

    testWidgets('an empty window shows the empty phrase', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 380,
            child: GlyphTimeline(
              title: 'Next 30 days',
              windowLabel: '13 Oct to 12 Nov',
              start: start,
              emptyLabel: 'None recorded',
              items: const <TimelineItem>[],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('None recorded'), findsOneWidget);
    });

    testWidgets('the axis scrolls sideways and draws after the next income', (
      tester,
    ) async {
      await tester.pumpWidget(timeline(incomeDayIndex: 19));
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(GlyphTimeline),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.pixels, 0);
      await tester.drag(find.byType(GlyphTimeline), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
    });
  });
}
