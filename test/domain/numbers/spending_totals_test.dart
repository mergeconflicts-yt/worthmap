import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/core/percent.dart';
import 'package:contour/domain/numbers/spending_totals.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/appendix_a.dart';

Money _usd(int minor) => Money.fromMinor(minor, Currency.usd);

SpendingEntry _entry({
  String date = '2026-10-05',
  SpendingKind kind = SpendingKind.expense,
  int minor = 1000,
  String? category,
  bool? essential,
}) =>
    SpendingEntry(
      date: LocalDate.parse(date),
      kind: kind,
      amount: _usd(minor),
      categoryId: category,
      isEssential: essential,
    );

Money _known(Total total) {
  expect(total, isA<KnownTotal>());
  return (total as KnownTotal).amount;
}

Percent _points(String value) => Percent.fromPoints(Decimal.parse(value));

void main() {
  group('spendingTotals with Appendix A', () {
    late SpendingTotals totals;

    setUp(() {
      totals = spendingTotals(
        appendixAPayments().where(
          (entry) => entry.date.year == 2026 && entry.date.month == 10,
        ),
        currency: Currency.usd,
      );
    });

    test('money in is 8,200', () {
      expect(_known(totals.moneyIn), _usd(820000));
    });

    test('money out is 3,940', () {
      expect(_known(totals.moneyOut), _usd(394000));
    });

    test('kept is 4,260', () {
      expect(_known(totals.kept), _usd(426000));
    });

    test('kept is 52.0% of money in', () {
      expect(totals.keptPercent, _points('52.0'));
    });

    test('needs and wants split spending and add to it', () {
      expect(_known(totals.needs), _usd(289000));
      expect(_known(totals.wants), _usd(105000));
      expect(_known(totals.unclassified), _usd(0));
      expect(
        _known(totals.needs) + _known(totals.wants),
        _known(totals.moneyOut),
      );
    });
  });

  group('spendingTotals rules', () {
    test('a transfer is neither income nor spending', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.expense, minor: 1000, essential: true),
          _entry(kind: SpendingKind.income, minor: 5000),
          _entry(kind: SpendingKind.transfer, minor: 999999),
        ],
        currency: Currency.usd,
      );
      expect(_known(totals.moneyIn), _usd(5000));
      expect(_known(totals.moneyOut), _usd(1000));
      expect(_known(totals.kept), _usd(4000));
    });

    test('a reimbursable payment is excluded from spending', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.expense, minor: 1000, essential: true),
          _entry(
            kind: SpendingKind.reimbursable,
            minor: 500,
            essential: true,
          ),
        ],
        currency: Currency.usd,
      );
      expect(_known(totals.moneyOut), _usd(1000));
      expect(_known(totals.needs), _usd(1000));
    });

    test('loan money and sale proceeds are not income', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.loanIn, minor: 800000),
          _entry(kind: SpendingKind.saleProceeds, minor: 200000),
        ],
        currency: Currency.usd,
      );
      expect(totals.moneyIn, isA<NoneRecordedTotal>());
    });

    test('a fee counts in money out and is unclassified without a category',
        () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.expense, minor: 1000, essential: true),
          _entry(kind: SpendingKind.fee, minor: 120),
        ],
        currency: Currency.usd,
      );
      expect(_known(totals.moneyOut), _usd(1120));
      expect(_known(totals.needs), _usd(1000));
      expect(_known(totals.unclassified), _usd(120));
    });

    test('a refund reduces money out and the bucket of its tag', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.expense, minor: 1000, essential: false),
          _entry(kind: SpendingKind.refund, minor: 250, essential: false),
        ],
        currency: Currency.usd,
      );
      expect(_known(totals.moneyOut), _usd(750));
      expect(_known(totals.wants), _usd(750));
      expect(_known(totals.needs), _usd(0));
    });

    test('refunds above expenses give a signed money out', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.expense, minor: 1000, essential: false),
          _entry(kind: SpendingKind.refund, minor: 3000, essential: false),
        ],
        currency: Currency.usd,
      );
      expect(_known(totals.moneyOut), _usd(-2000));
      expect(totals.kept, isA<NotAvailableTotal>());
    });

    test('an empty period is none recorded, not zero', () {
      final totals = spendingTotals(
        const <SpendingEntry>[],
        currency: Currency.usd,
      );
      expect(totals.moneyIn, isA<NoneRecordedTotal>());
      expect(totals.moneyOut, isA<NoneRecordedTotal>());
      expect(totals.needs, isA<NoneRecordedTotal>());
      expect(totals.wants, isA<NoneRecordedTotal>());
      expect(totals.unclassified, isA<NoneRecordedTotal>());
      expect(totals.keptPercent, isNull);
      expect(
        totals.kept,
        isA<NotAvailableTotal>().having(
          (t) => t.reason,
          'reason',
          NotAvailableReason.moneyInNotRecorded,
        ),
      );
    });

    test('spending without income keeps kept not available', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.expense, minor: 1000, essential: true),
        ],
        currency: Currency.usd,
      );
      expect(_known(totals.moneyOut), _usd(1000));
      expect(
        totals.kept,
        isA<NotAvailableTotal>().having(
          (t) => t.reason,
          'reason',
          NotAvailableReason.moneyInNotRecorded,
        ),
      );
    });

    test('income without spending keeps kept not available', () {
      final totals = spendingTotals(
        <SpendingEntry>[_entry(kind: SpendingKind.income, minor: 1000)],
        currency: Currency.usd,
      );
      expect(
        totals.kept,
        isA<NotAvailableTotal>().having(
          (t) => t.reason,
          'reason',
          NotAvailableReason.moneyOutNotRecorded,
        ),
      );
    });

    test('zero income is known but kept percent is not available', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.income, minor: 0),
          _entry(kind: SpendingKind.expense, minor: 1000, essential: true),
        ],
        currency: Currency.usd,
      );
      expect(_known(totals.moneyIn), _usd(0));
      expect(_known(totals.kept), _usd(-1000));
      expect(totals.keptPercent, isNull);
    });

    test('a zero amount is a real zero, not a missing row', () {
      final totals = spendingTotals(
        <SpendingEntry>[
          _entry(kind: SpendingKind.expense, minor: 0, essential: true),
        ],
        currency: Currency.usd,
      );
      expect(_known(totals.moneyOut), _usd(0));
    });

    test('a negative amount is rejected', () {
      expect(
        () => _entry(minor: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a row in another currency is rejected', () {
      final entry = SpendingEntry(
        date: LocalDate.parse('2026-10-05'),
        kind: SpendingKind.expense,
        amount: Money.fromMinor(1000, Currency.eur),
        isEssential: true,
      );
      expect(
        () => spendingTotals(<SpendingEntry>[entry], currency: Currency.usd),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });
}
