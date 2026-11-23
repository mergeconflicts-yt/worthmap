import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/domain/numbers/spending_averages.dart';
import 'package:contour/domain/numbers/spending_totals.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/appendix_a.dart';

Money _usd(int minor) => Money.fromMinor(minor, Currency.usd);

MonthlyTotal _month(int year, int month, int minor) =>
    MonthlyTotal(year: year, month: month, amount: _usd(minor));

Money _average(AverageMonthlyTotal result) {
  expect(result.average, isA<KnownTotal>());
  return (result.average as KnownTotal).amount;
}

void main() {
  group('averageMonthlyTotal with Appendix A', () {
    test('12 complete months average 4,005', () {
      final result = averageMonthlyTotal(
        appendixAMonthlyTotals(),
        currency: Currency.usd,
      );
      expect(_average(result), _usd(400500));
      expect(result.months, 12);
      expect(result.total, _usd(4806000));
    });

    test('May to September averages 4,216 over 5 months', () {
      final result = averageMonthlyTotal(
        appendixAMonthlyTotals().sublist(7),
        currency: Currency.usd,
      );
      expect(_average(result), _usd(421600));
      expect(result.months, 5);
      expect(result.total, _usd(2108000));
    });

    test('fewer than 12 months reports its coverage', () {
      final result = averageMonthlyTotal(
        appendixAMonthlyTotals().sublist(9),
        currency: Currency.usd,
      );
      expect(result.months, 3);
      expect(_average(result), _usd(436000));
    });

    test('at most 12 months are used', () {
      final result = averageMonthlyTotal(
        <MonthlyTotal>[
          _month(2025, 9, 999999),
          ...appendixAMonthlyTotals(),
        ],
        currency: Currency.usd,
      );
      expect(result.months, 12);
      expect(_average(result), _usd(400500));
    });

    test('the 12-month money-in average is 9,266.67 in minor units', () {
      final start = LocalDate.parse('2025-10-01');
      final end = LocalDate.parse('2026-09-30');
      final byMonth = <String, Money>{};
      for (final entry in appendixAPayments()) {
        if (entry.kind != SpendingKind.income ||
            entry.date.compareTo(start) < 0 ||
            entry.date.compareTo(end) > 0) {
          continue;
        }
        final key = '${entry.date.year}-${entry.date.month}';
        byMonth[key] = (byMonth[key] ?? _usd(0)) + entry.amount;
      }
      final months = <MonthlyTotal>[];
      for (final entry in byMonth.entries) {
        final parts = entry.key.split('-');
        months.add(
          MonthlyTotal(
            year: int.parse(parts[0]),
            month: int.parse(parts[1]),
            amount: entry.value,
          ),
        );
      }
      final result = averageMonthlyTotal(months, currency: Currency.usd);
      expect(result.months, 12);
      expect(_average(result), _usd(926667));
    });
  });

  group('averageMonthlyTotal rules', () {
    test('rounds the average with half to even', () {
      expect(
        _average(
          averageMonthlyTotal(
            <MonthlyTotal>[
              _month(2026, 1, 100),
              _month(2026, 2, 101),
            ],
            currency: Currency.usd,
          ),
        ),
        _usd(100),
      );
      expect(
        _average(
          averageMonthlyTotal(
            <MonthlyTotal>[
              _month(2026, 1, 101),
              _month(2026, 2, 102),
            ],
            currency: Currency.usd,
          ),
        ),
        _usd(102),
      );
      expect(
        _average(
          averageMonthlyTotal(
            <MonthlyTotal>[
              _month(2026, 1, 100),
              _month(2026, 2, 100),
              _month(2026, 3, 101),
            ],
            currency: Currency.usd,
          ),
        ),
        _usd(100),
      );
    });

    test('sorts months before taking the window', () {
      final result = averageMonthlyTotal(
        <MonthlyTotal>[
          _month(2026, 2, 2000),
          _month(2026, 1, 1000),
        ],
        currency: Currency.usd,
        maxMonths: 1,
      );
      expect(_average(result), _usd(2000));
    });

    test('no month is none recorded', () {
      final result = averageMonthlyTotal(
        const <MonthlyTotal>[],
        currency: Currency.usd,
      );
      expect(result.average, isA<NoneRecordedTotal>());
      expect(result.months, 0);
      expect(result.total, isNull);
    });

    test('rejects a window below one month', () {
      expect(
        () => averageMonthlyTotal(
          const <MonthlyTotal>[],
          currency: Currency.usd,
          maxMonths: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an invalid month or year', () {
      expect(() => _month(2026, 13, 100), throwsA(isA<ArgumentError>()));
      expect(() => _month(0, 1, 100), throwsA(isA<ArgumentError>()));
    });

    test('rejects another currency', () {
      final month = MonthlyTotal(
        year: 2026,
        month: 1,
        amount: Money.fromMinor(100, Currency.eur),
      );
      expect(
        () => averageMonthlyTotal(
          <MonthlyTotal>[month],
          currency: Currency.usd,
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });

  group('monthsCovered', () {
    test('cash 21,450 over the 4,005 average is 5.4 months', () {
      expect(
        monthsCovered(
          cash: appendixACashYouCanUse(),
          average: _usd(400500),
        ),
        Decimal.parse('5.4'),
      );
      expect(
        monthsCovered(
          cash: appendixACashYouCanUse(),
          average: _usd(400500),
          scale: 2,
        ),
        Decimal.parse('5.36'),
      );
    });

    test('a zero or negative average is not available', () {
      expect(
        monthsCovered(cash: _usd(100), average: _usd(0)),
        isNull,
      );
      expect(
        monthsCovered(cash: _usd(100), average: _usd(-1)),
        isNull,
      );
    });

    test('rejects another currency', () {
      expect(
        () => monthsCovered(
          cash: _usd(100),
          average: Money.fromMinor(100, Currency.eur),
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });
}
