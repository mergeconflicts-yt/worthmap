// X40: in-memory Wealth reads. It writes no database.
import 'package:contour/core/dates.dart';
import 'package:contour/core/percent.dart';
import 'package:contour/domain/periods/period_math.dart';
import 'package:contour/features/wealth/wealth_models.dart';
import 'package:decimal/decimal.dart';

/// The X40 sample values from SCREENS, with no database.
final class FakeWealthGateway implements WealthGateway {
  FakeWealthGateway({this.fail = false});

  /// Throws a [WealthError] from [load] when true.
  final bool fail;

  @override
  Future<WealthView> load(WealthPeriod period) async {
    if (fail) {
      throw const WealthError(WealthErrorCode.loadFailed);
    }
    final first = LocalDate(2025, 12, 28);
    final last = LocalDate(2026, 11, 28);
    final points = <WealthPoint>[
      for (var i = 0; i < 12; i++)
        WealthPoint(
          date: addMonths(first, i),
          netWorthMinor: 17100000 + i * 140000,
          investmentsMinor: 11980000 + i * 90000,
          cashMinor: 2145000,
        ),
      WealthPoint(
        date: last,
        netWorthMinor: 18790000,
        investmentsMinor: 12980000,
        cashMinor: 2145000,
      ),
    ];
    final start = points.first.netWorthMinor;
    final end = points.last.netWorthMinor;
    final share = Percent.fromPoints(Decimal.parse('9.9'));
    return WealthView(
      currencyCode: 'USD',
      today: last,
      period: period,
      netWorthMinor: end,
      changeMinor: period == WealthPeriod.fiveYears ? null : end! - start!,
      changeShare: period == WealthPeriod.fiveYears ? null : share,
      points: period == WealthPeriod.fiveYears
          ? <WealthPoint>[points.first, points.last]
          : points,
      ownMinor: 19754000,
      oweMinor: 964000,
      ownTypes: const <WealthType>[
        WealthType(
          kind: WealthTypeKind.cash,
          amountMinor: 2145000,
          count: 2,
        ),
        WealthType(
          kind: WealthTypeKind.investments,
          amountMinor: 12980000,
          count: 1,
        ),
      ],
      oweTypes: const <WealthType>[
        WealthType(
          kind: WealthTypeKind.card,
          amountMinor: 964000,
          count: 1,
        ),
      ],
      accountCount: 9,
      inboxCount: 2,
      unvestedMinor: 3159500,
      owedToYouMinor: 264000,
      dividendsMinor: 24500,
      target: WealthTarget(
        amountMinor: 100000000,
        date: LocalDate(2040, 12, 1),
        share: Percent.fromPoints(Decimal.parse('18.8')),
      ),
    );
  }
}
