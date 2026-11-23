// P26 (SPEC 4.4; flow F08): money in for a spending period.
//
// Money in is income only. Transfers, refunds, reimbursements, loan money and
// sale proceeds are not income (SPEC 4.4). The parent income posting counts
// once; its split rows are parts of the same amount and are never added again.
//
// A read only: this file writes no record and formats no money.

import 'package:drift/drift.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/periods/period_math.dart';
import '../../domain/periods/period_range.dart';
import '../db/app_database.dart';

/// One money-in bucket: a day for 1W/1M, a month for 6M/1Y.
final class MoneyInBucket {
  const MoneyInBucket({
    required this.index,
    required this.firstDate,
    required this.lastDate,
    required this.amount,
  });

  final int index;
  final LocalDate firstDate;
  final LocalDate lastDate;

  /// Null when no income row falls in the bucket.
  final Money? amount;
}

/// The money-in totals of one range.
final class MoneyInSnapshot {
  const MoneyInSnapshot({
    required this.range,
    required this.currency,
    required this.buckets,
    required this.amount,
    required this.count,
  });

  final DateRange range;
  final Currency currency;
  final List<MoneyInBucket> buckets;

  /// Null when no income row is recorded in the range (never zero, SPEC 4.3).
  final Money? amount;

  /// The number of income postings in the range.
  final int count;
}

/// Reads money in for the spending screens.
final class MoneyInProjection {
  MoneyInProjection({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  /// [level] 0 makes daily buckets; 1 makes monthly buckets.
  Future<MoneyInSnapshot> read({
    required DateRange range,
    required Currency currency,
    required int level,
  }) async {
    final rows = await _db.customSelect(
      'SELECT date, sum(amount_minor) AS amount FROM transactions '
      "WHERE deleted_at IS NULL AND kind = 'income' "
      'AND currency = ? AND date >= ? AND date <= ? '
      'GROUP BY date ORDER BY date',
      variables: <Variable<Object>>[
        Variable(currency.code),
        Variable(range.start.toString()),
        Variable(range.end.toString()),
      ],
    ).get();
    final byDay = <String, int>{
      for (final row in rows)
        row.data['date'] as String: (row.data['amount'] as int?) ?? 0,
    };
    final count = await _db.customSelect(
      'SELECT count(*) AS n FROM transactions '
      "WHERE deleted_at IS NULL AND kind = 'income' "
      'AND currency = ? AND date >= ? AND date <= ?',
      variables: <Variable<Object>>[
        Variable(currency.code),
        Variable(range.start.toString()),
        Variable(range.end.toString()),
      ],
    ).getSingle();

    final buckets = <MoneyInBucket>[];
    var index = 0;
    if (level == 0) {
      for (var date = range.start;
          date.compareTo(range.end) <= 0;
          date = addDays(date, 1)) {
        final minor = byDay[date.toString()];
        buckets.add(
          MoneyInBucket(
            index: index,
            firstDate: date,
            lastDate: date,
            amount: minor == null ? null : Money.fromMinor(minor, currency),
          ),
        );
        index += 1;
      }
    } else {
      var monthStart = LocalDate(range.start.year, range.start.month, 1);
      while (monthStart.compareTo(range.end) <= 0) {
        final nextMonth = addMonths(monthStart, 1);
        final monthEnd = addDays(nextMonth, -1);
        final first =
            monthStart.compareTo(range.start) < 0 ? range.start : monthStart;
        final last = monthEnd.compareTo(range.end) > 0 ? range.end : monthEnd;
        var minor = 0;
        var any = false;
        for (var day = first; day.compareTo(last) <= 0; day = addDays(day, 1)) {
          final value = byDay[day.toString()];
          if (value != null) {
            minor += value;
            any = true;
          }
        }
        buckets.add(
          MoneyInBucket(
            index: index,
            firstDate: first,
            lastDate: last,
            amount: any ? Money.fromMinor(minor, currency) : null,
          ),
        );
        index += 1;
        monthStart = nextMonth;
      }
    }

    final total = byDay.values.fold<int>(0, (sum, value) => sum + value);
    return MoneyInSnapshot(
      range: range,
      currency: currency,
      buckets: List<MoneyInBucket>.unmodifiable(buckets),
      amount: byDay.isEmpty ? null : Money.fromMinor(total, currency),
      count: count.data['n'] as int,
    );
  }
}
