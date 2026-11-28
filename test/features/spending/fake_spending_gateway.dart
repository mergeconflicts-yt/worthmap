import 'package:contour/core/dates.dart';
import 'package:contour/core/percent.dart';
import 'package:contour/domain/periods/period_math.dart';
import 'package:contour/features/spending/spending_models.dart';
import 'package:decimal/decimal.dart';

/// Appendix A values for the P26 tests (SPEC 13, Appendix A).
final class FakeSpendingGateway implements SpendingGateway {
  FakeSpendingGateway({this.currencyCode = 'USD'});

  final String currencyCode;

  static final LocalDate _today = LocalDate(2026, 10, 13);

  final Map<SpendingPeriod, SpendingView> views =
      <SpendingPeriod, SpendingView>{
    SpendingPeriod.week: _view(
      period: SpendingPeriod.week,
      start: LocalDate(2026, 10, 7),
      end: _today,
      spent: 156000,
      limit: 520000,
      left: 364000,
      previous: 140500,
      buckets: <int>[22000, 24000, 21000, 26000, 23000, 21000, 19000],
    ),
    SpendingPeriod.month: _view(
      period: SpendingPeriod.month,
      start: LocalDate(2026, 10, 1),
      end: _today,
      spent: 394000,
      limit: 520000,
      left: 126000,
      previous: 400500,
      buckets: <int>[
        30000,
        28000,
        27000,
        26000,
        25000,
        24000,
        23000,
        22000,
        21000,
        20000,
        19000,
        18000,
        15000,
      ],
    ),
    SpendingPeriod.sixMonths: _view(
      period: SpendingPeriod.sixMonths,
      start: LocalDate(2026, 4, 1),
      end: LocalDate(2026, 9, 30),
      spent: 2108000,
      limit: 2600000,
      left: 492000,
      previous: null,
      buckets: <int>[320000, 350000, 340000, 360000, 380000, 506000],
    ),
    SpendingPeriod.year: _view(
      period: SpendingPeriod.year,
      start: LocalDate(2025, 10, 1),
      end: LocalDate(2026, 9, 30),
      spent: 4806000,
      limit: 6240000,
      left: 1434000,
      previous: null,
      buckets: <int>[
        380000,
        390000,
        410000,
        400000,
        420000,
        380000,
        360000,
        350000,
        340000,
        420000,
        450000,
        506000,
      ],
    ),
  };

  static SpendingView _view({
    required SpendingPeriod period,
    required LocalDate start,
    required LocalDate end,
    required int spent,
    required int limit,
    required int left,
    required int? previous,
    required List<int> buckets,
  }) {
    var index = 0;
    final bars = <SpendingBucketView>[];
    final monthly =
        period == SpendingPeriod.sixMonths || period == SpendingPeriod.year;
    for (final amount in buckets) {
      final first = monthly
          ? addMonths(LocalDate(start.year, start.month, 1), index)
          : LocalDate(start.year, start.month, start.day + index);
      final last = monthly ? addDays(addMonths(first, 1), -1) : first;
      bars.add(
        SpendingBucketView(
          index: index,
          firstDate: first,
          lastDate: last,
          amountMinor: amount,
        ),
      );
      index += 1;
    }
    return SpendingView(
      period: period,
      rangeStart: start,
      rangeEnd: end,
      month: LocalDate(start.year, start.month, 1),
      currencyCode: 'USD',
      partial: period == SpendingPeriod.week || period == SpendingPeriod.month,
      moneyOutMinor: spent,
      limitMinor: limit,
      leftMinor: left,
      used: Percent.fromFraction(
        (Decimal.fromInt(spent) / Decimal.fromInt(limit))
            .toDecimal(scaleOnInfinitePrecision: 6),
      ),
      sameDaysPreviousMinor: previous,
      monthGone: Percent.fromPoints(Decimal.parse('41.94')),
      monthDay: 13,
      monthDays: 31,
      categories: _categories(period),
      buckets: List<SpendingBucketView>.unmodifiable(bars),
    );
  }

  static List<SpendingCategoryView> _categories(SpendingPeriod period) {
    if (period == SpendingPeriod.week) {
      return const <SpendingCategoryView>[
        SpendingCategoryView(
          id: 'rent',
          name: 'Rent',
          amountMinor: 120000,
          currencyCode: 'USD',
          isEssential: true,
        ),
        SpendingCategoryView(
          id: 'groceries',
          name: 'Groceries',
          amountMinor: 36000,
          currencyCode: 'USD',
          isEssential: true,
        ),
      ];
    }
    return const <SpendingCategoryView>[
      SpendingCategoryView(
        id: 'rent',
        name: 'Rent',
        amountMinor: 180000,
        currencyCode: 'USD',
        isEssential: true,
      ),
      SpendingCategoryView(
        id: 'groceries',
        name: 'Groceries',
        amountMinor: 60000,
        currencyCode: 'USD',
        isEssential: true,
      ),
      SpendingCategoryView(
        id: 'dining',
        name: 'Dining',
        amountMinor: 52000,
        currencyCode: 'USD',
        isEssential: false,
      ),
      SpendingCategoryView(
        id: 'shopping',
        name: 'Shopping',
        amountMinor: 24000,
        currencyCode: 'USD',
        isEssential: false,
      ),
      SpendingCategoryView(
        id: 'transport',
        name: 'Transport',
        amountMinor: 30000,
        currencyCode: 'USD',
        isEssential: true,
      ),
      SpendingCategoryView(
        id: 'utilities',
        name: 'Utilities',
        amountMinor: 20000,
        currencyCode: 'USD',
        isEssential: true,
      ),
      SpendingCategoryView(
        id: 'subscriptions',
        name: 'Subscriptions',
        amountMinor: 9000,
        currencyCode: 'USD',
        isEssential: false,
      ),
      SpendingCategoryView(
        id: 'other',
        name: 'Other',
        amountMinor: 19000,
        currencyCode: 'USD',
      ),
    ];
  }

  MoneyInView get moneyIn => MoneyInView(
        period: SpendingPeriod.month,
        rangeStart: LocalDate(2026, 10, 1),
        rangeEnd: _today,
        currencyCode: currencyCode,
        amountMinor: 820000,
        count: 1,
        buckets: <SpendingBucketView>[
          for (var day = 1; day <= 13; day += 1)
            SpendingBucketView(
              index: day - 1,
              firstDate: LocalDate(2026, 10, day),
              lastDate: LocalDate(2026, 10, day),
              amountMinor: day == 1 ? 820000 : 0,
            ),
        ],
      );

  LimitsView get limits => LimitsView(
        month: '2026-10',
        currencyCode: currencyCode,
        rows: const <LimitView>[
          LimitView(
            categoryId: 'rent',
            name: 'Rent',
            limitMinor: 180000,
            currencyCode: 'USD',
          ),
          LimitView(
            categoryId: 'groceries',
            name: 'Groceries',
            limitMinor: 120000,
            currencyCode: 'USD',
          ),
          LimitView(
            categoryId: 'dining',
            name: 'Dining',
            limitMinor: 60000,
            currencyCode: 'USD',
          ),
          LimitView(
            categoryId: 'shopping',
            name: 'Shopping',
            limitMinor: 50000,
            currencyCode: 'USD',
          ),
          LimitView(
            categoryId: 'transport',
            name: 'Transport',
            limitMinor: 40000,
            currencyCode: 'USD',
          ),
          LimitView(
            categoryId: 'utilities',
            name: 'Utilities',
            limitMinor: 30000,
            currencyCode: 'USD',
          ),
          LimitView(
            categoryId: 'other',
            name: 'Other',
            limitMinor: 30000,
            currencyCode: 'USD',
          ),
          LimitView(
            categoryId: 'subscriptions',
            name: 'Subscriptions',
            limitMinor: 10000,
            currencyCode: 'USD',
          ),
        ],
      );

  int saveCalls = 0;
  Map<String, int>? savedLimits;
  Object? loadFailure;
  Object? saveFailure;

  @override
  Future<SpendingView> loadSpending(SpendingPeriod period) async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return views[period]!;
  }

  @override
  Future<MoneyInView> loadMoneyIn(SpendingPeriod period) async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return moneyIn;
  }

  @override
  Future<SpendingRowsView> loadRows() async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return SpendingRowsView(
      month: LocalDate(2026, 10, 1),
      leftMinor: 126000,
      limitMinor: 520000,
      whereCount: 8,
      moneyInMinor: 820000,
      moneyInAverageMinor: 926700,
      paymentsCount: 42,
      repeatingCount: 7,
      repeatingChanges: 3,
      repeatingMonthlyMinor: 208400,
    );
  }

  @override
  Future<LimitsView> loadLimits() async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return limits;
  }

  @override
  Future<void> saveLimits(Map<String, int> limits) async {
    saveCalls += 1;
    final failure = saveFailure;
    if (failure != null) {
      throw failure;
    }
    savedLimits = Map<String, int>.from(limits);
  }
}

/// The Appendix A October money in.
const int appendixMoneyInMinor = 820000;

/// The Appendix A October money out.
const int appendixSpentMinor = 394000;
