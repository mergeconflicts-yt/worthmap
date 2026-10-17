import 'package:contour/core/percent.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal _d(String value) => Decimal.parse(value);

Decimal _sum(List<Percent> percents) =>
    percents.map((percent) => percent.value).reduce((a, b) => a + b);

void _expectValue(Percent percent, String value) {
  expect(
    percent.value.compareTo(_d(value)),
    equals(0),
    reason: 'expected $value but was ${percent.value}',
  );
}

void main() {
  group('Percent value', () {
    test('fromPoints holds percentage points', () {
      _expectValue(Percent.fromPoints(_d('37')), '37');
    });

    test('fromFraction converts a fraction to percentage points', () {
      _expectValue(Percent.fromFraction(_d('0.37')), '37');
      _expectValue(Percent.fromFraction(_d('1')), '100');
    });

    test('toFraction converts back', () {
      expect(
        Percent.fromPoints(_d('37')).toFraction().compareTo(_d('0.37')),
        equals(0),
      );
    });

    test('zero is zero', () {
      _expectValue(Percent.zero, '0');
    });

    test('equal values are equal and hash the same', () {
      final a = Percent.fromPoints(_d('12.5'));
      final b = Percent.fromPoints(_d('12.50'));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString names the type and value', () {
      expect(Percent.fromPoints(_d('37')).toString(), contains('37'));
    });
  });

  group('Percent.split', () {
    test('matches the appendix home split at scale 1', () {
      final parts = <Decimal>[_d('2890'), _d('1050'), _d('0'), _d('4260')];
      final split = Percent.split(parts);
      expect(split, hasLength(4));
      _expectValue(split[0], '35.2');
      _expectValue(split[1], '12.8');
      _expectValue(split[2], '0');
      _expectValue(split[3], '52');
      expect(_sum(split).compareTo(_d('100')), equals(0));
    });

    test('always adds to exactly 100 at scale 1', () {
      final parts = <Decimal>[_d('1'), _d('7'), _d('11'), _d('3'), _d('2')];
      final split = Percent.split(parts);
      expect(_sum(split).compareTo(_d('100')), equals(0));
    });

    test('whole-number split adds to exactly 100', () {
      final parts = <Decimal>[
        _d('37'),
        _d('36'),
        _d('12'),
        _d('6'),
        _d('5'),
        _d('4'),
      ];
      final split = Percent.split(parts, scale: 0);
      expect(_sum(split).compareTo(_d('100')), equals(0));
      _expectValue(split[0], '37');
      _expectValue(split[1], '36');
    });

    test('equal thirds at scale 0 are stable and add to 100', () {
      final split =
          Percent.split(<Decimal>[_d('1'), _d('1'), _d('1')], scale: 0);
      _expectValue(split[0], '34');
      _expectValue(split[1], '33');
      _expectValue(split[2], '33');
      expect(_sum(split).compareTo(_d('100')), equals(0));
    });

    test('equal thirds at scale 2 add to 100', () {
      final split =
          Percent.split(<Decimal>[_d('1'), _d('1'), _d('1')], scale: 2);
      _expectValue(split[0], '33.34');
      _expectValue(split[1], '33.33');
      _expectValue(split[2], '33.33');
    });

    test('a single part is 100', () {
      final split = Percent.split(<Decimal>[_d('5')]);
      _expectValue(split.single, '100');
    });

    test('a zero part stays at zero', () {
      final split = Percent.split(<Decimal>[_d('1'), _d('0'), _d('0')]);
      _expectValue(split[1], '0');
      _expectValue(split[2], '0');
      expect(_sum(split).compareTo(_d('100')), equals(0));
    });

    test('more parts than units gives the extra to the first in order', () {
      final parts = List<Decimal>.generate(200, (_) => _d('1'));
      final split = Percent.split(parts, scale: 0);
      final hundreds = split.where((p) => p.value.compareTo(_d('1')) == 0);
      final zeros = split.where((p) => p.value.compareTo(Decimal.zero) == 0);
      expect(hundreds, hasLength(100));
      expect(zeros, hasLength(100));
      expect(_sum(split).compareTo(_d('100')), equals(0));
    });

    test('empty input returns empty', () {
      expect(Percent.split(const <Decimal>[]), isEmpty);
    });

    test('does not change the input list', () {
      final parts = <Decimal>[_d('1'), _d('2')];
      Percent.split(parts);
      expect(parts, <Decimal>[_d('1'), _d('2')]);
    });

    test('a negative part is rejected', () {
      expect(
        () => Percent.split(<Decimal>[_d('1'), _d('-1')]),
        throwsArgumentError,
      );
    });

    test('a zero total is rejected', () {
      expect(
        () => Percent.split(<Decimal>[_d('0'), _d('0')]),
        throwsArgumentError,
      );
    });

    test('a negative scale is rejected', () {
      expect(
        () => Percent.split(<Decimal>[_d('1')], scale: -1),
        throwsArgumentError,
      );
    });
  });
}
