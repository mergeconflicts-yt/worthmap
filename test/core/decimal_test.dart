import 'package:contour/core/decimal.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

// T02 — Decimal rounding policy. SPEC 4.1: half to even for conversions,
// half up for display. Tests first (AGENTS 2.8).
void main() {
  group('roundToScale halfEven', () {
    test('rounds exact ties to the even neighbour', () {
      expect(
        roundToScale(Decimal.parse('2.5'), 0, RoundingMode.halfEven).toString(),
        '2',
      );
      expect(
        roundToScale(Decimal.parse('3.5'), 0, RoundingMode.halfEven).toString(),
        '4',
      );
      expect(
        roundToScale(Decimal.parse('-2.5'), 0, RoundingMode.halfEven)
            .toString(),
        '-2',
      );
      expect(
        roundToScale(Decimal.parse('-3.5'), 0, RoundingMode.halfEven)
            .toString(),
        '-4',
      );
    });

    test('rounds non-ties to the nearest value', () {
      expect(
        roundToScale(Decimal.parse('2.4'), 0, RoundingMode.halfEven).toString(),
        '2',
      );
      expect(
        roundToScale(Decimal.parse('2.6'), 0, RoundingMode.halfEven).toString(),
        '3',
      );
      expect(
        roundToScale(Decimal.parse('-2.4'), 0, RoundingMode.halfEven)
            .toString(),
        '-2',
      );
      expect(
        roundToScale(Decimal.parse('-2.6'), 0, RoundingMode.halfEven)
            .toString(),
        '-3',
      );
    });

    test('honours the requested scale', () {
      expect(
        roundToScale(Decimal.parse('1.005'), 2, RoundingMode.halfEven)
            .toStringAsFixed(2),
        '1.00',
      );
      expect(
        roundToScale(Decimal.parse('1.015'), 2, RoundingMode.halfEven)
            .toStringAsFixed(2),
        '1.02',
      );
      expect(
        roundToScale(Decimal.parse('1.025'), 2, RoundingMode.halfEven)
            .toStringAsFixed(2),
        '1.02',
      );
    });
  });

  group('roundToScale halfUp (ties away from zero)', () {
    test('rounds exact ties away from zero', () {
      expect(
        roundToScale(Decimal.parse('2.5'), 0, RoundingMode.halfUp).toString(),
        '3',
      );
      expect(
        roundToScale(Decimal.parse('-2.5'), 0, RoundingMode.halfUp).toString(),
        '-3',
      );
    });

    test('leaves non-ties unchanged by the mode', () {
      expect(
        roundToScale(Decimal.parse('2.4'), 0, RoundingMode.halfUp).toString(),
        '2',
      );
      expect(
        roundToScale(Decimal.parse('2.6'), 0, RoundingMode.halfUp).toString(),
        '3',
      );
    });
  });

  test('roundToBigInt returns the integer minor value', () {
    expect(
      roundToBigInt(Decimal.parse('100.5'), RoundingMode.halfEven),
      BigInt.from(100),
    );
    expect(
      roundToBigInt(Decimal.parse('101.5'), RoundingMode.halfEven),
      BigInt.from(102),
    );
  });

  test('supports a negative scale', () {
    expect(
      roundToScale(Decimal.parse('1234.5'), -2, RoundingMode.halfEven)
          .toString(),
      '1200',
    );
  });
}
