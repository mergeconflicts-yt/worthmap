// P26 (SCREENS X30–X33; flow F08; SPEC 4.4, 6.5): the Spending feature
// contract.
//
// One port for the Spending root, where it goes, money in, budget and the
// limits editor. Reads come from the P15 spending projection and the P26
// money-in read; the only write is `SaveLimits`, which changes no payment
// (F08-E).
//
// The feature formats no money in the data layer; the screens format through
// `lib/design/format/`.
library;

import 'package:decimal/decimal.dart';

import '../../core/dates.dart';
import '../../core/percent.dart';

/// The four period chips of X30 (SPEC 6.5).
enum SpendingPeriod { week, month, sixMonths, year }

/// One category row of the period.
final class SpendingCategoryView {
  const SpendingCategoryView({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.currencyCode,
  });

  /// The category identity, or `uncategorised`.
  final String id;
  final String name;
  final int amountMinor;
  final String currencyCode;
}

/// One chart bucket of the period.
final class SpendingBucketView {
  const SpendingBucketView({
    required this.index,
    required this.firstDate,
    required this.lastDate,
    required this.amountMinor,
  });

  final int index;
  final LocalDate firstDate;
  final LocalDate lastDate;

  /// Null for a gap (no recorded amount).
  final int? amountMinor;
}

/// One period of spending (X30, X30c).
final class SpendingView {
  const SpendingView({
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.currencyCode,
    required this.partial,
    required this.moneyOutMinor,
    required this.limitMinor,
    required this.leftMinor,
    required this.used,
    required this.sameDaysPreviousMinor,
    required this.monthGone,
    required this.monthDay,
    required this.monthDays,
    required this.categories,
    required this.buckets,
  });

  final SpendingPeriod period;
  final LocalDate rangeStart;
  final LocalDate rangeEnd;
  final String currencyCode;

  /// True when the range end is today or later (an incomplete period).
  final bool partial;

  /// Null when nothing is recorded (never zero, SPEC 4.3).
  final int? moneyOutMinor;
  final int? limitMinor;
  final int? leftMinor;
  final Percent? used;

  /// Money out on the same days of the previous month.
  final int? sameDaysPreviousMinor;
  final Percent? monthGone;

  /// The day number inside the budget month (1-based).
  final int monthDay;

  /// The number of days in the budget month.
  final int monthDays;
  final List<SpendingCategoryView> categories;
  final List<SpendingBucketView> buckets;

  /// The highest bucket amount, for the chart scale.
  int get bucketMax {
    var max = 0;
    for (final bucket in buckets) {
      final amount = bucket.amountMinor;
      if (amount != null && amount > max) {
        max = amount;
      }
    }
    return max;
  }

  /// Category shares as percentages that add to exactly 100 (SPEC 4.1).
  List<Percent> get categoryShares {
    final total = categories.fold<int>(0, (sum, row) => sum + row.amountMinor);
    if (total <= 0) {
      return const <Percent>[];
    }
    return Percent.split(<Decimal>[
      for (final row in categories) Decimal.fromInt(row.amountMinor),
    ]);
  }
}

/// Money in for one period (X31).
final class MoneyInView {
  const MoneyInView({
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.currencyCode,
    required this.amountMinor,
    required this.count,
    required this.buckets,
  });

  final SpendingPeriod period;
  final LocalDate rangeStart;
  final LocalDate rangeEnd;
  final String currencyCode;

  /// Null when no income row is recorded in the range.
  final int? amountMinor;
  final int count;
  final List<SpendingBucketView> buckets;
}

/// One category limit row (X33).
final class LimitView {
  const LimitView({
    required this.categoryId,
    required this.name,
    required this.limitMinor,
    required this.currencyCode,
  });

  final String categoryId;
  final String name;
  final int limitMinor;
  final String currencyCode;
}

/// The budget month and its limits (X32, X33).
final class LimitsView {
  const LimitsView({
    required this.month,
    required this.currencyCode,
    required this.rows,
  });

  /// `YYYY-MM`.
  final String month;
  final String currencyCode;
  final List<LimitView> rows;

  /// SPEC 4.4: the sum of the positive limits, or null when none is set.
  int? get totalMinor {
    var sum = 0;
    var any = false;
    for (final row in rows) {
      if (row.limitMinor > 0) {
        sum += row.limitMinor;
        any = true;
      }
    }
    return any ? sum : null;
  }

  int get categoryCount => rows.where((row) => row.limitMinor > 0).length;
}

/// The Spending data port.
abstract interface class SpendingGateway {
  /// The spending period. It may publish a new projection generation.
  Future<SpendingView> loadSpending(SpendingPeriod period);

  /// Money in for the same period.
  Future<MoneyInView> loadMoneyIn(SpendingPeriod period);

  /// The current budget month and every expense category with its limit.
  Future<LimitsView> loadLimits();

  /// `SaveLimits`: the map holds minor units per category; zero removes a
  /// limit. No payment changes (F08-E).
  Future<void> saveLimits(Map<String, int> limits);
}

/// Safe failure codes (no amount, category or id in the text).
enum SpendingErrorCode {
  notWired,
  loadFailed,
  saveFailed,
  invalidLimits,
}

class SpendingError implements Exception {
  const SpendingError(this.code);

  final SpendingErrorCode code;

  @override
  String toString() => 'SpendingError(${code.name})';
}

/// The placeholder gateway before the app composition mounts the vault.
final class UnavailableSpendingGateway implements SpendingGateway {
  const UnavailableSpendingGateway();

  @override
  Future<SpendingView> loadSpending(SpendingPeriod period) async =>
      throw const SpendingError(SpendingErrorCode.notWired);

  @override
  Future<MoneyInView> loadMoneyIn(SpendingPeriod period) async =>
      throw const SpendingError(SpendingErrorCode.notWired);

  @override
  Future<LimitsView> loadLimits() async =>
      throw const SpendingError(SpendingErrorCode.notWired);

  @override
  Future<void> saveLimits(Map<String, int> limits) async =>
      throw const SpendingError(SpendingErrorCode.notWired);
}
