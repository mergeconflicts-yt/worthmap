import 'package:contour/core/money.dart';
import 'package:contour/domain/payments/payment_split.dart';
import 'package:flutter_test/flutter_test.dart';

Money _usd(int minor) => Money.fromMinor(minor, Currency.usd);

SplitPart _part(int minor, String category, {bool essential = false}) =>
    SplitPart(
      amount: _usd(minor),
      categoryId: category,
      isEssential: essential,
    );

void main() {
  group('checkSplit', () {
    test('the X23 parts balance to 121.30', () {
      final result = checkSplit(
        total: _usd(12130),
        parts: <SplitPart>[
          _part(8412, 'groceries', essential: true),
          _part(2500, 'household'),
          _part(1218, 'gifts'),
        ],
      );
      expect(result, isA<BalancedSplit>());
      final balanced = result as BalancedSplit;
      expect(balanced.total, _usd(12130));
      expect(balanced.parts.length, 3);
      expect(balanced.parts[0].amount, _usd(8412));
    });

    test('one part equal to the total balances', () {
      final result = checkSplit(
        total: _usd(500),
        parts: <SplitPart>[_part(500, 'a')],
      );
      expect(result, isA<BalancedSplit>());
    });

    test('reports what is left to split', () {
      final result = checkSplit(
        total: _usd(12130),
        parts: <SplitPart>[_part(8412, 'a'), _part(2500, 'b')],
      );
      expect(result, isA<UnbalancedSplit>());
      expect((result as UnbalancedSplit).left, _usd(1218));
    });

    test('reports a negative remainder when parts exceed the total', () {
      final result = checkSplit(
        total: _usd(1000),
        parts: <SplitPart>[_part(1200, 'a')],
      );
      expect(result, isA<UnbalancedSplit>());
      expect((result as UnbalancedSplit).left, _usd(-200));
    });

    test('no parts leaves the whole amount', () {
      final result = checkSplit(total: _usd(1000), parts: const <SplitPart>[]);
      expect((result as UnbalancedSplit).left, _usd(1000));
    });

    test('rejects a zero or negative total', () {
      expect(
        () => checkSplit(total: _usd(0), parts: const <SplitPart>[]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a part in another currency', () {
      expect(
        () => checkSplit(
          total: _usd(1000),
          parts: <SplitPart>[
            SplitPart(
              amount: Money.fromMinor(1000, Currency.eur),
              categoryId: 'a',
              isEssential: false,
            ),
          ],
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });

  group('SplitPart', () {
    test('rejects a zero amount', () {
      expect(() => _part(0, 'a'), throwsA(isA<ArgumentError>()));
    });

    test('rejects an empty category', () {
      expect(() => _part(100, ''), throwsA(isA<ArgumentError>()));
    });
  });
}
