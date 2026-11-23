// P15 (SPEC 4.4, 6.5; DATABASE_DESIGN 8; query contracts Q09-Q12): the
// spending projection.
//
// One generation holds the requested period's exact contributions, summary
// buckets, category contributions and chart buckets. The staging rows are
// written first; publication moves the current pointer and advances the read
// revision in one transaction (Q09-Q12, SYSTEM_DESIGN 8).
//
// The projection never reads the wall clock: the caller passes today, the
// start day of the budget month and the part of today already elapsed. A
// missing limit keeps its Missing state; the domain comparison falls back to
// the same days of the previous month (SPEC 4.4).

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/percent.dart';
import '../../domain/numbers/spending_budget.dart';
import '../../domain/numbers/spending_ratio.dart';
import '../../domain/numbers/spending_totals.dart';
import '../../domain/periods/budget_month.dart';
import '../../domain/periods/period_math.dart';
import '../../domain/periods/period_range.dart';
import '../db/app_database.dart';
import '../db/read_revision.dart';

/// SPEC 6.5: the Spending period chip.
enum SpendingChip {
  /// The last 7 days, today included.
  week,

  /// The current budget month to date.
  month,

  /// The last 6 complete months.
  sixMonths,

  /// The last 12 complete months.
  year,
}

/// SPEC 4.11: the period that recognises a refund.
enum RefundRecognition {
  /// The month of the refund (the default).
  refundMonth,

  /// The month of the original purchase.
  purchaseMonth,
}

/// Safe projection failure codes (no personal data, AGENTS 2.6).
enum SpendingProjectionErrorCode {
  /// A refund under the purchase-month setting links more than one original
  /// payment. The allocation is not defined here, so the projection fails
  /// closed instead of counting the amount twice.
  multipleRefundLinks,

  /// The period has more source rows than the generation bound.
  tooManyRows,
}

class SpendingProjectionError implements Exception {
  const SpendingProjectionError(this.code);

  final SpendingProjectionErrorCode code;

  @override
  String toString() => 'SpendingProjectionError(${code.name})';
}

/// One spending projection request.
final class SpendingRequest {
  SpendingRequest({
    required this.chip,
    required this.today,
    required this.currency,
    this.startDay = 1,
    this.accountIds = const <String>{},
    this.refundRecognition = RefundRecognition.refundMonth,
    Decimal? shareOfToday,
  }) : shareOfToday = shareOfToday ?? Decimal.one;

  /// The selected period chip.
  final SpendingChip chip;

  /// The local calendar date the request is evaluated for.
  final LocalDate today;

  /// The reporting currency.
  final Currency currency;

  /// The budget month start day (SPEC 6.5).
  final int startDay;

  /// Selected accounts; empty means all accounts.
  final Set<String> accountIds;

  /// The refund recognition period (SPEC 4.11).
  final RefundRecognition refundRecognition;

  /// The part of today already elapsed, 0 to 1 (SPEC 4.4 "Month gone").
  final Decimal shareOfToday;

  /// The inclusive range of the selected chip (SPEC 6.5).
  DateRange get range => spendingPeriod(today, _periodKind, startDay: startDay);

  /// The budget month that contains [today].
  BudgetMonth get budgetMonth =>
      BudgetMonth.containing(today, startDay: startDay);

  PeriodKind get _periodKind => switch (chip) {
        SpendingChip.week => PeriodKind.week,
        SpendingChip.month => PeriodKind.month,
        SpendingChip.sixMonths => PeriodKind.sixMonths,
        SpendingChip.year => PeriodKind.year,
      };

  /// The number of monthly limits a multi-month chip compares with.
  int get limitMonths => switch (chip) {
        SpendingChip.sixMonths => 6,
        SpendingChip.year => 12,
        SpendingChip.week || SpendingChip.month => 1,
      };

  /// The chart level: 0 daily, 1 monthly.
  int get level => switch (chip) {
        SpendingChip.week || SpendingChip.month => 0,
        SpendingChip.sixMonths || SpendingChip.year => 1,
      };
}

/// One category total in the generation.
final class SpendingCategoryBucket {
  const SpendingCategoryBucket({
    required this.categoryId,
    required this.amount,
  });

  /// The category identity, or [SpendingProjection.uncategorised] for
  /// amounts with no category (never guessed, SPEC 4.3).
  final String categoryId;

  /// The net money out for the category.
  final Money amount;
}

/// One chart bucket of the generation (Q12).
final class SpendingChartBucket {
  const SpendingChartBucket({
    required this.index,
    required this.firstDate,
    required this.lastDate,
    required this.amount,
    required this.sourceCount,
  });

  /// The zero-based bucket position.
  final int index;

  /// The first date in the bucket.
  final LocalDate firstDate;

  /// The last date in the bucket.
  final LocalDate lastDate;

  /// The exact net money out, or null for a gap.
  final Money? amount;

  /// The number of source contributions.
  final int sourceCount;
}

/// One published spending period, read from its generation.
final class SpendingSnapshot {
  const SpendingSnapshot({
    required this.generationId,
    required this.rebuilt,
    required this.range,
    required this.partial,
    required this.monthGone,
    required this.moneyOut,
    required this.limit,
    required this.left,
    required this.used,
    required this.sameDaysPrevious,
    required this.categories,
    required this.buckets,
    required this.level,
  });

  /// The integer generation identity.
  final int generationId;

  /// True when this call published a new generation.
  final bool rebuilt;

  /// The requested inclusive range.
  final DateRange range;

  /// True when the last day of the range is still in progress.
  final bool partial;

  /// SPEC 4.4: the share of the budget month that has passed.
  final Percent? monthGone;

  /// Money out, with its state (known or none recorded).
  final Total moneyOut;

  /// The month's total limit, or null when there is no limit.
  final Money? limit;

  /// Limit minus money out, or null when either side is unknown.
  final Money? left;

  /// Money out as a share of the limit.
  final Percent? used;

  /// Money out on the same days of the previous month (SPEC 4.4).
  final Money? sameDaysPrevious;

  /// Category totals, largest first.
  final List<SpendingCategoryBucket> categories;

  /// The chart buckets in index order.
  final List<SpendingChartBucket> buckets;

  /// 0 for daily buckets, 1 for monthly buckets.
  final int level;

  /// SPEC 4.4: the comparison, or the same-day comparison without a limit.
  BudgetStanding get standing => compareSpentToLimit(
        spent: moneyOut,
        limit: limit,
        sameDayLastMonth: sameDaysPrevious,
      );
}

/// The spending projection repository (Q09-Q12).
final class SpendingProjection {
  SpendingProjection({
    required AppDatabase db,
    required DateTime Function() clockUtc,
  })  : _db = db,
        _clockUtc = clockUtc;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;

  /// The registry kind of the spending period metric.
  static const String kind = 'metric.spendingPeriod';

  /// The calculation method version.
  static const int methodVersion = 1;

  /// The group identity of an amount with no category.
  static const String uncategorised = 'uncategorised';

  /// The largest source and output page (Q11/Q12 use 500).
  static const int maxPage = 500;

  /// The source contribution bound of one generation.
  static const int maxContributions = 20000;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  /// Publishes or reuses the current generation and reads it.
  ///
  /// A stale or absent generation is rebuilt; an unchanged generation is
  /// reused (Q09). A source change during the read abandons the attempt and
  /// retries once, so a generation never mixes two revisions.
  Future<SpendingSnapshot> project(SpendingRequest request) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final keyId = await _ensureKey(request);
      final current = await _currentGeneration(keyId);
      if (current != null) {
        return _readSnapshot(request, current, rebuilt: false);
      }
      final before = await currentReadRevision(_db);
      final computed = await _compute(request);
      final after = await currentReadRevision(_db);
      if (before != after) {
        continue;
      }
      final published = await _publish(
        request,
        keyId,
        computed,
        expectedReadRevision: after,
      );
      if (!published) {
        continue;
      }
      final generation = await _currentGeneration(keyId);
      if (generation == null) {
        throw StateError('The spending generation did not publish');
      }
      return _readSnapshot(request, generation, rebuilt: true);
    }
    throw StateError('The spending projection changed during the read');
  }

  /// Reads the current generation without building one.
  ///
  /// Null means no current generation: a screen shows Updating and asks for
  /// [project] (Q09).
  Future<SpendingSnapshot?> read(SpendingRequest request) async {
    final keyId = await _findKey(request);
    if (keyId == null) {
      return null;
    }
    final current = await _currentGeneration(keyId);
    if (current == null) {
      return null;
    }
    return _readSnapshot(request, current, rebuilt: false);
  }

  Future<int?> _findKey(SpendingRequest request) async {
    final scopeJson = _scopeJson(request);
    final policyJson = _policyJson(request);
    final rows = await _db.customSelect(
      'SELECT id FROM projection_keys WHERE kind = ? AND scope_hash = ? '
      'AND period_start = ? AND period_end = ? AND currency = ? '
      'AND method_version = ? AND policy_digest = ? '
      'AND scope_json = ? AND policy_json = ?',
      variables: [
        const Variable(kind),
        Variable(_digest(scopeJson)),
        Variable(request.range.start.toString()),
        Variable(request.range.end.toString()),
        Variable(request.currency.code),
        const Variable(methodVersion),
        Variable(_digest(policyJson)),
        Variable(scopeJson),
        Variable(policyJson),
      ],
    ).get();
    return rows.isEmpty ? null : rows.first.data['id'] as int;
  }

  Future<int> _ensureKey(SpendingRequest request) async {
    final existing = await _findKey(request);
    if (existing != null) {
      return existing;
    }
    final scopeJson = _scopeJson(request);
    final policyJson = _policyJson(request);
    await _db.customStatement(
      'INSERT INTO projection_keys (kind, scope_hash, scope_json, '
      'period_start, period_end, as_of, currency, method_version, '
      'policy_digest, policy_json) '
      'VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?)',
      [
        kind,
        _digest(scopeJson),
        scopeJson,
        request.range.start.toString(),
        request.range.end.toString(),
        request.currency.code,
        methodVersion,
        _digest(policyJson),
        policyJson,
      ],
    );
    final row =
        await _db.customSelect('SELECT last_insert_rowid() AS id').getSingle();
    return row.data['id'] as int;
  }

  String _scopeJson(SpendingRequest request) {
    final accounts = request.accountIds.toList()..sort();
    return jsonEncode(<String, Object?>{
      'accounts': accounts,
      'allAccounts': accounts.isEmpty,
      'refundRecognition': request.refundRecognition.name,
      'startDay': request.startDay,
    });
  }

  String _policyJson(SpendingRequest request) {
    final monthGone = _monthGone(request);
    return jsonEncode(<String, Object?>{
      'mode': 'current',
      'chip': request.chip.name,
      'periodStart': request.range.start.toString(),
      'periodEnd': request.range.end.toString(),
      'through': request.today.toString(),
      'partial': _partial(request),
      'monthGone': monthGone?.value.toString(),
      'shareOfToday': request.shareOfToday.toString(),
      'limitMonths': request.limitMonths,
      'level': request.level,
    });
  }

  bool _partial(SpendingRequest request) => request.range.end == request.today;

  Percent? _monthGone(SpendingRequest request) {
    if (request.chip != SpendingChip.month) {
      return null;
    }
    return request.budgetMonth.monthGone(
      shareOfToday: request.shareOfToday,
    );
  }

  static Uint8List _digest(String value) =>
      Uint8List.fromList(sha256.convert(utf8.encode(value)).bytes);

  Future<_Generation?> _currentGeneration(int keyId) async {
    final row = await _db.customSelect(
      'SELECT g.id, g.coverage_json '
      'FROM current_projections c '
      'JOIN projection_generations g ON g.id = c.generation_id '
      'JOIN db_state s ON s.singleton = 1 '
      'WHERE c.key_id = ? AND g.db_epoch = s.db_epoch '
      "AND g.status = 'published' "
      'AND NOT EXISTS ('
      'SELECT 1 FROM projection_inputs i '
      'LEFT JOIN dependency_revisions d ON d.scope_id = i.scope_id '
      'WHERE i.generation_id = g.id '
      'AND (d.scope_id IS NULL OR i.input_revision <> d.revision))',
      variables: [Variable(keyId)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _Generation(
      id: row.data['id'] as int,
      coverage: row.data['coverage_json'] as String,
    );
  }

  Future<_Computed> _compute(SpendingRequest request) async {
    final contributions = await _readContributions(
      request,
      request.range,
      request.refundRecognition,
    );
    if (contributions.length > maxContributions) {
      throw const SpendingProjectionError(
        SpendingProjectionErrorCode.tooManyRows,
      );
    }
    final entries = <SpendingEntry>[
      for (final row in contributions)
        if (row.spendingKind != null)
          SpendingEntry(
            date: row.date,
            kind: row.spendingKind!,
            amount: Money.fromMinor(row.absMinor, request.currency),
            categoryId: row.categoryId,
          ),
    ];
    final totals = spendingTotals(entries, currency: request.currency);
    final categoryAmounts = <String, int>{};
    for (final row in contributions) {
      final category = row.categoryId;
      if (category == null || row.spendingMinor == 0) {
        continue;
      }
      categoryAmounts[category] =
          (categoryAmounts[category] ?? 0) + row.spendingMinor;
    }

    final sameDays = request.chip == SpendingChip.month
        ? await _readMoneyOut(
            request,
            sameDaysPreviousMonth(request.today, startDay: request.startDay),
          )
        : null;

    final monthLimit = await _monthlyLimit(request);
    final limit = monthLimit == null
        ? null
        : Money.fromMinor(
            monthLimit.minor * request.limitMonths,
            request.currency,
          );

    final knownOut = totals.moneyOut is KnownTotal
        ? (totals.moneyOut as KnownTotal).amount
        : null;
    final left = knownOut == null || limit == null ? null : limit - knownOut;
    final monthGone = _monthGone(request);
    final buckets = _chartBuckets(request, contributions);
    final coverage = <String, Object?>{
      'period': <String, Object?>{
        'start': request.range.start.toString(),
        'end': request.range.end.toString(),
      },
      'chip': request.chip.name,
      'partial': _partial(request),
      'through': request.today.toString(),
      if (monthGone != null) 'monthGone': monthGone.value.toString(),
      'refundRecognition': request.refundRecognition.name,
      'level': request.level,
      'limitMonths': request.limitMonths,
      'contributions': contributions.length,
    };

    return _Computed(
      total: totals.moneyOut,
      categoryAmounts: categoryAmounts,
      limit: limit,
      left: left,
      sameDays: sameDays,
      buckets: buckets,
      coverageJson: jsonEncode(coverage),
      contributions: contributions,
    );
  }

  Future<Money?> _monthlyLimit(SpendingRequest request) async {
    final month = request.budgetMonth;
    final row = await _db.customSelect(
      'SELECT SUM(l.limit_minor) AS total FROM budgets b '
      'JOIN budget_limits l ON l.budget_id = b.id '
      'WHERE b.month = ? AND b.currency = ? AND b.deleted_at IS NULL '
      'AND l.deleted_at IS NULL AND l.limit_minor > 0',
      variables: [
        Variable(_monthKey(month.start)),
        Variable(request.currency.code),
      ],
    ).getSingle();
    final total = row.data['total'];
    if (total is! int || total <= 0) {
      return null;
    }
    return Money.fromMinor(total, request.currency);
  }

  Future<Total> _readMoneyOut(
    SpendingRequest request,
    DateRange range,
  ) async {
    final contributions = await _readContributions(
      request,
      range,
      request.refundRecognition,
    );
    final entries = <SpendingEntry>[
      for (final row in contributions)
        if (row.spendingKind != null)
          SpendingEntry(
            date: row.date,
            kind: row.spendingKind!,
            amount: Money.fromMinor(row.absMinor, request.currency),
          ),
    ];
    return spendingTotals(entries, currency: request.currency).moneyOut;
  }

  List<_ChartRow> _chartBuckets(
    SpendingRequest request,
    List<_Contribution> contributions,
  ) {
    final byDate = <String, List<_Contribution>>{};
    for (final row in contributions) {
      if (row.spendingKind == null || row.spendingKind == SpendingKind.income) {
        continue;
      }
      byDate.putIfAbsent(row.date.toString(), () => <_Contribution>[]).add(row);
    }
    if (byDate.isEmpty) {
      return <_ChartRow>[
        _ChartRow(
          index: 0,
          firstDate: request.range.start,
          lastDate: request.range.end,
          amountMinor: null,
          sourceCount: 0,
        ),
      ];
    }
    if (request.level == 0) {
      final rows = <_ChartRow>[];
      var date = request.range.start;
      var index = 0;
      while (date.compareTo(request.range.end) <= 0) {
        final dayRows = byDate[date.toString()] ?? const <_Contribution>[];
        rows.add(
          _ChartRow(
            index: index,
            firstDate: date,
            lastDate: date,
            amountMinor:
                dayRows.fold<int>(0, (sum, row) => sum + row.spendingMinor),
            sourceCount: dayRows.length,
          ),
        );
        date = addDays(date, 1);
        index += 1;
      }
      return rows;
    }
    final grouped = <String, List<_Contribution>>{};
    for (final row in contributions) {
      if (row.spendingKind == null || row.spendingKind == SpendingKind.income) {
        continue;
      }
      final month =
          BudgetMonth.containing(row.date, startDay: request.startDay);
      grouped
          .putIfAbsent(month.start.toString(), () => <_Contribution>[])
          .add(row);
    }
    final rows = <_ChartRow>[];
    var month = BudgetMonth.containing(
      request.range.start,
      startDay: request.startDay,
    );
    var index = 0;
    while (month.start.compareTo(request.range.end) <= 0) {
      final key = month.start.toString();
      final monthRows = grouped[key] ?? const <_Contribution>[];
      rows.add(
        _ChartRow(
          index: index,
          firstDate: month.start,
          lastDate: month.end,
          amountMinor:
              monthRows.fold<int>(0, (sum, row) => sum + row.spendingMinor),
          sourceCount: monthRows.length,
        ),
      );
      month = month.next;
      index += 1;
    }
    return rows;
  }

  Future<List<_Contribution>> _readContributions(
    SpendingRequest request,
    DateRange range,
    RefundRecognition recognition,
  ) async {
    final results = <String, _Contribution>{};
    final refundLinks = <String, Set<String>>{};
    var lastDate = '';
    var lastId = '';
    var lastPart = '';
    while (true) {
      final rows = await _db.customSelect(
        'SELECT t.id AS transaction_id, '
        "COALESCE(s.id, 'parent') AS part_key, "
        't.account_id, '
        'CASE WHEN s.id IS NULL THEN t.category_id ELSE s.category_id END '
        'AS category_id, '
        't.kind, COALESCE(s.amount_minor, t.amount_minor) AS amount_minor, '
        't.currency, t.date, rt.date AS original_date, rl.id AS refund_link_id '
        'FROM transactions t '
        'LEFT JOIN transaction_splits s '
        'ON s.transaction_id = t.id AND s.deleted_at IS NULL '
        'LEFT JOIN refund_links rl '
        'ON rl.refund_transaction_id = t.id AND rl.deleted_at IS NULL '
        'LEFT JOIN transactions rt ON rt.id = rl.original_transaction_id '
        'WHERE t.deleted_at IS NULL AND t.date >= ? AND t.date <= ? '
        'AND t.currency = ? '
        '${request.accountIds.isEmpty ? '' : 'AND t.account_id IN (${List<String>.filled(request.accountIds.length, '?').join(', ')}) '}'
        "AND (t.date, t.id, COALESCE(s.id, 'parent')) > (?, ?, ?) "
        'ORDER BY t.date, t.id, part_key LIMIT ?',
        variables: [
          Variable(range.start.toString()),
          Variable(range.end.toString()),
          Variable(request.currency.code),
          if (request.accountIds.isNotEmpty)
            for (final id in request.accountIds) Variable(id),
          Variable(lastDate),
          Variable(lastId),
          Variable(lastPart),
          const Variable(maxPage),
        ],
      ).get();
      if (rows.isEmpty) {
        break;
      }
      for (final row in rows) {
        final part = row.data['part_key'] as String;
        final transactionId = row.data['transaction_id'] as String;
        // Advance the cursor over every examined row, including a refund
        // that the purchase-month policy moves out of this range (Q04 rule).
        lastDate = row.data['date'] as String;
        lastId = transactionId;
        lastPart = part;
        final contribution = _contributionFromRow(row, recognition);
        final link = row.data['refund_link_id'] as String?;
        if (link != null) {
          refundLinks.putIfAbsent(transactionId, () => <String>{}).add(link);
        }
        if (contribution.date.compareTo(range.start) < 0 ||
            contribution.date.compareTo(range.end) > 0) {
          continue;
        }
        results['$transactionId\u0000$part'] = contribution;
      }
      if (results.length > maxContributions) {
        throw const SpendingProjectionError(
          SpendingProjectionErrorCode.tooManyRows,
        );
      }
      if (rows.length < maxPage) {
        break;
      }
    }
    if (recognition == RefundRecognition.purchaseMonth) {
      for (final links in refundLinks.values) {
        if (links.length > 1) {
          throw const SpendingProjectionError(
            SpendingProjectionErrorCode.multipleRefundLinks,
          );
        }
      }
      await _readMovedRefunds(request, range, results);
    }
    return results.values.toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) {
          return byDate;
        }
        final byTransaction = a.transactionId.compareTo(b.transactionId);
        if (byTransaction != 0) {
          return byTransaction;
        }
        return a.partKey.compareTo(b.partKey);
      });
  }

  Future<void> _readMovedRefunds(
    SpendingRequest request,
    DateRange range,
    Map<String, _Contribution> results,
  ) async {
    final accountClause = request.accountIds.isEmpty
        ? ''
        : 'AND t.account_id IN (${List<String>.filled(request.accountIds.length, '?').join(', ')}) ';
    final rows = await _db.customSelect(
      'SELECT t.id AS transaction_id, '
      "COALESCE(s.id, 'parent') AS part_key, "
      't.account_id, '
      'CASE WHEN s.id IS NULL THEN t.category_id ELSE s.category_id END '
      'AS category_id, '
      't.kind, COALESCE(s.amount_minor, t.amount_minor) AS amount_minor, '
      't.currency, t.date, o.date AS original_date, rl.id AS refund_link_id '
      'FROM refund_links rl '
      'JOIN transactions t ON t.id = rl.refund_transaction_id '
      'JOIN transactions o ON o.id = rl.original_transaction_id '
      'LEFT JOIN transaction_splits s '
      'ON s.transaction_id = t.id AND s.deleted_at IS NULL '
      'WHERE rl.deleted_at IS NULL AND t.deleted_at IS NULL '
      'AND o.date >= ? AND o.date <= ? AND t.currency = ? '
      'AND t.date NOT BETWEEN ? AND ? $accountClause'
      'LIMIT ?',
      variables: [
        Variable(range.start.toString()),
        Variable(range.end.toString()),
        Variable(request.currency.code),
        Variable(range.start.toString()),
        Variable(range.end.toString()),
        if (request.accountIds.isNotEmpty)
          for (final id in request.accountIds) Variable(id),
        const Variable(maxPage + 1),
      ],
    ).get();
    if (rows.length > maxPage) {
      throw const SpendingProjectionError(
        SpendingProjectionErrorCode.tooManyRows,
      );
    }
    final perRefund = <String, Set<String>>{};
    for (final row in rows) {
      final transactionId = row.data['transaction_id'] as String;
      perRefund
          .putIfAbsent(transactionId, () => <String>{})
          .add(row.data['refund_link_id'] as String);
    }
    for (final links in perRefund.values) {
      if (links.length > 1) {
        throw const SpendingProjectionError(
          SpendingProjectionErrorCode.multipleRefundLinks,
        );
      }
    }
    for (final row in rows) {
      final part = row.data['part_key'] as String;
      final transactionId = row.data['transaction_id'] as String;
      results['$transactionId\u0000$part'] = _contributionFromRow(
        row,
        RefundRecognition.purchaseMonth,
      );
    }
  }

  _Contribution _contributionFromRow(
    QueryRow row,
    RefundRecognition recognition,
  ) {
    final kind = row.data['kind'] as String;
    final amount = row.data['amount_minor'] as int;
    final originalDate = row.data['original_date'] as String?;
    final dateSource = recognition == RefundRecognition.purchaseMonth &&
            kind == 'refund' &&
            originalDate != null
        ? originalDate
        : row.data['date'] as String;
    return _Contribution(
      transactionId: row.data['transaction_id'] as String,
      partKey: row.data['part_key'] as String,
      accountId: row.data['account_id'] as String,
      categoryId: row.data['category_id'] as String?,
      date: LocalDate.parse(dateSource),
      kind: kind,
      absMinor: amount.abs(),
      spendingKind: switch (kind) {
        'expense' => SpendingKind.expense,
        'fee' => SpendingKind.fee,
        'refund' => SpendingKind.refund,
        'income' => SpendingKind.income,
        _ => null,
      },
      spendingMinor: switch (kind) {
        'expense' || 'fee' => amount.abs(),
        'refund' => -amount.abs(),
        _ => 0,
      },
      recognitionPolicy: recognition.name,
    );
  }

  Future<bool> _publish(
    SpendingRequest request,
    int keyId,
    _Computed computed, {
    required int expectedReadRevision,
  }) async {
    final scopes = <({String kind, String key})>[
      if (request.accountIds.isEmpty)
        (kind: 'settings', key: 'accounts.all')
      else
        for (final id in request.accountIds) (kind: 'account', key: id),
      (kind: 'settings', key: 'budget:${_monthKey(request.budgetMonth.start)}'),
    ];
    var published = false;
    await _db.transaction(() async {
      final readRevision = await currentReadRevision(_db);
      if (readRevision != expectedReadRevision) {
        return;
      }
      final pins = <int, int>{};
      for (final scope in scopes) {
        await _ensureScope(scope.kind, scope.key);
        final row = await _db.customSelect(
          'SELECT s.id, r.revision FROM dependency_scopes s '
          'JOIN dependency_revisions r ON r.scope_id = s.id '
          'WHERE s.kind = ? AND s.scope_key = ?',
          variables: [Variable(scope.kind), Variable(scope.key)],
        ).getSingleOrNull();
        if (row == null) {
          return;
        }
        pins[row.data['id'] as int] = row.data['revision'] as int;
      }

      final epoch = (await _db
              .customSelect(
                'SELECT db_epoch FROM db_state WHERE singleton = 1',
              )
              .getSingle())
          .data['db_epoch'] as String;
      final commitSequence = await currentCommitSequence(_db);
      final outputRows = computed.summaryRowCount +
          computed.categoryPostings.length +
          computed.buckets.length * 2;
      final previous = await _db.customSelect(
        'SELECT generation_id FROM current_projections WHERE key_id = ?',
        variables: [Variable(keyId)],
      ).getSingleOrNull();

      await _db.customStatement(
        'INSERT INTO projection_generations (key_id, db_epoch, status, '
        'computed_at, source_commit_sequence, coverage_json, output_row_count) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          keyId,
          epoch,
          'staging',
          _nowMs(),
          commitSequence,
          computed.coverageJson,
          outputRows,
        ],
      );
      final generationId = (await _db
              .customSelect('SELECT last_insert_rowid() AS id')
              .getSingle())
          .data['id'] as int;

      for (final pin in pins.entries) {
        await _db.customStatement(
          'INSERT INTO projection_inputs (generation_id, scope_id, '
          'input_revision) VALUES (?, ?, ?)',
          [generationId, pin.key, pin.value],
        );
      }
      await _writeSummary(generationId, request, computed);
      await _writeCategoryPostings(generationId, request, computed);
      await _writeChart(generationId, request, computed);

      await _db.customStatement(
        'UPDATE projection_generations SET status = ? WHERE id = ?',
        ['published', generationId],
      );
      await _db.customStatement(
        'INSERT INTO current_projections (key_id, generation_id) '
        'VALUES (?, ?) ON CONFLICT(key_id) DO UPDATE SET '
        'generation_id = excluded.generation_id',
        [keyId, generationId],
      );
      if (previous != null) {
        final previousId = previous.data['generation_id'] as int;
        if (previousId != generationId) {
          await _db.customStatement(
            'UPDATE projection_generations SET status = ? WHERE id = ?',
            ['obsolete', previousId],
          );
        }
      }
      await advanceReadRevision(_db);
      for (final pin in pins.entries) {
        await _clearDirty(
          scopeId: pin.key,
          revision: pin.value,
          range: request.range,
        );
      }
      published = true;
    });
    return published;
  }

  Future<void> _ensureScope(String kind, String key) async {
    await _db.customStatement(
      'INSERT INTO dependency_scopes (kind, scope_key) '
      'SELECT ?, ? WHERE NOT EXISTS (SELECT 1 FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      [kind, key, kind, key],
    );
    await _db.customStatement(
      'INSERT INTO dependency_revisions (scope_id, revision) '
      'SELECT id, 1 FROM dependency_scopes WHERE kind = ? AND scope_key = ? '
      'AND NOT EXISTS (SELECT 1 FROM dependency_revisions '
      'WHERE scope_id = dependency_scopes.id)',
      [kind, key],
    );
  }

  Future<void> _clearDirty({
    required int scopeId,
    required int revision,
    required DateRange range,
  }) async {
    await _db.customStatement(
      'DELETE FROM dirty_ranges WHERE scope_id = ? AND projection_kind = ? '
      'AND start_date >= ? AND end_date IS NOT NULL AND end_date <= ? '
      'AND required_revision <= ?',
      [
        scopeId,
        kind,
        range.start.toString(),
        range.end.toString(),
        revision,
      ],
    );
  }

  Future<void> _writeSummary(
    int generationId,
    SpendingRequest request,
    _Computed computed,
  ) async {
    final currency = request.currency.code;
    Future<void> put({
      required String bucket,
      required String group,
      required int? amount,
      required String state,
      required int known,
      required int missing,
    }) async {
      await _db.customStatement(
        'INSERT INTO summary_buckets (generation_id, bucket_key, group_key, '
        'currency, amount_minor, value_state, known_count, missing_count) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          generationId,
          bucket,
          group,
          currency,
          amount,
          state,
          known,
          missing,
        ],
      );
    }

    final out = computed.total;
    final knownOut = out is KnownTotal ? out.amount.minor : null;
    await put(
      bucket: 'moneyOut',
      group: 'all',
      amount: knownOut,
      state: knownOut == null ? 'missing' : 'known',
      known: knownOut == null ? 0 : computed.spendingCount,
      missing: knownOut == null ? 1 : 0,
    );
    await put(
      bucket: 'limit',
      group: 'all',
      amount: computed.limit?.minor,
      state: computed.limit == null ? 'missing' : 'known',
      known: computed.limit == null ? 0 : 1,
      missing: computed.limit == null ? 1 : 0,
    );
    await put(
      bucket: 'left',
      group: 'all',
      amount: computed.left?.minor,
      state: computed.left == null ? 'missing' : 'known',
      known: computed.left == null ? 0 : 1,
      missing: computed.left == null ? 1 : 0,
    );
    final sameDaysTotal = computed.sameDays;
    final sameDays =
        sameDaysTotal is KnownTotal ? sameDaysTotal.amount.minor : null;
    await put(
      bucket: 'sameDaysPrevious',
      group: 'all',
      amount: sameDays,
      state: sameDays == null ? 'missing' : 'known',
      known: sameDays == null ? 0 : 1,
      missing: sameDays == null ? 1 : 0,
    );
    for (final entry in computed.categoryAmounts.entries) {
      await put(
        bucket: 'categoryOut',
        group: entry.key,
        amount: entry.value,
        state: 'known',
        known: computed.contributions
            .where((row) => row.categoryId == entry.key)
            .length,
        missing: 0,
      );
    }
    if (computed.unclassifiedMinor != 0) {
      await put(
        bucket: 'categoryOut',
        group: uncategorised,
        amount: computed.unclassifiedMinor,
        state: 'known',
        known: computed.unclassifiedCount,
        missing: 0,
      );
    }
  }

  Future<void> _writeCategoryPostings(
    int generationId,
    SpendingRequest request,
    _Computed computed,
  ) async {
    for (final row in computed.categoryPostings) {
      await _db.customStatement(
        'INSERT INTO category_postings (generation_id, transaction_id, '
        'part_key, account_id, category_id, date, kind, amount_minor, '
        'currency, recognition_policy) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          generationId,
          row.transactionId,
          row.partKey,
          row.accountId,
          row.categoryId,
          row.date.toString(),
          row.kind,
          row.spendingMinor == 0 ? row.absMinor : row.spendingMinor,
          request.currency.code,
          row.recognitionPolicy,
        ],
      );
    }
  }

  Future<void> _writeChart(
    int generationId,
    SpendingRequest request,
    _Computed computed,
  ) async {
    final currency = request.currency.code;
    for (final bucket in computed.buckets) {
      final missing = bucket.amountMinor == null;
      await _db.customStatement(
        'INSERT INTO exact_series_points (generation_id, point_ordinal, date, '
        'same_day_order, effective_at, point_role, value_kind, value_state, '
        'amount_minor, currency, coverage_json) '
        'VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?)',
        [
          generationId,
          bucket.index,
          bucket.lastDate.toString(),
          missing ? 'gap' : 'observation',
          missing ? 'missing' : 'money',
          missing ? 'missing' : 'known',
          missing ? null : bucket.amountMinor,
          missing ? null : currency,
          '{"source":"ledger"}',
        ],
      );
      await _db.customStatement(
        'INSERT INTO chart_buckets (generation_id, first_point_ordinal, '
        'low_point_ordinal, high_point_ordinal, last_point_ordinal, '
        'representation, level, bucket_index, first_date, last_date, '
        'first_minor, low_minor, high_minor, last_minor, currency, '
        'value_kind, source_count) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          generationId,
          bucket.index,
          missing ? null : bucket.index,
          missing ? null : bucket.index,
          bucket.index,
          missing ? 'gap' : 'step',
          request.level,
          bucket.index,
          bucket.firstDate.toString(),
          bucket.lastDate.toString(),
          missing ? null : bucket.amountMinor,
          missing ? null : bucket.amountMinor,
          missing ? null : bucket.amountMinor,
          missing ? null : bucket.amountMinor,
          missing ? null : currency,
          missing ? 'missing' : 'money',
          bucket.sourceCount,
        ],
      );
    }
  }

  Future<SpendingSnapshot> _readSnapshot(
    SpendingRequest request,
    _Generation generation, {
    required bool rebuilt,
  }) async {
    final summary = await _readSummary(generation.id, request.currency.code);
    final categories = <SpendingCategoryBucket>[
      for (final row in summary.where((row) => row.bucket == 'categoryOut'))
        if (row.amountMinor != null)
          SpendingCategoryBucket(
            categoryId: row.groupKey,
            amount: Money.fromMinor(row.amountMinor!, request.currency),
          ),
    ]..sort((a, b) => b.amount.minor.compareTo(a.amount.minor));

    Money? amountOf(String bucket) {
      for (final row in summary) {
        if (row.bucket == bucket && row.groupKey == 'all') {
          final minor = row.amountMinor;
          return minor == null
              ? null
              : Money.fromMinor(minor, request.currency);
        }
      }
      return null;
    }

    final outRow = summary.firstWhere(
      (row) => row.bucket == 'moneyOut' && row.groupKey == 'all',
      orElse: () => const _SummaryRow(
        bucket: 'moneyOut',
        groupKey: 'all',
        amountMinor: null,
        valueState: 'missing',
      ),
    );
    final moneyOut = outRow.amountMinor == null
        ? const NoneRecordedTotal()
        : KnownTotal(
            Money.fromMinor(outRow.amountMinor!, request.currency),
          );
    final limit = amountOf('limit');
    final coverage = jsonDecode(generation.coverage) as Map<String, Object?>;
    final monthGonePoints = coverage['monthGone'] as String?;

    return SpendingSnapshot(
      generationId: generation.id,
      rebuilt: rebuilt,
      range: request.range,
      partial: coverage['partial'] == true,
      monthGone: monthGonePoints == null
          ? null
          : Percent.fromPoints(Decimal.parse(monthGonePoints)),
      moneyOut: moneyOut,
      limit: limit,
      left: amountOf('left'),
      used: _usedOf(moneyOut, limit),
      sameDaysPrevious: amountOf('sameDaysPrevious'),
      categories: categories,
      buckets: await _readChart(generation.id, request.level),
      level: request.level,
    );
  }

  Percent? _usedOf(Total moneyOut, Money? limit) {
    if (moneyOut is! KnownTotal || limit == null) {
      return null;
    }
    return percentOfMoney(moneyOut.amount, limit, scale: 2);
  }

  Future<List<_SummaryRow>> _readSummary(
    int generationId,
    String currency,
  ) async {
    final rows = <_SummaryRow>[];
    for (final bucket in <String>[
      'moneyOut',
      'limit',
      'left',
      'sameDaysPrevious',
    ]) {
      final page = await _db.customSelect(
        'SELECT group_key, amount_minor, value_state FROM summary_buckets '
        'WHERE generation_id = ? AND bucket_key = ? AND currency = ? '
        'AND group_key > ? ORDER BY group_key LIMIT ?',
        variables: [
          Variable(generationId),
          Variable(bucket),
          Variable(currency),
          const Variable(''),
          const Variable(maxPage),
        ],
      ).get();
      for (final row in page) {
        rows.add(_summaryFromRow(bucket, row));
      }
    }
    var lastGroup = '';
    while (true) {
      final page = await _db.customSelect(
        'SELECT group_key, amount_minor, value_state FROM summary_buckets '
        'WHERE generation_id = ? AND bucket_key = ? AND currency = ? '
        'AND group_key > ? ORDER BY group_key LIMIT ?',
        variables: [
          Variable(generationId),
          const Variable('categoryOut'),
          Variable(currency),
          Variable(lastGroup),
          const Variable(maxPage),
        ],
      ).get();
      if (page.isEmpty) {
        break;
      }
      for (final row in page) {
        rows.add(_summaryFromRow('categoryOut', row));
        lastGroup = row.data['group_key'] as String;
      }
      if (page.length < maxPage) {
        break;
      }
    }
    return rows;
  }

  _SummaryRow _summaryFromRow(String bucket, QueryRow row) => _SummaryRow(
        bucket: bucket,
        groupKey: row.data['group_key'] as String,
        amountMinor: row.data['amount_minor'] as int?,
        valueState: row.data['value_state'] as String,
      );

  Future<List<SpendingChartBucket>> _readChart(
    int generationId,
    int level,
  ) async {
    final rows = await _db.customSelect(
      'SELECT bucket_index, first_date, last_date, last_minor, currency, '
      'source_count FROM chart_buckets WHERE generation_id = ? AND level = ? '
      'ORDER BY bucket_index LIMIT ?',
      variables: [
        Variable(generationId),
        Variable(level),
        const Variable(maxPage),
      ],
    ).get();
    return <SpendingChartBucket>[
      for (final row in rows)
        SpendingChartBucket(
          index: row.data['bucket_index'] as int,
          firstDate: LocalDate.parse(row.data['first_date'] as String),
          lastDate: LocalDate.parse(row.data['last_date'] as String),
          amount: row.data['last_minor'] == null
              ? null
              : Money.fromMinor(
                  row.data['last_minor'] as int,
                  Currency.of(row.data['currency'] as String),
                ),
          sourceCount: row.data['source_count'] as int,
        ),
    ];
  }
}

String _monthKey(LocalDate date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

final class _Generation {
  const _Generation({required this.id, required this.coverage});

  final int id;
  final String coverage;
}

final class _Contribution {
  const _Contribution({
    required this.transactionId,
    required this.partKey,
    required this.accountId,
    required this.categoryId,
    required this.date,
    required this.kind,
    required this.absMinor,
    required this.spendingKind,
    required this.spendingMinor,
    required this.recognitionPolicy,
  });

  final String transactionId;
  final String partKey;
  final String accountId;
  final String? categoryId;
  final LocalDate date;
  final String kind;
  final int absMinor;
  final SpendingKind? spendingKind;
  final int spendingMinor;
  final String recognitionPolicy;
}

final class _ChartRow {
  const _ChartRow({
    required this.index,
    required this.firstDate,
    required this.lastDate,
    required this.amountMinor,
    required this.sourceCount,
  });

  final int index;
  final LocalDate firstDate;
  final LocalDate lastDate;
  final int? amountMinor;
  final int sourceCount;
}

final class _SummaryRow {
  const _SummaryRow({
    required this.bucket,
    required this.groupKey,
    required this.amountMinor,
    required this.valueState,
  });

  final String bucket;
  final String groupKey;
  final int? amountMinor;
  final String valueState;
}

final class _Computed {
  _Computed({
    required this.total,
    required this.categoryAmounts,
    required this.limit,
    required this.left,
    required this.sameDays,
    required this.buckets,
    required this.coverageJson,
    required this.contributions,
  });

  final Total total;
  final Map<String, int> categoryAmounts;
  final Money? limit;
  final Money? left;
  final Total? sameDays;
  final List<_ChartRow> buckets;
  final String coverageJson;
  final List<_Contribution> contributions;

  int get spendingCount => contributions
      .where(
        (row) =>
            row.spendingKind == SpendingKind.expense ||
            row.spendingKind == SpendingKind.fee ||
            row.spendingKind == SpendingKind.refund,
      )
      .length;

  int get unclassifiedCount => contributions
      .where((row) => row.categoryId == null && row.spendingMinor != 0)
      .length;

  int get unclassifiedMinor => contributions
      .where((row) => row.categoryId == null)
      .fold<int>(0, (sum, row) => sum + row.spendingMinor);

  int get summaryRowCount =>
      4 + categoryAmounts.length + (unclassifiedMinor != 0 ? 1 : 0);

  List<_Contribution> get categoryPostings =>
      contributions.where((row) => row.spendingKind != null).toList();
}
