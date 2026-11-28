// SPEC 9.2 / SPEC 4.9: value methods and their projections.
//
// A value is real when the user or a statement entered it. It is estimated
// when a rule projects it from the last real value. A rule with a missing
// input makes the value unavailable, never zero (SPEC 4.3).
//
// Basis (DECISIONS P4-VALUE-METHOD-BASIS, decided 28 Nov 2026):
// - Day count: actual days. One year is 365 days. A leap day is one day.
// - Compounding: the method the user selects. A complete period uses the
//   period rate. The days after the last complete period use simple interest
//   at the annual rate.
// - Contributions: each contribution grows from its own date to the read
//   date at simple pro-rata of the annual rate. No order is invented.
// - Rounding: the projection keeps full precision and rounds once, half to
//   even, to the currency's minor unit.
// - A maturity date stops all growth. Renewal is a write, not a projection.
library;

import 'dart:math' as math;

import 'package:decimal/decimal.dart';

import '../../core/dates.dart';
import '../../core/decimal.dart';
import '../../core/money.dart';
import '../periods/period_math.dart';

/// SPEC 9.2: how interest is added.
enum Compounding { simple, monthly, quarterly, yearly }

/// SPEC 9.2: the method that produced an estimate.
enum ValueBasis {
  interest,
  contribution,
  depreciation,
  weightAndPrice,
  marketPrice,
}

/// Why a projection has no value.
enum ValueUnavailable {
  /// The read date is before the rule starts.
  beforeStart,

  /// The rule needs a price, and none is recorded.
  noPrice,

  /// A capital account has no reported value.
  noReportedValue,
}

/// SPEC 4.9: one reading of an account value.
sealed class ProjectedValue {
  const ProjectedValue();
}

/// A value from a statement, an import or a dated manual entry.
final class KnownValue extends ProjectedValue {
  const KnownValue({required this.amount, required this.date});

  final Money amount;
  final LocalDate date;
}

/// A value projected by a rule since [KnownValue.date].
final class EstimatedValue extends ProjectedValue {
  const EstimatedValue({
    required this.amount,
    required this.date,
    required this.basis,
  });

  final Money amount;
  final LocalDate date;
  final ValueBasis basis;
}

/// No value. The screen shows Missing or None recorded.
final class UnavailableValue extends ProjectedValue {
  const UnavailableValue(this.reason);

  final ValueUnavailable reason;
}

/// The last real value, unchanged. A manual value has no rule.
ProjectedValue projectManual({
  required Money value,
  required LocalDate date,
}) =>
    KnownValue(amount: value, date: date);

/// SPEC 9.2 `marketPrice`: quantity x quote x exchange rate.
///
/// A missing quote or a missing rate is unavailable, never zero (SPEC 4.1).
ProjectedValue projectMarketPrice({
  required Decimal quantity,
  required Money? pricePerUnit,
  Decimal? fxRate,
  required LocalDate asOf,
}) {
  final price = pricePerUnit;
  if (price == null) {
    return const UnavailableValue(ValueUnavailable.noPrice);
  }
  final rate = fxRate ?? Decimal.one;
  final value = Decimal.fromInt(price.minor) * quantity * rate;
  return EstimatedValue(
    amount: _toMoney(value, price.currency),
    date: asOf,
    basis: ValueBasis.marketPrice,
  );
}

/// SPEC 9.2 `interest`: a deposit or a bond from its start to [asOf].
///
/// The value stops at [maturity]. The reader shows "Matured" after that date.
/// Growth before [start] is unavailable.
ProjectedValue projectInterest({
  required Money principal,
  required Decimal annualRate,
  required Compounding compounding,
  required LocalDate start,
  required LocalDate asOf,
  LocalDate? maturity,
}) {
  if (maturity != null && _before(maturity, start)) {
    throw ArgumentError.value(maturity, 'maturity', 'Before start');
  }
  if (_before(asOf, start)) {
    return const UnavailableValue(ValueUnavailable.beforeStart);
  }
  final end = maturity != null && _before(maturity, asOf) ? maturity : asOf;
  final principalMinor = Decimal.fromInt(principal.minor);
  final Decimal factor;
  if (compounding == Compounding.simple) {
    factor = Decimal.one + _proRata(annualRate, daysBetween(start, end));
  } else {
    final periodMonths = switch (compounding) {
      Compounding.simple => 0,
      Compounding.monthly => 1,
      Compounding.quarterly => 3,
      Compounding.yearly => 12,
    };
    final completeMonths =
        _wholeMonths(start, end) ~/ periodMonths * periodMonths;
    final boundary = addMonths(start, completeMonths);
    final periods = completeMonths ~/ periodMonths;
    final periodRate = _ratio(annualRate, Decimal.fromInt(12 ~/ periodMonths));
    final remainingDays = daysBetween(boundary, end);
    factor = _pow(Decimal.one + periodRate, periods) *
        (Decimal.one + _proRata(annualRate, remainingDays));
  }
  return EstimatedValue(
    amount: _toMoney(principalMinor * factor, principal.currency),
    date: end,
    basis: ValueBasis.interest,
  );
}

/// SPEC 9.2 `contribution`: a pension from its last statement.
///
/// Each contribution grows from its own date. The day is clamped to the month
/// (day 31 gives 30 September). Contributions on or before [lastValueDate]
/// are already in the last value.
ProjectedValue projectContribution({
  required Money lastValue,
  required LocalDate lastValueDate,
  required Money monthlyContribution,
  required Decimal annualRate,
  required int contributionDay,
  required LocalDate asOf,
  Money? employerContribution,
}) {
  if (contributionDay < 1 || contributionDay > 31) {
    throw ArgumentError.value(contributionDay, 'contributionDay', '1 to 31');
  }
  if (_before(asOf, lastValueDate)) {
    return const UnavailableValue(ValueUnavailable.beforeStart);
  }
  final currency = lastValue.currency;
  var total = _grown(
    Decimal.fromInt(lastValue.minor),
    annualRate,
    daysBetween(lastValueDate, asOf),
  );
  final perMonth = Decimal.fromInt(monthlyContribution.minor) +
      Decimal.fromInt((employerContribution ?? Money.zero(currency)).minor);
  if (perMonth != Decimal.zero) {
    final firstMonth = LocalDate(lastValueDate.year, lastValueDate.month, 1);
    for (var index = 0;; index++) {
      final month = addMonths(firstMonth, index);
      if (month.year > asOf.year ||
          (month.year == asOf.year && month.month > asOf.month)) {
        break;
      }
      final day = math.min(
        contributionDay,
        LocalDate.daysInMonth(month.year, month.month),
      );
      final date = LocalDate(month.year, month.month, day);
      final afterLast = date.compareTo(lastValueDate) > 0;
      final notFuture = date.compareTo(asOf) <= 0;
      if (afterLast && notFuture) {
        total += _grown(
          perMonth,
          annualRate,
          daysBetween(date, asOf),
        );
      }
    }
  }
  return EstimatedValue(
    amount: _toMoney(total, currency),
    date: asOf,
    basis: ValueBasis.contribution,
  );
}

/// SPEC 9.2 `depreciation`: straight-line from a purchase value.
///
/// A value cannot go below zero. [yearlyRate] is a fraction (0.10 is 10%).
ProjectedValue projectDepreciation({
  required Money purchaseValue,
  required LocalDate purchaseDate,
  required Decimal yearlyRate,
  required LocalDate asOf,
}) {
  if (yearlyRate < Decimal.zero) {
    throw ArgumentError.value(yearlyRate, 'yearlyRate', 'Not negative');
  }
  if (_before(asOf, purchaseDate)) {
    return const UnavailableValue(ValueUnavailable.beforeStart);
  }
  final years = _ratio(
    Decimal.fromInt(daysBetween(purchaseDate, asOf)),
    Decimal.fromInt(365),
  );
  final factor = Decimal.one - yearlyRate * years;
  final value = factor < Decimal.zero ? Decimal.zero : factor;
  return EstimatedValue(
    amount: _toMoney(
      Decimal.fromInt(purchaseValue.minor) * value,
      purchaseValue.currency,
    ),
    date: asOf,
    basis: ValueBasis.depreciation,
  );
}

/// SPEC 9.2 `weightPrice`: weight x purity x price per unit of weight.
ProjectedValue projectWeightAndPrice({
  required Decimal weight,
  required Decimal purity,
  required Money? pricePerUnit,
  required LocalDate asOf,
}) {
  final price = pricePerUnit;
  if (price == null) {
    return const UnavailableValue(ValueUnavailable.noPrice);
  }
  return EstimatedValue(
    amount: _toMoney(
      weight * purity * Decimal.fromInt(price.minor),
      price.currency,
    ),
    date: asOf,
    basis: ValueBasis.weightAndPrice,
  );
}

/// SPEC 9.2 `capitalAccount`: only a reported value is a value.
///
/// A commitment is not money paid and not a value.
ProjectedValue projectCapitalAccount({
  required Money? reportedValue,
  required LocalDate? reportedDate,
}) {
  final value = reportedValue;
  final date = reportedDate;
  if (value == null || date == null) {
    return const UnavailableValue(ValueUnavailable.noReportedValue);
  }
  return KnownValue(amount: value, date: date);
}

/// The fraction of a year for [days] at [annualRate], for example 0.05 x
/// 74 / 365.
Decimal _proRata(Decimal annualRate, int days) => _ratio(
      annualRate * Decimal.fromInt(days),
      Decimal.fromInt(365),
    );

Decimal _grown(Decimal amountMinor, Decimal annualRate, int days) =>
    amountMinor * (Decimal.one + _proRata(annualRate, days));

/// The largest whole number of months whose clamped calendar boundary is not
/// after [end]. 31 Jan to 28 Feb is one month.
int _wholeMonths(LocalDate start, LocalDate end) {
  final rough = (end.year - start.year) * 12 + (end.month - start.month);
  return _before(end, addMonths(start, rough)) ? rough - 1 : rough;
}

bool _before(LocalDate left, LocalDate right) => left.compareTo(right) < 0;

Decimal _ratio(Decimal numerator, Decimal denominator) =>
    (numerator / denominator).toDecimal(scaleOnInfinitePrecision: 18);

Decimal _pow(Decimal base, int exponent) {
  var result = Decimal.one;
  for (var index = 0; index < exponent; index++) {
    result *= base;
  }
  return result;
}

/// Rounds a value already expressed in minor units.
Money _toMoney(Decimal minorUnits, Currency currency) => Money.fromMinor(
      roundToBigInt(minorUnits, RoundingMode.halfEven).toInt(),
      currency,
    );
