import '../../core/dates.dart';

/// SPEC 4.4 / 6.5: calendar arithmetic for the budget month and periods.
///
/// Dates are local calendar dates (no time, no timezone). The arithmetic is
/// deterministic and never reads the wall clock (AGENTS 6.3).

/// Returns [date] moved by [days] (negative moves back).
LocalDate addDays(LocalDate date, int days) {
  final shifted = DateTime.utc(date.year, date.month, date.day + days);
  return LocalDate(shifted.year, shifted.month, shifted.day);
}

/// Returns [date] moved by [months], keeping the day where the month allows
/// it and clamping to the last day otherwise (31 Jan + 1 month = 28/29 Feb).
LocalDate addMonths(LocalDate date, int months) {
  final total = date.year * 12 + (date.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final day = date.day <= LocalDate.daysInMonth(year, month)
      ? date.day
      : LocalDate.daysInMonth(year, month);
  return LocalDate(year, month, day);
}

/// The number of whole days from [from] to [to]; negative when [to] is first.
int daysBetween(LocalDate from, LocalDate to) => DateTime.utc(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// ISO weekday: Monday is 1 and Sunday is 7.
int weekdayOf(LocalDate date) =>
    DateTime.utc(date.year, date.month, date.day).weekday;

/// The Monday on or before [date] (X22: weeks start Monday).
LocalDate startOfWeek(LocalDate date) =>
    addDays(date, -(weekdayOf(date) - DateTime.monday));
