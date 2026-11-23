import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/core/percent.dart';
import 'package:contour/domain/numbers/spending_shares.dart';
import 'package:contour/domain/numbers/spending_totals.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/appendix_a.dart';

Money _usd(int minor) => Money.fromMinor(minor, Currency.usd);

Percent _points(String value) => Percent.fromPoints(Decimal.parse(value));

SpendingEntry _entry({
  SpendingKind kind = SpendingKind.expense,
  int minor = 1000,
  String? category,
  bool? essential,
}) =>
    SpendingEntry(
      date: LocalDate.parse('2026-10-05'),
      kind: kind,
      amount: _usd(minor),
      categoryId: category,
      isEssential: essential,
    );

void main() {
  group('categorySpending with Appendix A October', () {
    late List<CategorySpend> rows;

    setUp(() {
      rows = categorySpending(
        appendixAPayments().where(
          (entry) => entry.date.year == 2026 && entry.date.month == 10,
        ),
        currency: Currency.usd,
      );
    });

    test('lists eight categories, largest first', () {
      expect(rows.length, 8);
      expect(
        rows.map((row) => row.categoryId).toList(),
        <String>[
          'rent',
          'groceries',
          'dining',
          'shopping',
          'transport',
          'utilities',
          'other',
          'subscriptions',
        ],
      );
    });

    test('amounts match the printed category rows', () {
      expect(rows[0].spent, _usd(180000));
      expect(rows[1].spent, _usd(62000));
      expect(rows[7].spent, _usd(9000));
    });

    test('carries the needs and wants tag', () {
      expect(
        rows.firstWhere((row) => row.categoryId == 'rent').isEssential,
        isTrue,
      );
      expect(
        rows.firstWhere((row) => row.categoryId == 'dining').isEssential,
        isFalse,
      );
    });
  });

  group('categorySpending rules', () {
    test('adds fees and subtracts refunds in their category', () {
      final rows = categorySpending(
        <SpendingEntry>[
          _entry(minor: 1000, category: 'a', essential: true),
          _entry(kind: SpendingKind.fee, minor: 120, category: 'a'),
          _entry(kind: SpendingKind.refund, minor: 200, category: 'a'),
        ],
        currency: Currency.usd,
      );
      expect(rows.single.spent, _usd(920));
      expect(rows.single.isEssential, isTrue);
    });

    test('a refund can carry the tag when it comes first', () {
      final rows = categorySpending(
        <SpendingEntry>[
          _entry(
            kind: SpendingKind.refund,
            minor: 200,
            category: 'a',
            essential: true,
          ),
        ],
        currency: Currency.usd,
      );
      expect(rows.single.spent, _usd(-200));
      expect(rows.single.isEssential, isTrue);
    });

    test('skips rows without a category and non-spending kinds', () {
      final rows = categorySpending(
        <SpendingEntry>[
          _entry(minor: 1000, category: 'a', essential: true),
          _entry(minor: 500),
          _entry(kind: SpendingKind.income, minor: 900, category: 'b'),
          _entry(kind: SpendingKind.transfer, minor: 700, category: 'c'),
          _entry(kind: SpendingKind.reimbursable, minor: 600, category: 'd'),
          _entry(kind: SpendingKind.loanIn, minor: 500, category: 'e'),
          _entry(kind: SpendingKind.saleProceeds, minor: 400, category: 'f'),
        ],
        currency: Currency.usd,
      );
      expect(rows.single.categoryId, 'a');
    });

    test('rejects another currency', () {
      final entry = SpendingEntry(
        date: LocalDate.parse('2026-10-05'),
        kind: SpendingKind.expense,
        amount: Money.fromMinor(1000, Currency.eur),
        categoryId: 'a',
      );
      expect(
        () => categorySpending(<SpendingEntry>[entry], currency: Currency.usd),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });

  group('shares', () {
    test('a category share of spending and of money in', () {
      expect(
        shareOfWhole(_usd(180000), _usd(394000)),
        _points('45.7'),
      );
      expect(
        shareOfWhole(_usd(180000), _usd(820000)),
        _points('22.0'),
      );
    });

    test('a share of zero is not available', () {
      expect(shareOfWhole(_usd(100), _usd(0)), isNull);
      expect(shareOfWhole(_usd(100), _usd(-1)), isNull);
    });

    test('rejects a negative scale', () {
      expect(
        () => shareOfWhole(_usd(100), _usd(200), scale: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects another currency', () {
      expect(
        () => shareOfWhole(_usd(100), Money.fromMinor(200, Currency.eur)),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });

  group('needsWantsShares with Appendix A October', () {
    test('needs 73.4, wants 26.6 and nothing unclassified', () {
      final totals = spendingTotals(
        appendixAPayments().where(
          (entry) => entry.date.year == 2026 && entry.date.month == 10,
        ),
        currency: Currency.usd,
      );
      final shares = needsWantsShares(totals);
      expect(shares, <Percent>[_points('73.4'), _points('26.6'), _points('0')]);
      final sum = shares
          .map((share) => share.value)
          .reduce((left, right) => left + right);
      expect(sum, Decimal.parse('100'));
    });

    test('an uncategorised amount keeps the split at 100%', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(minor: 2890, category: 'a', essential: true),
          _entry(minor: 1050, category: 'b', essential: false),
          _entry(kind: SpendingKind.fee, minor: 120),
        ],
        currency: Currency.usd,
      );
      final shares = needsWantsShares(totals);
      expect(shares.length, 3);
      final sum = shares
          .map((share) => share.value)
          .reduce((left, right) => left + right);
      expect(sum, Decimal.parse('100'));
    });

    test('no spending gives no split', () {
      final totals =
          spendingTotals(const <SpendingEntry>[], currency: Currency.usd);
      expect(needsWantsShares(totals), isEmpty);
    });

    test('a zero total gives no split', () {
      final totals = spendingTotals(
        <SpendingEntry>[_entry(minor: 0, category: 'a', essential: true)],
        currency: Currency.usd,
      );
      expect(needsWantsShares(totals), isEmpty);
    });

    test('a signed spending total gives no split', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.refund, minor: 500, essential: false),
        ],
        currency: Currency.usd,
      );
      expect(needsWantsShares(totals), isEmpty);
    });
  });
}
