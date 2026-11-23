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
    expect(find.textContaining('187,900'), findsOneWidget);
    expect(find.text('Quick look'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Card bill'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Investments'), findsOneWidget);
    expect(find.text('Next 30 days'), findsOneWidget);
    expect(find.textContaining('Netflix'), findsWidgets);
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
    expect(find.text(r'$0.00'), findsNothing);
  });
}
