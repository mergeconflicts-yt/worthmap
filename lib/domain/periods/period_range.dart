import '../../core/dates.dart';
import 'budget_month.dart';
import 'period_math.dart';

/// SPEC 6.5: the period chips and the ranges they cover.
///
/// X30 and X31 use 1W · 1M · 6M · 1Y. Spending multi-month ranges count
/// complete months only, because a monthly limit has no closed value for the
/// current partial month; money-in ranges end with the current month to date.
/// The 1M chip is the current budget month to date in both cases.
enum PeriodKind {
  /// The last 7 days, today included (a rolling week, not a calendar week).
  week,

  /// The current budget month to date.
  month,

  /// Six months.
  sixMonths,

  /// Twelve months.
  year,
}

/// An inclusive range of local calendar dates.
final class DateRange {
  DateRange(this.start, this.end) {
    if (start.compareTo(end) > 0) {
      throw ArgumentError('The range start must not be after the end');
    }
  }

  /// The first day, inclusive.
  final LocalDate start;

  /// The last day, inclusive.
  final LocalDate end;

  /// The number of days in the range.
  int get days => daysBetween(start, end) + 1;

  /// True when [date] is inside the range.
  bool contains(LocalDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;

  @override
  String toString() => '$start..$end';
}

/// SPEC 6.5: the range of the Spending chips (X30).
///
/// 1W is the last 7 days. 1M is the current budget month to date (1-13 Oct in
/// the sample). 6M and 1Y are the last 6 and 12 complete months, ending with
/// the last complete month (Apr-Sep and Oct 2025-Sep 2026 in the sample).
DateRange spendingPeriod(
  LocalDate today,
  PeriodKind kind, {
  int startDay = 1,
}) {
  final current = BudgetMonth.containing(today, startDay: startDay);
  return switch (kind) {
    PeriodKind.week => DateRange(addDays(today, -6), today),
    PeriodKind.month => DateRange(current.start, today),
    PeriodKind.sixMonths => _completeMonths(current, 6),
    PeriodKind.year => _completeMonths(current, 12),
  };
}

/// SPEC 6.5 / 6.6: the range of the Money in chips (X31).
///
/// 1W and 1M match the Spending chips. 6M and 1Y end with the current month
/// to date (May-Oct and Nov 2025-Oct 2026 in the sample).
DateRange moneyInPeriod(
  LocalDate today,
  PeriodKind kind, {
  int startDay = 1,
}) {
  final current = BudgetMonth.containing(today, startDay: startDay);
  return switch (kind) {
    PeriodKind.week => DateRange(addDays(today, -6), today),
    PeriodKind.month => DateRange(current.start, today),
    PeriodKind.sixMonths => _trailingMonths(current, 6, today),
    PeriodKind.year => _trailingMonths(current, 12, today),
  };
}

/// SPEC 6.5: the same days of the previous budget month.
///
/// X30 compares "Same days in September: $4,005" with 1-13 October. When the
/// current month has more days than the previous one, the range stops at the
/// previous month's last day.
DateRange sameDaysPreviousMonth(LocalDate today, {int startDay = 1}) {
  final current = BudgetMonth.containing(today, startDay: startDay);
  final previous = current.previous;
  final days = current.dayNumber <= previous.lengthInDays
      ? current.dayNumber
      : previous.lengthInDays;
  return DateRange(previous.start, addDays(previous.start, days - 1));
}

DateRange _completeMonths(BudgetMonth current, int months) {
  var last = current.previous;
  final end = last.end;
  for (var index = 1; index < months; index++) {
    last = last.previous;
  }
  return DateRange(last.start, end);
}

DateRange _trailingMonths(BudgetMonth current, int months, LocalDate today) {
  var start = current;
  for (var index = 1; index < months; index++) {
    start = start.previous;
  }
  return DateRange(start.start, today);
}
