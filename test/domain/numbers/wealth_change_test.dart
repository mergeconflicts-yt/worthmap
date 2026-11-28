// X40 (SCREENS; SPEC 6.5, 13.12): the change between two net-worth readings.
import 'package:contour/core/percent.dart';
import 'package:contour/domain/numbers/wealth_change.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the change is end minus start', () {
    expect(wealthChangeMinor(startMinor: 10000, endMinor: 11000), 1000);
    expect(wealthChangeMinor(startMinor: 20000, endMinor: 15000), -5000);
    expect(wealthChangeMinor(startMinor: 0, endMinor: 250), 250);
  });

  test('a missing reading makes the change Missing', () {
    expect(wealthChangeMinor(startMinor: null, endMinor: 11000), isNull);
    expect(wealthChangeMinor(startMinor: 10000, endMinor: null), isNull);
    expect(wealthChangeMinor(startMinor: null, endMinor: null), isNull);
  });

  test('the share divides by the earlier reading', () {
    final share = wealthChangeShare(startMinor: 10000, endMinor: 11000);
    expect(share, isNotNull);
    expect(share!.value, Decimal.fromInt(10));

    final loss = wealthChangeShare(startMinor: 20000, endMinor: 15000);
    expect(loss!.value, Decimal.fromInt(-25));

    final small = wealthChangeShare(startMinor: 182410, endMinor: 187900);
    expect(small!.value.toStringAsFixed(1), '3.0');
  });

  test('a zero start gives no share, but the change stays known', () {
    expect(wealthChangeMinor(startMinor: 0, endMinor: 250), 250);
    expect(wealthChangeShare(startMinor: 0, endMinor: 250), isNull);
  });

  test('a negative start keeps the sign of the share', () {
    final share = wealthChangeShare(startMinor: -10000, endMinor: -5000);
    expect(share!.value, Decimal.fromInt(-50));
  });

  test('a zero change gives a zero share', () {
    final share = wealthChangeShare(startMinor: 10000, endMinor: 10000);
    expect(share!.value, Decimal.zero);
    expect(share, Percent.zero);
  });
}
