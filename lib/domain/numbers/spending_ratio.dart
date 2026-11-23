import 'package:decimal/decimal.dart';

import '../../core/money.dart';
import '../../core/percent.dart';

/// SPEC 4.1: exact ratios for the spending numbers.
///
/// A ratio is computed from [Decimal] values through exact rational
/// arithmetic and is rounded once, with half up (away from zero), to the
/// requested number of decimal places. No `double` is used (AGENTS 2.3).

/// SPEC 4.1: the exact power of ten for [exponent] as a [Decimal].
Decimal _tenPower(int exponent) =>
    Decimal.fromBigInt(BigInt.from(10).pow(exponent));

/// Rounds `numerator / denominator` to an integer with half to even.
///
/// SPEC 4.1 uses half to even for derived money conversions. Used by the
/// monthly average, which must not drift with the display format.
BigInt roundHalfEvenDivision(BigInt numerator, BigInt denominator) {
  if (denominator == BigInt.zero) {
    throw ArgumentError.value(denominator, 'denominator', 'Must not be zero');
  }
  final value = Decimal.fromBigInt(numerator).toRational() /
      Decimal.fromBigInt(denominator).toRational();
  final floor = value.floor();
  final remainder = value - Decimal.fromBigInt(floor).toRational();
  final half = Decimal.parse('0.5').toRational();
  if (remainder < half) {
    return floor;
  }
  if (remainder > half) {
    return floor + BigInt.one;
  }
  return floor.isEven ? floor : floor + BigInt.one;
}

/// The exact ratio `part / whole`, rounded to [scale] decimal places.
///
/// Throws [ArgumentError] when [whole] is zero; a ratio without a whole is
/// not available and callers must show a state instead (SPEC 4.9).
Decimal ratioToScale(Decimal part, Decimal whole, {int scale = 1}) {
  if (scale < 0) {
    throw ArgumentError.value(scale, 'scale', 'Must be zero or more');
  }
  if (whole == Decimal.zero) {
    throw ArgumentError.value(whole, 'whole', 'Must not be zero');
  }
  final factor = _tenPower(scale);
  final scaled = (part.toRational() / whole.toRational()) * factor.toRational();
  final rounded = scaled.round();
  return (Decimal.fromBigInt(rounded).toRational() / factor.toRational())
      .toDecimal();
}

/// SPEC 4.4: [part] as a share of [whole] in percentage points.
///
/// Returns null when [whole] is zero or negative: a share of nothing is not
/// available, never 0% (SPEC 4.3).
Percent? percentOfMoney(Money part, Money whole, {int scale = 1}) {
  if (part.currency != whole.currency) {
    throw MoneyCurrencyMismatch(part.currency.code, whole.currency.code);
  }
  if (scale < 0) {
    throw ArgumentError.value(scale, 'scale', 'Must be zero or more');
  }
  if (whole.minor <= 0) {
    return null;
  }
  final factor = _tenPower(scale);
  final scaled = (Decimal.fromInt(part.minor).toRational() /
          Decimal.fromInt(whole.minor).toRational()) *
      Decimal.fromInt(100).toRational() *
      factor.toRational();
  final rounded = scaled.round();
  final points =
      (Decimal.fromBigInt(rounded).toRational() / factor.toRational())
          .toDecimal();
  return Percent.fromPoints(points);
}
