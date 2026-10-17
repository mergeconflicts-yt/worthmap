/// SPEC 4.1 / AGENTS 6.4: a payment date is a local calendar date.
///
/// It has no time or timezone. Events (UTC instants) stay separate.
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate._(this.year, this.month, this.day);

  /// Creates and validates a real calendar date.
  factory LocalDate(int year, int month, int day) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be 1 to 12');
    }
    if (day < 1 || day > daysInMonth(year, month)) {
      throw ArgumentError.value(day, 'day', 'Not a valid day for the month');
    }
    return LocalDate._(year, month, day);
  }

  final int year;
  final int month;
  final int day;

  static final RegExp _pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// True when [year] is a Gregorian leap year.
  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// The number of days in [month] of [year].
  static int daysInMonth(int year, int month) {
    const lengths = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be 1 to 12');
    }
    if (month == 2 && isLeapYear(year)) {
      return 29;
    }
    return lengths[month - 1];
  }

  /// Parses strict ISO `YYYY-MM-DD`, or returns null.
  static LocalDate? tryParse(String source) {
    if (!_pattern.hasMatch(source)) {
      return null;
    }
    final year = int.parse(source.substring(0, 4));
    final month = int.parse(source.substring(5, 7));
    final day = int.parse(source.substring(8, 10));
    if (month < 1 || month > 12) {
      return null;
    }
    if (day < 1 || day > daysInMonth(year, month)) {
      return null;
    }
    return LocalDate._(year, month, day);
  }

  /// Parses strict ISO `YYYY-MM-DD`, or throws [FormatException].
  static LocalDate parse(String source) {
    final value = tryParse(source);
    if (value == null) {
      throw FormatException('Not an ISO local date', source);
    }
    return value;
  }

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// AGENTS 6.3: domain functions never call `DateTime.now`; a [Clock] is passed.
///
/// Implementations live at the app boundary. Tests use [FixedClock].
abstract class Clock {
  const Clock();

  /// The current instant, in UTC.
  DateTime nowUtc();
}

/// A [Clock] that always returns one instant. For tests only.
final class FixedClock extends Clock {
  const FixedClock(this._instant);

  final DateTime _instant;

  @override
  DateTime nowUtc() => _instant;
}
