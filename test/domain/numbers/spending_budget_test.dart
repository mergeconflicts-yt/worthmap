import 'package:contour/core/money.dart';
import 'package:contour/core/percent.dart';
import 'package:contour/domain/numbers/spending_budget.dart';
import 'package:contour/domain/numbers/spending_totals.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/appendix_a.dart';

Money _usd(int minor) => Money.fromMinor(minor, Currency.usd);

Percent _points(String value) => Percent.fromPoints(Decimal.parse(value));

Total _spent(int minor) => KnownTotal(_usd(minor));

void main() {
  group('compareSpentToLimit with a limit', () {
    test('October is within the 5,200 limit with 1,260 left', () {
      final result = compareSpentToLimit(
        spent: _spent(394000),
        limit: appendixAOctoberLimit(),
      );
      expect(result, isA<WithinLimit>());
      final within = result as WithinLimit;
      expect(within.left, _usd(126000));
      expect(within.spent, _usd(394000));
      expect(within.used, _points('75.77'));
    });

    test('spending exactly at the limit is within, with nothing left', () {
      final result = compareSpentToLimit(
        spent: _spent(520000),
        limit: appendixAOctoberLimit(),
      );
      expect(result, isA<WithinLimit>());
      expect((result as WithinLimit).left, _usd(0));
    });

    test('more than the limit shows the amount over', () {
      final result = compareSpentToLimit(
        spent: _spent(530000),
        limit: appendixAOctoberLimit(),
      );
      expect(result, isA<OverLimit>());
      final over = result as OverLimit;
      expect(over.over, _usd(10000));
      expect(over.used, _points('101.92'));
    });
  });

  group('compareSpentToLimit without a limit', () {
    test('compares with the same days last month', () {
      final result = compareSpentToLimit(
        spent: _spent(394000),
        sameDayLastMonth: appendixASameDaysSeptember(),
      );
      expect(result, isA<ComparedWithoutLimit>());
      final compared = result as ComparedWithoutLimit;
      expect(compared.difference, _usd(-6500));
    });

    test('a zero limit is not a limit', () {
      final result = compareSpentToLimit(
        spent: _spent(394000),
        limit: _usd(0),
        sameDayLastMonth: appendixASameDaysSeptember(),
      );
      expect(result, isA<ComparedWithoutLimit>());
    });

    test('no limit and no previous month is not available', () {
      final result = compareSpentToLimit(spent: _spent(394000));
      expect(result, isA<BudgetNotAvailable>());
    });
  });

  group('compareSpentToLimit states', () {
    test('nothing recorded stays none recorded', () {
      final result = compareSpentToLimit(spent: const NoneRecordedTotal());
      expect(result, isA<BudgetNoneRecorded>());
    });

    test('a not-available spent total stays not available', () {
      final result = compareSpentToLimit(
        spent: const NotAvailableTotal(NotAvailableReason.moneyOutNotRecorded),
      );
      expect(result, isA<BudgetNotAvailable>());
    });

    test('rejects a limit in another currency', () {
      expect(
        () => compareSpentToLimit(
          spent: _spent(1000),
          limit: Money.fromMinor(2000, Currency.eur),
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });

    test('rejects a previous amount in another currency', () {
      expect(
        () => compareSpentToLimit(
          spent: _spent(1000),
          sameDayLastMonth: Money.fromMinor(2000, Currency.eur),
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });
}
