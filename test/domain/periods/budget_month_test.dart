import 'package:contour/core/dates.dart';
import 'package:contour/core/percent.dart';
import 'package:contour/domain/periods/budget_month.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

LocalDate _d(int year, int month, int day) => LocalDate(year, month, day);

Percent _points(String value) => Percent.fromPoints(Decimal.parse(value));

void main() {
  group('a calendar month (start day 1)', () {
    late BudgetMonth month;

    setUp(() {
      month = BudgetMonth.containing(_d(2026, 10, 13));
    });

    test('runs from the first to the last day', () {
      expect(month.start, _d(2026, 10, 1));
      expect(month.end, _d(2026, 10, 31));
      expect(month.lengthInDays, 31);
      expect(month.dayNumber, 13);
    });

    test('contains its own days and no neighbour', () {
      expect(month.contains(_d(2026, 9, 30)), isFalse);
      expect(month.contains(_d(2026, 10, 1)), isTrue);
      expect(month.contains(_d(2026, 10, 31)), isTrue);
      expect(month.contains(_d(2026, 11, 1)), isFalse);
    });

    test('previous and next cross the year', () {
      expect(month.previous.start, _d(2026, 9, 1));
      expect(month.next.start, _d(2026, 11, 1));
      final january = BudgetMonth.containing(_d(2026, 1, 15));
      expect(january.previous.start, _d(2025, 12, 1));
      expect(january.previous.end, _d(2025, 12, 31));
    });
  });

  group('a custom start day', () {
    test('13 October sits in 25 September to 24 October', () {
      final month = BudgetMonth.containing(_d(2026, 10, 13), startDay: 25);
      expect(month.start, _d(2026, 9, 25));
      expect(month.end, _d(2026, 10, 24));
      expect(month.lengthInDays, 30);
      expect(month.dayNumber, 19);
    });

    test('the start day is day one and the day before is the last', () {
      final first = BudgetMonth.containing(_d(2026, 9, 25), startDay: 25);
      expect(first.dayNumber, 1);
      final last = BudgetMonth.containing(_d(2026, 10, 24), startDay: 25);
      expect(last.start, first.start);
      expect(last.end, _d(2026, 10, 24));
      final next = BudgetMonth.containing(_d(2026, 10, 25), startDay: 25);
      expect(next.start, _d(2026, 10, 25));
    });

    test('the previous month keeps the start day', () {
      final month = BudgetMonth.containing(_d(2026, 10, 13), startDay: 25);
      expect(month.previous.start, _d(2026, 8, 25));
      expect(month.previous.end, _d(2026, 9, 24));
    });
  });

  group('a month-end start day', () {
    test('31 clamps to 30 in April', () {
      final april = BudgetMonth.containing(_d(2026, 4, 15), startDay: 31);
      expect(april.start, _d(2026, 3, 31));
      expect(april.end, _d(2026, 4, 29));
      expect(april.lengthInDays, 30);
      final aprilEnd = BudgetMonth.containing(_d(2026, 4, 30), startDay: 31);
      expect(aprilEnd.start, _d(2026, 4, 30));
      expect(aprilEnd.end, _d(2026, 5, 30));
    });

    test('31 clamps to 28 in a normal February and 29 in a leap one', () {
      final february = BudgetMonth.containing(_d(2026, 2, 15), startDay: 31);
      expect(february.start, _d(2026, 1, 31));
      expect(february.end, _d(2026, 2, 27));
      final leap = BudgetMonth.containing(_d(2028, 2, 15), startDay: 31);
      expect(leap.start, _d(2028, 1, 31));
      expect(leap.end, _d(2028, 2, 28));
    });

    test('a date before this month start belongs to the previous month', () {
      final march = BudgetMonth.containing(_d(2026, 3, 1), startDay: 31);
      expect(march.start, _d(2026, 2, 28));
      expect(march.end, _d(2026, 3, 30));
    });
  });

  group('month gone', () {
    test('13 October is 42% of a 31-day month at day end', () {
      final month = BudgetMonth.containing(_d(2026, 10, 13));
      expect(month.monthGone(shareOfToday: Decimal.one), _points('41.94'));
    });

    test('the part of today and the start of the month count', () {
      final month = BudgetMonth.containing(_d(2026, 10, 13));
      expect(
        month.monthGone(shareOfToday: Decimal.parse('0.5')),
        _points('40.32'),
      );
      expect(month.monthGone(shareOfToday: Decimal.zero), _points('38.71'));
    });

    test('a custom start day changes the position', () {
      final month = BudgetMonth.containing(_d(2026, 10, 13), startDay: 25);
      expect(month.monthGone(shareOfToday: Decimal.one), _points('63.33'));
    });

    test('rejects a share outside 0 to 1', () {
      final month = BudgetMonth.containing(_d(2026, 10, 13));
      expect(
        () => month.monthGone(shareOfToday: Decimal.parse('-0.1')),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => month.monthGone(shareOfToday: Decimal.parse('1.1')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  test('rejects a start day outside 1 to 31', () {
    expect(
      () => BudgetMonth.containing(_d(2026, 10, 13), startDay: 0),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => BudgetMonth.containing(_d(2026, 10, 13), startDay: 32),
      throwsA(isA<ArgumentError>()),
    );
  });
}
