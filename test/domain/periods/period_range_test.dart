import 'package:contour/core/dates.dart';
import 'package:contour/domain/periods/period_range.dart';
import 'package:flutter_test/flutter_test.dart';

LocalDate _d(int year, int month, int day) => LocalDate(year, month, day);

final LocalDate _today = _d(2026, 10, 13);

void _expectRange(DateRange range, LocalDate start, LocalDate end) {
  expect(range.start, start, reason: 'start');
  expect(range.end, end, reason: 'end');
}

void main() {
  group('Spending chips', () {
    test('1W is the last seven days, today included', () {
      _expectRange(
        spendingPeriod(_today, PeriodKind.week),
        _d(2026, 10, 7),
        _d(2026, 10, 13),
      );
    });

    test('1M is the budget month to date', () {
      _expectRange(
        spendingPeriod(_today, PeriodKind.month),
        _d(2026, 10, 1),
        _d(2026, 10, 13),
      );
    });

    test('6M is the last six complete months', () {
      _expectRange(
        spendingPeriod(_today, PeriodKind.sixMonths),
        _d(2026, 4, 1),
        _d(2026, 9, 30),
      );
    });

    test('1Y is the last twelve complete months', () {
      _expectRange(
        spendingPeriod(_today, PeriodKind.year),
        _d(2025, 10, 1),
        _d(2026, 9, 30),
      );
    });

    test('a custom start day moves the month and the multi-month window', () {
      _expectRange(
        spendingPeriod(_today, PeriodKind.month, startDay: 25),
        _d(2026, 9, 25),
        _d(2026, 10, 13),
      );
      _expectRange(
        spendingPeriod(_today, PeriodKind.sixMonths, startDay: 25),
        _d(2026, 3, 25),
        _d(2026, 9, 24),
      );
    });
  });

  group('Money in chips', () {
    test('1W and 1M match the Spending chips', () {
      _expectRange(
        moneyInPeriod(_today, PeriodKind.week),
        _d(2026, 10, 7),
        _d(2026, 10, 13),
      );
      _expectRange(
        moneyInPeriod(_today, PeriodKind.month),
        _d(2026, 10, 1),
        _d(2026, 10, 13),
      );
    });

    test('6M ends with the current month to date', () {
      _expectRange(
        moneyInPeriod(_today, PeriodKind.sixMonths),
        _d(2026, 5, 1),
        _d(2026, 10, 13),
      );
    });

    test('1Y ends with the current month to date', () {
      _expectRange(
        moneyInPeriod(_today, PeriodKind.year),
        _d(2025, 11, 1),
        _d(2026, 10, 13),
      );
    });

    test('a custom start day moves the window start', () {
      _expectRange(
        moneyInPeriod(_today, PeriodKind.sixMonths, startDay: 25),
        _d(2026, 4, 25),
        _d(2026, 10, 13),
      );
    });
  });

  group('same days last month', () {
    test('1-13 October compares with 1-13 September', () {
      _expectRange(
        sameDaysPreviousMonth(_today),
        _d(2026, 9, 1),
        _d(2026, 9, 13),
      );
    });

    test('a short previous month stops at its last day', () {
      _expectRange(
        sameDaysPreviousMonth(_d(2026, 3, 31)),
        _d(2026, 2, 1),
        _d(2026, 2, 28),
      );
    });

    test('a custom start day keeps the day count', () {
      _expectRange(
        sameDaysPreviousMonth(_today, startDay: 25),
        _d(2026, 8, 25),
        _d(2026, 9, 12),
      );
    });
  });

  group('DateRange', () {
    test('counts days and contains only its own dates', () {
      final range = DateRange(_d(2026, 10, 7), _d(2026, 10, 13));
      expect(range.days, 7);
      expect(range.contains(_d(2026, 10, 6)), isFalse);
      expect(range.contains(_d(2026, 10, 7)), isTrue);
      expect(range.contains(_d(2026, 10, 13)), isTrue);
      expect(range.contains(_d(2026, 10, 14)), isFalse);
    });

    test('a single day is a valid range', () {
      final range = DateRange(_today, _today);
      expect(range.days, 1);
    });

    test('prints its two dates', () {
      final range = DateRange(_d(2026, 10, 7), _d(2026, 10, 13));
      expect(range.toString(), '2026-10-07..2026-10-13');
    });

    test('rejects a start after the end', () {
      expect(
        () => DateRange(_d(2026, 10, 14), _d(2026, 10, 13)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
