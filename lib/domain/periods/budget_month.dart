import 'package:decimal/decimal.dart';

import '../../core/dates.dart';
import '../../core/decimal.dart';
import '../../core/percent.dart';
import 'period_math.dart';

/// SPEC 4.4 / 6.5: one budget month, from its start day to the day before
/// the next start.
///
/// The start day is the user's setting (X80 "Month starts on"). A start day
/// above a month's length uses that month's last day, so no month is skipped
/// (31 starts on 28/29 February). Month gone is
/// `(day number - 1 + share of today) / days`, rounded to 2 percentage
/// points; the screen draws it as a tick and shows 0 decimals (4.4).
final class BudgetMonth {
  BudgetMonth._({
    required this.start,
    required this.end,
    required this.startDay,
    required this.dayNumber,
  }) : lengthInDays = daysBetween(start, end) + 1;

  /// The budget month that contains [date].
  ///
  /// [startDay] must be 1 to 31. [date] must be inside the month.
  factory BudgetMonth.containing(LocalDate date, {int startDay = 1}) {
    if (startDay < 1 || startDay > 31) {
      throw ArgumentError.value(startDay, 'startDay', 'Must be 1 to 31');
    }
    final thisStart = _clampedStart(date.year, date.month, startDay);
    final LocalDate start;
    if (date.compareTo(thisStart) >= 0) {
      start = thisStart;
    } else {
      final previous = addMonths(LocalDate(date.year, date.month, 1), -1);
      start = _clampedStart(previous.year, previous.month, startDay);
    }
    final next = _nextStart(start, startDay);
    final end = addDays(next, -1);
    return BudgetMonth._(
      start: start,
      end: end,
      startDay: startDay,
      dayNumber: daysBetween(start, date) + 1,
    );
  }

  /// The first day of the month, inclusive.
  final LocalDate start;

  /// The last day of the month, inclusive.
  final LocalDate end;

  /// The user's start day, 1 to 31.
  final int startDay;

  /// The position of the reference date inside the month, 1-based.
  final int dayNumber;

  /// The number of days in the month.
  final int lengthInDays;

  /// True when [date] is inside the month.
  bool contains(LocalDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;

  /// The month before this one.
  BudgetMonth get previous =>
      BudgetMonth.containing(addDays(start, -1), startDay: startDay);

  /// The month after this one.
  BudgetMonth get next =>
      BudgetMonth.containing(addDays(end, 1), startDay: startDay);

  /// SPEC 4.4: the share of the month that has passed.
  ///
  /// [shareOfToday] is the part of today already elapsed, 0 to 1, supplied by
  /// the app boundary (the domain never reads the clock). A calendar day
  /// counts whole when the boundary passes 1.
  Percent monthGone({required Decimal shareOfToday}) {
    if (shareOfToday < Decimal.zero || shareOfToday > Decimal.one) {
      throw ArgumentError.value(
        shareOfToday,
        'shareOfToday',
        'Must be between 0 and 1',
      );
    }
    final elapsed = Decimal.fromInt(dayNumber - 1) + shareOfToday;
    final fraction = elapsed / Decimal.fromInt(lengthInDays);
    final points =
        fraction.toDecimal(scaleOnInfinitePrecision: 8) * Decimal.fromInt(100);
    return Percent.fromPoints(roundToScale(points, 2, RoundingMode.halfUp));
  }
}

LocalDate _clampedStart(int year, int month, int startDay) {
  final last = LocalDate.daysInMonth(year, month);
  return LocalDate(year, month, startDay <= last ? startDay : last);
}

LocalDate _nextStart(LocalDate start, int startDay) {
  final next = addMonths(start, 1);
  return _clampedStart(next.year, next.month, startDay);
}
