import 'package:contour/core/dates.dart';
import 'package:flutter_test/flutter_test.dart';

// T02 — LocalDate and Clock. SPEC 4.1 / AGENTS 6.4: payment dates are local
// calendar dates; domain code never calls DateTime.now (Clock is injected).
// Tests first (AGENTS 2.8).
void main() {
  test('validates real calendar dates', () {
    expect(LocalDate(2024, 2, 29).day, 29);
    expect(LocalDate(2000, 2, 29).day, 29);
    expect(() => LocalDate(2023, 2, 29), throwsArgumentError);
    expect(() => LocalDate(1900, 2, 29), throwsArgumentError);
    expect(() => LocalDate(2026, 13, 1), throwsArgumentError);
    expect(() => LocalDate(2026, 0, 1), throwsArgumentError);
    expect(() => LocalDate(2026, 4, 31), throwsArgumentError);
    expect(() => LocalDate(2026, 10, 0), throwsArgumentError);
  });

  test('reports leap years and month lengths', () {
    expect(LocalDate.isLeapYear(2024), true);
    expect(LocalDate.isLeapYear(2100), false);
    expect(LocalDate.daysInMonth(2024, 2), 29);
    expect(LocalDate.daysInMonth(2023, 2), 28);
    expect(LocalDate.daysInMonth(2024, 4), 30);
  });

  test('parses and formats strict ISO YYYY-MM-DD', () {
    expect(LocalDate.parse('2026-10-13').toString(), '2026-10-13');
    expect(LocalDate.parse('2026-01-05').toString(), '2026-01-05');
    expect(LocalDate.tryParse('2026-2-1'), isNull);
    expect(LocalDate.tryParse('2026-02-30'), isNull);
    expect(LocalDate.tryParse('not a date'), isNull);
    expect(() => LocalDate.parse('2026-2-1'), throwsFormatException);
  });

  test('orders by calendar date and compares by value', () {
    expect(
      LocalDate(2026, 10, 13).compareTo(LocalDate(2026, 10, 14)),
      lessThan(0),
    );
    expect(LocalDate(2026, 10, 13), LocalDate(2026, 10, 13));
    expect(LocalDate(2026, 10, 13).hashCode, LocalDate(2026, 10, 13).hashCode);
  });

  test('FixedClock returns the supplied UTC instant', () {
    final clock = FixedClock(DateTime.utc(2026, 10, 13, 4));
    expect(clock.nowUtc(), DateTime.utc(2026, 10, 13, 4));
  });

  test('daysInMonth rejects an invalid month', () {
    expect(() => LocalDate.daysInMonth(2026, 13), throwsArgumentError);
  });

  test('compareTo compares year, then month, then day', () {
    expect(
      LocalDate(2026, 1, 1).compareTo(LocalDate(2027, 1, 1)),
      lessThan(0),
    );
    expect(
      LocalDate(2026, 5, 1).compareTo(LocalDate(2026, 6, 1)),
      lessThan(0),
    );
  });
}
