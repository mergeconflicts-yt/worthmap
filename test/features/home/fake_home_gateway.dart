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
  netWorthMinor: 18790000,
  cashMinor: 2145000,
  cardOwedMinor: 124000,
  moneyInMinor: 820000,
  spentMinor: 394000,
  limitMinor: 520000,
  used: Percent.fromPoints(Decimal.fromInt(76)),
  monthGone: Percent.fromPoints(Decimal.fromInt(42)),
  monthDay: 13,
  monthDays: 31,
  inboxCount: 12,
  repeatingCount: 7,
  recent: <HomeRecentPayment>[
    HomeRecentPayment(
      id: 'p1',
      date: LocalDate(2026, 10, 13),
      amountMinor: -3175,
      currencyCode: 'USD',
      merchantName: 'PX Market',
      categoryName: 'Groceries',
    ),
    HomeRecentPayment(
      id: 'p2',
      date: LocalDate(2026, 10, 12),
      amountMinor: -5200,
      currencyCode: 'USD',
      merchantName: 'Cafe Nero',
      categoryName: 'Dining',
    ),
    HomeRecentPayment(
      id: 'p3',
      date: LocalDate(2026, 10, 10),
      amountMinor: -12000,
      currencyCode: 'USD',
      merchantName: 'City power',
      categoryName: 'Utilities',
    ),
    HomeRecentPayment(
      id: 'p4',
      date: LocalDate(2026, 10, 9),
      amountMinor: -1799,
      currencyCode: 'USD',
      merchantName: 'Netflix',
      categoryName: 'Subscriptions',
    ),
    HomeRecentPayment(
      id: 'p5',
      date: LocalDate(2026, 10, 8),
      amountMinor: -8412,
      currencyCode: 'USD',
      merchantName: 'Whole Foods',
      categoryName: 'Groceries',
    ),
  ],
);
