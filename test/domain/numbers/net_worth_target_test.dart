// SPEC 13.2: the net worth target share.
import 'package:contour/core/money.dart';
import 'package:contour/domain/numbers/net_worth_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('netWorthTargetShare', () {
    test('SPEC 13.2 sample: 187,900 of 1,000,000 is 18.8%', () {
      final share = netWorthTargetShare(
        current: Money.fromMinor(18790000, Currency.usd),
        target: Money.fromMinor(100000000, Currency.usd),
      );
      expect(share?.value.toString(), '18.8');
    });

    test('rounds once to one decimal place with half up', () {
      final share = netWorthTargetShare(
        current: Money.fromMinor(1, Currency.usd),
        target: Money.fromMinor(3, Currency.usd),
      );
      expect(share?.value.toString(), '33.3');
    });

    test('a missing current value is not zero', () {
      expect(
        netWorthTargetShare(
          current: null,
          target: Money.fromMinor(100000000, Currency.usd),
        ),
        isNull,
      );
    });

    test('a zero target is not available', () {
      expect(
        netWorthTargetShare(
          current: Money.fromMinor(18790000, Currency.usd),
          target: Money.fromMinor(0, Currency.usd),
        ),
        isNull,
      );
    });

    test('a negative current value keeps its sign', () {
      final share = netWorthTargetShare(
        current: Money.fromMinor(-5000000, Currency.usd),
        target: Money.fromMinor(100000000, Currency.usd),
      );
      expect(share?.value.toString(), '-5');
    });
  });
}
