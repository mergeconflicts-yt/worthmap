import 'package:contour/design/design.dart';
import 'package:contour/features/spending/spending_models.dart';
import 'package:contour/features/spending/x30_spending.dart';
import 'package:contour/features/spending/x33_edit_limits.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_spending_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.spending, child: child),
    );

void main() {
  testWidgets('X30 shows the hero, the chips, the rings and the rows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var where = 0;
    await tester.pumpWidget(
      _wrap(
        X30Spending(
          gateway: FakeSpendingGateway(),
          onWhereItGoes: () => where += 1,
          onAllPayments: () {},
          onRepeating: () {},
          onMoneyIn: () {},
          onBudget: () {},
          onEditLimits: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SPENT'), findsOneWidget);
    expect(find.textContaining('3,940'), findsWidgets);
    expect(find.textContaining('5,200'), findsWidgets);
    expect(find.textContaining('1,260'), findsWidgets);
    expect(find.text('1W'), findsOneWidget);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('6M'), findsOneWidget);
    expect(find.text('1Y'), findsOneWidget);
    expect(find.text('By category'), findsOneWidget);
    expect(find.byType(SplitStrip), findsOneWidget);
    expect(find.text('Needs'), findsOneWidget);
    expect(find.text('Wants'), findsOneWidget);
    expect(find.text('Where it goes'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Money in'), findsOneWidget);
    expect(find.text('Repeating'), findsOneWidget);
    expect(find.text('All payments'), findsOneWidget);
    expect(find.text('Edit limits'), findsOneWidget);
    expect(find.textContaining('7 payments'), findsOneWidget);
    expect(find.textContaining('3 changes'), findsOneWidget);
    expect(find.textContaining('2,084'), findsOneWidget);
    expect(find.textContaining('9,267'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('8 categories'), findsOneWidget);
    expect(find.byType(RingMeterGrid), findsOneWidget);
    expect(find.byType(AppIcon), findsWidgets);

    await tester.tap(find.text('Where it goes'));
    await tester.pump();
    expect(where, 1);
  });

  testWidgets('a chip changes the number and keeps one control row',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(X30Spending(gateway: FakeSpendingGateway())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('6M'));
    await tester.pumpAndSettle();

    expect(find.textContaining('21,080'), findsWidgets);
    expect(find.textContaining('within the limit'), findsOneWidget);
    expect(find.byType(ChipRow), findsOneWidget);
  });

  testWidgets('a closed period over its limit says how much', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSpendingGateway();
    final base = gateway.views[SpendingPeriod.sixMonths]!;
    gateway.views[SpendingPeriod.sixMonths] = SpendingView(
      period: base.period,
      rangeStart: base.rangeStart,
      rangeEnd: base.rangeEnd,
      month: base.month,
      currencyCode: base.currencyCode,
      partial: false,
      moneyOutMinor: 2700000,
      limitMinor: 2600000,
      leftMinor: -100000,
      used: base.used,
      sameDaysPreviousMinor: null,
      monthGone: base.monthGone,
      monthDay: base.monthDay,
      monthDays: base.monthDays,
      categories: base.categories,
      buckets: base.buckets,
    );
    await tester.pumpWidget(
      _wrap(X30Spending(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('6M'));
    await tester.pumpAndSettle();

    expect(find.textContaining(r'$1,000 over the limit'), findsOneWidget);
  });

  testWidgets('X33 removes a limit and saves the exact map', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSpendingGateway();
    await tester.pumpWidget(
      _wrap(
        X33EditLimits(
          gateway: gateway,
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly limits'), findsOneWidget);
    expect(find.textContaining('5,200'), findsWidgets);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text(r'$1,800.00').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Limit for Rent'), findsOneWidget);

    await tester.tap(find.text('Remove the limit'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Save').last);
    await tester.pumpAndSettle();

    expect(gateway.saveCalls, 1);
    expect(gateway.savedLimits!['rent'], 0);
  });
}
