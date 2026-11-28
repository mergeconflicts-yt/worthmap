import 'package:contour/core/money.dart';
import 'package:contour/design/design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wholeMoney rounds to whole units with half-up', () {
    final values = <int, String>{
      238226: r'$2,382',
      238260: r'$2,383',
      999999: r'$10,000',
      0: r'$0',
    };
    for (final entry in values.entries) {
      final whole = wholeMoney(Money.fromMinor(entry.key, Currency.usd));
      expect(whole.minor % 100, 0);
      expect(
        formatMoney(whole, trimZeroFraction: true),
        entry.value,
      );
    }
  });

  test('wholeMoney keeps a currency with no minor units', () {
    final yen = wholeMoney(Money.fromMinor(1234, Currency.jpy));
    expect(yen.minor, 1234);
  });
}
