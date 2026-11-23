import 'package:contour/core/dates.dart';
import 'package:contour/domain/periods/period_math.dart';
import 'package:flutter_test/flutter_test.dart';

LocalDate _d(int year, int month, int day) => LocalDate(year, month, day);

void main() {
  group('addDays', () {
    test('moves within a month and across months and years', () {
      expect(addDays(_d(2026, 10, 13), -6), _d(2026, 10, 7));
      expect(addDays(_d(2026, 10, 1), -1), _d(2026, 9, 30));
      expect(addDays(_d(2026, 12, 31), 1), _d(2027, 1, 1));
      expect(addDays(_d(2028, 2, 28), 1), _d(2028, 2, 29));
    });
  });

  group('addMonths', () {
    test('keeps the day when the month allows it', () {
      expect(addMonths(_d(2026, 10, 13), 1), _d(2026, 11, 13));
      expect(addMonths(_d(2026, 1, 15), -1), _d(2025, 12, 15));
    });

    test('clamps to the last day of the target month', () {
      expect(addMonths(_d(2026, 1, 31), 1), _d(2026, 2, 28));
      expect(addMonths(_d(2028, 1, 31), 1), _d(2028, 2, 29));
      expect(addMonths(_d(2026, 3, 31), -1), _d(2026, 2, 28));
    });
  });

  group('daysBetween', () {
    test('counts whole days with a sign', () {
      expect(daysBetween(_d(2026, 10, 1), _d(2026, 10, 13)), 12);
      expect(daysBetween(_d(2026, 10, 13), _d(2026, 10, 1)), -12);
      expect(daysBetween(_d(2026, 10, 1), _d(2026, 10, 1)), 0);
      expect(daysBetween(_d(2025, 12, 31), _d(2026, 1, 1)), 1);
    });
  });

  group('weekdayOf and startOfWeek', () {
    test('13 October 2026 is a Tuesday', () {
      expect(weekdayOf(_d(2026, 10, 13)), DateTime.tuesday);
    });

    test('the week starts on Monday', () {
      expect(startOfWeek(_d(2026, 10, 13)), _d(2026, 10, 12));
      expect(startOfWeek(_d(2026, 10, 12)), _d(2026, 10, 12));
      expect(startOfWeek(_d(2026, 10, 18)), _d(2026, 10, 12));
    });
  });
}
