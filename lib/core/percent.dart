import 'package:decimal/decimal.dart';

/// SPEC 4.1: percentages in one split add to exactly 100%.
///
/// The value is stored in percentage points: `Percent.fromPoints(37)` means
/// 37%. This type holds the value only; SPEC 4.6 and DESIGN 4 put all display
/// formatting in `lib/design/format/` (`PercentText`).
final class Percent {
  const Percent._(this.value);

  /// Builds a percent from percentage points (`37` means 37%).
  factory Percent.fromPoints(Decimal points) => Percent._(points);

  /// Builds a percent from a fraction of a whole (`0.37` means 37%).
  factory Percent.fromFraction(Decimal fraction) =>
      Percent._(fraction.shift(2));

  /// A zero percent.
  static final Percent zero = Percent._(Decimal.zero);

  static final Decimal _hundred = Decimal.fromInt(100);

  /// The percentage points (37 means 37%).
  final Decimal value;

  /// The fraction of a whole (`37%` is `0.37`).
  Decimal toFraction() => (value / _hundred).toDecimal();

  /// SPEC 4.1: splits [parts] into percentages that add to exactly 100%.
  ///
  /// Uses largest-remainder rounding at [scale] decimal places. Each part
  /// takes its floored share; the remaining units go to the parts with the
  /// largest fractional remainder. An equal remainder follows the input
  /// order. [parts] must be zero or more and must have a positive total.
  static List<Percent> split(List<Decimal> parts, {int scale = 1}) {
    if (scale < 0) {
      throw ArgumentError.value(scale, 'scale', 'Must be zero or more');
    }
    if (parts.isEmpty) {
      return const <Percent>[];
    }

    var total = Decimal.zero;
    for (final part in parts) {
      if (part < Decimal.zero) {
        throw ArgumentError('Every part must be zero or more');
      }
      total = total + part;
    }
    if (total <= Decimal.zero) {
      throw ArgumentError('The total of the parts must be greater than zero');
    }

    final units = BigInt.from(100) * BigInt.from(10).pow(scale);
    final totalRational = total.toRational();
    final totalNumerator = totalRational.numerator;
    final totalDenominator = totalRational.denominator;

    final floors = List<BigInt>.generate(parts.length, (_) => BigInt.zero);
    final remainders = List<BigInt>.generate(parts.length, (_) => BigInt.zero);
    final denominators = List<BigInt>.generate(parts.length, (_) => BigInt.one);
    var floorSum = BigInt.zero;

    for (var i = 0; i < parts.length; i++) {
      final rational = parts[i].toRational();
      final numerator = rational.numerator * units * totalDenominator;
      final denominator = rational.denominator * totalNumerator;
      final floor = numerator ~/ denominator;
      floors[i] = floor;
      denominators[i] = denominator;
      remainders[i] = numerator - floor * denominator;
      floorSum += floor;
    }

    var left = units - floorSum;
    final order = List<int>.generate(parts.length, (i) => i)
      ..sort((a, b) {
        final compare = (remainders[b] * denominators[a])
            .compareTo(remainders[a] * denominators[b]);
        return compare != 0 ? compare : a.compareTo(b);
      });
    for (final index in order) {
      if (left == BigInt.zero) {
        break;
      }
      floors[index] += BigInt.one;
      left -= BigInt.one;
    }

    return <Percent>[
      for (final points in floors)
        Percent._(Decimal.fromBigInt(points).shift(-scale)),
    ];
  }

  @override
  bool operator ==(Object other) => other is Percent && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Percent($value)';
}
