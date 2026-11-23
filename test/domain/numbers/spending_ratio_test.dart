import 'package:contour/core/money.dart';
import 'package:contour/core/percent.dart';
import 'package:contour/domain/numbers/spending_ratio.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

Money _usd(int minor) => Money.fromMinor(minor, Currency.usd);

Percent _points(String value) => Percent.fromPoints(Decimal.parse(value));

void main() {
  group('roundHalfEvenDivision', () {
    test('rounds ties to the even neighbour', () {
      expect(
        roundHalfEvenDivision(BigInt.from(5), BigInt.from(2)),
        BigInt.from(2),
      );
      expect(
        roundHalfEvenDivision(BigInt.from(7), BigInt.from(2)),
        BigInt.from(4),
      );
      expect(
        roundHalfEvenDivision(BigInt.from(-5), BigInt.from(2)),
        BigInt.from(-2),
      );
      expect(
        roundHalfEvenDivision(BigInt.from(-7), BigInt.from(2)),
        BigInt.from(-4),
      );
    });

    test('rounds below and above a half', () {
      expect(roundHalfEvenDivision(BigInt.one, BigInt.from(3)), BigInt.zero);
      expect(roundHalfEvenDivision(BigInt.from(2), BigInt.from(3)), BigInt.one);
    });

    test('rejects a zero denominator', () {
      expect(
        () => roundHalfEvenDivision(BigInt.one, BigInt.zero),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ratioToScale', () {
    test('rounds to the requested scale', () {
      expect(
        ratioToScale(Decimal.one, Decimal.fromInt(3), scale: 2),
        Decimal.parse('0.33'),
      );
      expect(
        ratioToScale(Decimal.fromInt(2), Decimal.fromInt(3), scale: 1),
        Decimal.parse('0.7'),
      );
      expect(
        ratioToScale(Decimal.fromInt(2), Decimal.fromInt(3), scale: 0),
        Decimal.one,
      );
    });

    test('keeps a negative value', () {
      expect(
        ratioToScale(Decimal.fromInt(-1), Decimal.fromInt(4), scale: 2),
        Decimal.parse('-0.25'),
      );
    });

    test('rejects a zero whole and a negative scale', () {
      expect(
        () => ratioToScale(Decimal.one, Decimal.zero),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ratioToScale(Decimal.one, Decimal.fromInt(2), scale: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('percentOfMoney', () {
    test('builds percentage points at the requested scale', () {
      expect(percentOfMoney(_usd(180000), _usd(394000)), _points('45.7'));
      expect(
        percentOfMoney(_usd(394000), _usd(520000), scale: 2),
        _points('75.77'),
      );
      expect(percentOfMoney(_usd(1000), _usd(1000), scale: 0), _points('100'));
    });

    test('a zero or negative whole is not available', () {
      expect(percentOfMoney(_usd(100), _usd(0)), isNull);
      expect(percentOfMoney(_usd(100), _usd(-5)), isNull);
    });

    test('rejects a negative scale and another currency', () {
      expect(
        () => percentOfMoney(_usd(100), _usd(200), scale: -1),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => percentOfMoney(_usd(100), Money.fromMinor(200, Currency.eur)),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });
}
