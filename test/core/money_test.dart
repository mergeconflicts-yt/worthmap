import 'package:contour/core/money.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

// T02 — Money value type. SPEC 4.1: integer minor units plus an ISO 4217 code.
// Tests first (AGENTS 2.8).
void main() {
  test('add and subtract stay in minor units', () {
    final a = Money.fromMinor(187900, Currency.usd);
    final b = Money.fromMinor(1250, Currency.usd);
    expect((a - b).minor, 186650);
    expect((a + b).minor, 189150);
  });

  test('throws on a currency mismatch without leaking amounts', () {
    expect(
      () =>
          Money.fromMinor(100, Currency.usd) +
          Money.fromMinor(100, Currency.eur),
      throwsA(isA<MoneyCurrencyMismatch>()),
    );
  });

  test('negate flips the sign', () {
    expect((-Money.fromMinor(500, Currency.usd)).minor, -500);
  });

  test('fromDecimal rounds halfEven for a conversion', () {
    expect(Money.fromDecimal(Decimal.parse('1.005'), Currency.usd).minor, 100);
    expect(Money.fromDecimal(Decimal.parse('1.015'), Currency.usd).minor, 102);
    expect(Money.fromDecimal(Decimal.parse('2.345'), Currency.usd).minor, 234);
    expect(Money.fromDecimal(Decimal.parse('2.355'), Currency.usd).minor, 236);
  });

  test('fromDecimal honours a zero-minor-unit currency (JPY)', () {
    expect(Currency.jpy.minorUnits, 0);
    expect(
      Money.fromDecimal(Decimal.parse('1500.4'), Currency.jpy).minor,
      1500,
    );
    expect(
      Money.fromDecimal(Decimal.parse('1500.5'), Currency.jpy).minor,
      1500,
    );
    expect(
      Money.fromDecimal(Decimal.parse('1501.5'), Currency.jpy).minor,
      1502,
    );
  });

  test('fromDecimal honours a three-minor-unit currency (KWD)', () {
    expect(Currency.kwd.minorUnits, 3);
    expect(
      Money.fromDecimal(Decimal.parse('1.2345'), Currency.kwd).minor,
      1234,
    );
  });

  test('times rounds halfEven to minor units', () {
    final m = Money.fromMinor(1000, Currency.usd); // 10.00
    expect(m.times(Decimal.parse('0.1234')).minor, 123);
    expect(m.times(Decimal.parse('0.1235')).minor, 124);
    expect(m.times(Decimal.parse('0.1245')).minor, 124);
  });

  test('toDecimal is exact for the currency scale', () {
    expect(
      Money.fromMinor(-12345, Currency.usd).toDecimal().toString(),
      '-123.45',
    );
    expect(Money.fromMinor(1500, Currency.jpy).toDecimal().toString(), '1500');
  });

  test('zero and sign helpers', () {
    expect(Money.zero(Currency.usd).isZero, true);
    expect(Money.fromMinor(1, Currency.usd).isNegative, false);
    expect(Money.fromMinor(-1, Currency.usd).isNegative, true);
  });

  test('currency code is validated', () {
    expect(() => Currency('usd', minorUnits: 2), throwsArgumentError);
    expect(() => Currency('US', minorUnits: 2), throwsArgumentError);
    expect(() => Currency('USD', minorUnits: 5), throwsArgumentError);
    expect(Currency('USD', minorUnits: 2).code, 'USD');
  });

  test('compareTo orders by amount', () {
    expect(
      Money.fromMinor(100, Currency.usd)
          .compareTo(Money.fromMinor(200, Currency.usd)),
      lessThan(0),
    );
  });

  test('currency has value semantics and a plain code string', () {
    expect(Currency.usd, Currency('USD', minorUnits: 2));
    expect(Currency.usd.hashCode, Currency('USD', minorUnits: 2).hashCode);
    expect(Currency.usd.toString(), 'USD');
  });

  // CR-12: production code uses the pinned table, not caller metadata.
  test('Currency.of returns the pinned table', () {
    expect(Currency.of('USD'), Currency.usd);
    expect(Currency.of('JPY'), Currency.jpy);
    expect(Currency.of('TWD'), Currency.twd);
    expect(() => Currency.of('XXX'), throwsArgumentError);
  });

  test('money has value semantics and a debug string only', () {
    final a = Money.fromMinor(100, Currency.usd);
    expect(a, Money.fromMinor(100, Currency.usd));
    expect(a.hashCode, Money.fromMinor(100, Currency.usd).hashCode);
    expect(a.toString(), 'Money(100 USD)');
    expect(a == Money.fromMinor(100, Currency.eur), false);
  });

  test('currency mismatch errors carry only codes', () {
    const error = MoneyCurrencyMismatch('USD', 'EUR');
    expect(error.toString(), 'MoneyCurrencyMismatch(USD, EUR)');
    expect(error.left, 'USD');
    expect(error.right, 'EUR');
  });

  test('out-of-range amounts are rejected without leaking the value', () {
    expect(
      () => Money.fromDecimal(
        Decimal.parse('100000000000000000000000000000'),
        Currency.usd,
      ),
      throwsA(isA<MoneyOutOfRange>()),
    );
    expect(const MoneyOutOfRange().toString(), 'MoneyOutOfRange');
  });

  // R03: the signed 64-bit boundary must not overflow silently.
  group('signed 64-bit range', () {
    final int maxInt = Money.maxMinor.toInt();
    final int minInt = Money.minMinor.toInt();
    Money max() => Money.fromMinor(maxInt, Currency.usd);
    Money min() => Money.fromMinor(minInt, Currency.usd);
    Money one() => Money.fromMinor(1, Currency.usd);

    test('bounds are accepted', () {
      expect(max().minor, maxInt);
      expect(min().minor, minInt);
    });

    test('negating the minimum throws, not overflows', () {
      expect(() => -min(), throwsA(isA<MoneyOutOfRange>()));
    });

    test('negating the maximum stays in range', () {
      expect((-max()).minor, minInt + 1);
    });

    test('negating -1, 0 and 1 flips the sign', () {
      expect((-Money.fromMinor(-1, Currency.usd)).minor, 1);
      expect((-Money.zero(Currency.usd)).minor, 0);
      expect((-Money.fromMinor(1, Currency.usd)).minor, -1);
    });

    test('addition past either bound throws', () {
      expect(() => max() + one(), throwsA(isA<MoneyOutOfRange>()));
      expect(() => min() - one(), throwsA(isA<MoneyOutOfRange>()));
      expect((min() + max()).minor, -1);
    });

    test('subtraction past either bound throws', () {
      expect(
        () => max() - Money.fromMinor(-1, Currency.usd),
        throwsA(isA<MoneyOutOfRange>()),
      );
    });

    test('multiplication past either bound throws', () {
      expect(
        () => max().times(Decimal.fromInt(2)),
        throwsA(isA<MoneyOutOfRange>()),
      );
      expect(
        () => min().times(Decimal.fromInt(-1)),
        throwsA(isA<MoneyOutOfRange>()),
      );
      expect(min().times(Decimal.one).minor, minInt);
    });
  });
}
