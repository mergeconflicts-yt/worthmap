import 'package:decimal/decimal.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import 'spending_ratio.dart';
import 'spending_totals.dart';

/// SPEC 4.4 / 4.3: 12-month averages over complete months only.
///
/// The caller passes complete months (a period rule lives in
/// `lib/domain/periods/`), so this module stays pure arithmetic. Fewer than
/// 12 months is allowed; the result carries the month count so the screen can
/// say "Average of 9 months" (SPEC 4.3 "Coverage of averages").

/// One complete month and its amount (money out, or money in).
final class MonthlyTotal {
  MonthlyTotal({
    required this.year,
    required this.month,
    required this.amount,
  }) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be 1 to 12');
    }
    if (year < LocalDate.minYear || year > LocalDate.maxYear) {
      throw ArgumentError.value(year, 'year', 'Must be 1 to 9999');
    }
  }

  /// The calendar year of the month.
  final int year;

  /// The calendar month, 1 to 12.
  final int month;

  /// The amount of the complete month (money out, or money in).
  final Money amount;
}

/// SPEC 4.4: an average over complete months and its coverage.
final class AverageMonthlyTotal {
  const AverageMonthlyTotal({
    required this.average,
    required this.months,
    required this.total,
  });

  /// The average, or "None recorded" when no month is passed.
  final Total average;

  /// How many complete months the average uses.
  final int months;

  /// The sum of those months, or null when there are none.
  final Money? total;
}

/// SPEC 4.4: the monthly average of [months], using up to [maxMonths] months.
///
/// Months are sorted by date and the last [maxMonths] are used. The average
/// is rounded to minor units with half to even (SPEC 4.1).
AverageMonthlyTotal averageMonthlyTotal(
  List<MonthlyTotal> months, {
  required Currency currency,
  int maxMonths = 12,
}) {
  if (maxMonths < 1) {
    throw ArgumentError.value(maxMonths, 'maxMonths', 'Must be one or more');
  }
  final ordered = <MonthlyTotal>[...months]..sort((a, b) {
      if (a.year != b.year) {
        return a.year.compareTo(b.year);
      }
      return a.month.compareTo(b.month);
    });
  final window = ordered.length > maxMonths
      ? ordered.sublist(ordered.length - maxMonths)
      : ordered;
  if (window.isEmpty) {
    return const AverageMonthlyTotal(
      average: NoneRecordedTotal(),
      months: 0,
      total: null,
    );
  }
  var total = Money.zero(currency);
  for (final month in window) {
    if (month.amount.currency != currency) {
      throw MoneyCurrencyMismatch(month.amount.currency.code, currency.code);
    }
    total = total + month.amount;
  }
  final averageMinor = roundHalfEvenDivision(
    BigInt.from(total.minor),
    BigInt.from(window.length),
  );
  return AverageMonthlyTotal(
    average: KnownTotal(Money.fromMinor(averageMinor.toInt(), currency)),
    months: window.length,
    total: total,
  );
}

/// SPEC 4.4: "Months covered" = cash you can use / average monthly spending.
///
/// Returns null when the average is zero or negative: not available, never a
/// made-up number (SPEC 4.3). [scale] sets the decimal places, 1 by default.
Decimal? monthsCovered({
  required Money cash,
  required Money average,
  int scale = 1,
}) {
  if (cash.currency != average.currency) {
    throw MoneyCurrencyMismatch(cash.currency.code, average.currency.code);
  }
  if (average.minor <= 0) {
    return null;
  }
  return ratioToScale(
    Decimal.fromInt(cash.minor),
    Decimal.fromInt(average.minor),
    scale: scale,
  );
}
