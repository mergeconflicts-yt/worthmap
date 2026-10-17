import 'package:decimal/decimal.dart';

/// SPEC 4.1: rounding is half to even for conversions and half up for display.
///
/// `halfEven` is the default for money conversions (banker's rounding).
/// `halfUp` rounds an exact tie away from zero and is used for display only.
enum RoundingMode { halfEven, halfUp }

/// The exact power of ten for [exponent] as a [Decimal].
Decimal _tenPow(int exponent) {
  if (exponent >= 0) {
    return BigInt.from(10).pow(exponent).toDecimal();
  }
  return (BigInt.one.toDecimal() / BigInt.from(10).pow(-exponent).toDecimal())
      .toDecimal();
}

/// SPEC 4.1: rounds [value] to [scale] decimal places with [mode].
///
/// An exact tie (`0.5` at the target digit) follows the mode: `halfEven`
/// chooses the even neighbour; `halfUp` moves away from zero.
Decimal roundToScale(Decimal value, int scale, RoundingMode mode) {
  final factor = _tenPow(scale);
  final scaled = value * factor;
  final floored = scaled.floor();
  final fraction = scaled - floored;
  final half = Decimal.parse('0.5');

  final BigInt result;
  if (fraction < half) {
    result = floored.toBigInt();
  } else if (fraction > half) {
    result = floored.toBigInt() + BigInt.one;
  } else {
    switch (mode) {
      case RoundingMode.halfEven:
        final base = floored.toBigInt();
        result = base.isEven ? base : base + BigInt.one;
      case RoundingMode.halfUp:
        result = scaled.signum < 0
            ? floored.toBigInt()
            : floored.toBigInt() + BigInt.one;
    }
  }
  return (result.toDecimal() / factor).toDecimal();
}

/// SPEC 4.1: rounds [value] to the nearest integer minor unit with [mode].
BigInt roundToBigInt(Decimal value, RoundingMode mode) =>
    roundToScale(value, 0, mode).toBigInt();
