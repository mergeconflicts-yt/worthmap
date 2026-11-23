// X10 test double: one fixed summary.
import 'package:contour/core/dates.dart';
import 'package:contour/core/percent.dart';
import 'package:contour/features/home/home_models.dart';
import 'package:decimal/decimal.dart';

final class FakeHomeGateway implements HomeGateway {
  const FakeHomeGateway({this.summary});

  final HomeSummary? summary;

  @override
  Future<HomeSummary> load() async => summary ?? demoSummary;
}

final HomeSummary demoSummary = HomeSummary(
  currencyCode: 'USD',
  month: LocalDate(2026, 10, 1),
  netWorthMinor: 18790000,
  netWorthChangeMinor: 1690000,
  netWorthSeries: <HomeSeriesPoint>[
    for (var i = 0; i < 12; i++)
      HomeSeriesPoint(
        month: LocalDate(
          2025 + ((10 + i) ~/ 12),
          ((10 + i) % 12) + 1,
          1,
        ),
        amountMinor: 17100000 + i * 153636,
      ),
  ],
  cashMinor: 2145000,
  cardOwedMinor: 124000,
  investmentsMinor: 12980000,
  subscriptionsMonthlyMinor: 2898,
  moneyInMinor: 820000,
  spentMinor: 394000,
  limitMinor: 520000,
  used: Percent.fromPoints(Decimal.fromInt(76)),
  monthGone: Percent.fromPoints(Decimal.fromInt(42)),
  monthDay: 13,
  monthDays: 31,
  inboxCount: 12,
  repeatingCount: 7,
  accountCount: 4,
  upcoming: <HomeUpcomingItem>[
    HomeUpcomingItem(
      date: LocalDate(2026, 10, 18),
      name: 'Netflix',
      amountMinor: -1799,
      currencyCode: 'USD',
      kind: 'subscription',
    ),
    HomeUpcomingItem(
      date: LocalDate(2026, 10, 20),
      name: 'Phone',
      amountMinor: -4500,
      currencyCode: 'USD',
      kind: 'subscription',
    ),
    HomeUpcomingItem(
      date: LocalDate(2026, 10, 28),
      name: 'Health',
      amountMinor: -21000,
      currencyCode: 'USD',
      kind: 'subscription',
    ),
  ],
  incomeSplit: const HomeIncomeSplit(
    moneyInMinor: 820000,
    investedMinor: 0,
    inCashMinor: 426000,
    currencyCode: 'USD',
  ),
);
