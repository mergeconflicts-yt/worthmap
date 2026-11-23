import '../../core/money.dart';
import '../../core/percent.dart';
import 'spending_ratio.dart';
import 'spending_totals.dart';

/// SPEC 4.4 / 6.5: spending against the user's monthly limits.
///
/// The user's limits are their own numbers; the app only compares (SPEC 2).
/// A limit of zero is not a limit. When no limit exists, the comparison uses
/// the same day of the previous month.

/// SPEC 4.4: the state of one spent-versus-limit comparison.
sealed class BudgetStanding {
  const BudgetStanding();
}

/// Spending is at or below the limit.
final class WithinLimit extends BudgetStanding {
  const WithinLimit({
    required this.spent,
    required this.limit,
    required this.left,
    required this.used,
  });

  /// Money out in the period.
  final Money spent;

  /// The user's limit for the period.
  final Money limit;

  /// What remains: limit minus spent.
  final Money left;

  /// Spent as a share of the limit in percentage points.
  final Percent used;
}

/// Spending is above the limit.
final class OverLimit extends BudgetStanding {
  const OverLimit({
    required this.spent,
    required this.limit,
    required this.over,
    required this.used,
  });

  /// Money out in the period.
  final Money spent;

  /// The user's limit for the period.
  final Money limit;

  /// Spent minus limit.
  final Money over;

  /// Spent as a share of the limit in percentage points.
  final Percent used;
}

/// No limit exists, so spending is compared with the same days last month.
final class ComparedWithoutLimit extends BudgetStanding {
  const ComparedWithoutLimit({
    required this.spent,
    required this.sameDayLastMonth,
    required this.difference,
  });

  /// Money out in the period.
  final Money spent;

  /// Money out on the same day of the previous month.
  final Money sameDayLastMonth;

  /// Spent minus the previous amount; negative means lower.
  final Money difference;
}

/// Nothing is recorded for the period.
final class BudgetNoneRecorded extends BudgetStanding {
  const BudgetNoneRecorded();
}

/// The comparison is not available from the recorded rows.
final class BudgetNotAvailable extends BudgetStanding {
  const BudgetNotAvailable();
}

/// SPEC 4.4: compares money out with the limit, or with the same day last
/// month when no limit exists.
///
/// [spent] carries its own state so "None recorded" and "Not available" pass
/// through instead of becoming zero.
BudgetStanding compareSpentToLimit({
  required Total spent,
  Money? limit,
  Money? sameDayLastMonth,
}) {
  if (spent is NoneRecordedTotal) {
    return const BudgetNoneRecorded();
  }
  if (spent is! KnownTotal) {
    return const BudgetNotAvailable();
  }
  final amount = spent.amount;
  if (limit != null && limit.minor > 0) {
    final left = limit - amount;
    final used = percentOfMoney(amount, limit, scale: 2);
    if (left.isNegative) {
      return OverLimit(
        spent: amount,
        limit: limit,
        over: -left,
        used: used!,
      );
    }
    return WithinLimit(
      spent: amount,
      limit: limit,
      left: left,
      used: used!,
    );
  }
  if (sameDayLastMonth != null) {
    return ComparedWithoutLimit(
      spent: amount,
      sameDayLastMonth: sameDayLastMonth,
      difference: amount - sameDayLastMonth,
    );
  }
  return const BudgetNotAvailable();
}
