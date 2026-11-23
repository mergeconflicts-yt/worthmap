// P15 (SPEC 4.4, 6.5; DATABASE_DESIGN 5; SCREENS X32, X33): budget limits.
//
// The user's limits are their own numbers; the repository stores and reads
// them and never posts money (SPEC 2). One `budgets` row is one local budget
// month; `budget_limits` holds one amount per category in that month;
// `budget_templates` keeps the same numbers for the next month ("each month
// fresh", X33). A limit of zero is not a limit, so the writer removes it
// instead of storing it (SPEC 4.4).
//
// `SaveLimits` is the commit boundary. It writes the authored rows, their
// ChangeLog entries, the budget dependency revision and the dirty range that
// a spending projection consumes. It changes no payment.

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../../core/money.dart';
import '../../domain/periods/period_math.dart';
import '../db/app_database.dart';
import '../db/command_repository.dart';
import 'write_plan.dart';

/// One live category limit of a budget month.
final class BudgetLimitRow {
  const BudgetLimitRow({
    required this.id,
    required this.budgetId,
    required this.categoryId,
    required this.limitMinor,
    required this.currency,
    required this.revision,
  });

  /// The authored limit identity.
  final String id;

  /// The budget month that owns the limit.
  final String budgetId;

  /// The category the limit applies to.
  final String categoryId;

  /// The limit in integer minor units of [currency].
  final int limitMinor;

  /// The budget currency.
  final String currency;

  /// The authored revision.
  final int revision;
}

/// One live budget month and its category limits.
final class BudgetMonthLimits {
  const BudgetMonthLimits({
    required this.budgetId,
    required this.month,
    required this.currency,
    required this.startDate,
    required this.endDate,
    required this.limits,
  });

  /// The budget identity.
  final String budgetId;

  /// The month key, `YYYY-MM`.
  final String month;

  /// The budget currency code.
  final String currency;

  /// The first date of the budget month, inclusive.
  final String startDate;

  /// The last date of the budget month, inclusive.
  final String endDate;

  /// One row per category limit, in category order.
  final List<BudgetLimitRow> limits;

  /// SPEC 4.4: the total limit is the sum of the live category limits.
  ///
  /// A month with no positive limit has no limit: null, never zero.
  Money? get totalLimit {
    var sum = 0;
    var hasLimit = false;
    for (final row in limits) {
      if (row.limitMinor > 0) {
        sum += row.limitMinor;
        hasLimit = true;
      }
    }
    if (!hasLimit) {
      return null;
    }
    return Money.fromMinor(sum, Currency.of(currency));
  }

  /// The number of categories with a positive limit.
  int get categoryCount => limits.where((row) => row.limitMinor > 0).length;
}

/// One live budget template row (the amount used for a fresh month).
final class BudgetTemplateRow {
  const BudgetTemplateRow({
    required this.id,
    required this.categoryId,
    required this.limitMinor,
    required this.currency,
    required this.revision,
  });

  final String id;
  final String categoryId;
  final int limitMinor;
  final String currency;
  final int revision;
}

/// SPEC 4.4 / 6.5: budget reads and the prepared `SaveLimits` write.
final class BudgetRepository {
  BudgetRepository({
    required AppDatabase db,
    required DateTime Function() clockUtc,
    String Function()? newId,
  })  : _db = db,
        _clockUtc = clockUtc,
        _newId = newId;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;
  final String Function()? _newId;

  /// The dependency scope kind used for a budget month. The reference
  /// `dependency_scopes` CHECK has no separate budget kind; a budget month is
  /// a setting-like scope (DATABASE_DESIGN 8).
  static const String scopeKind = 'settings';

  /// The projection kind that consumes the budget dirty range.
  static const String projectionKind = 'metric.spendingPeriod';

  /// The dependency scope key of one budget month.
  static String scopeKey(String month) => 'budget:$month';

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  String _nextId() {
    final injected = _newId;
    if (injected != null) {
      return injected();
    }
    final random = Random.secure();
    final bytes = List<int>.generate(10, (_) => random.nextInt(256));
    return UuidV7.generate(
      unixMillis: _nowMs(),
      randomBytes: bytes,
    ).toString();
  }

  /// One month's live budget and limits, or null when none exists.
  ///
  /// A soft-deleted budget is absent. Limits are ordered by category so the
  /// read is stable for a screen and a test.
  Future<BudgetMonthLimits?> limitsFor(String month) async {
    _checkMonth(month);
    final budget = await _db.customSelect(
      'SELECT id, month, currency, start_date, end_date FROM budgets '
      'WHERE month = ? AND deleted_at IS NULL',
      variables: [Variable(month)],
    ).getSingleOrNull();
    if (budget == null) {
      return null;
    }
    final budgetId = budget.data['id'] as String;
    final rows = await _db.customSelect(
      'SELECT id, budget_id, category_id, limit_minor, currency, revision '
      'FROM budget_limits WHERE budget_id = ? AND deleted_at IS NULL '
      'ORDER BY category_id',
      variables: [Variable(budgetId)],
    ).get();
    return BudgetMonthLimits(
      budgetId: budgetId,
      month: budget.data['month'] as String,
      currency: budget.data['currency'] as String,
      startDate: budget.data['start_date'] as String,
      endDate: budget.data['end_date'] as String,
      limits: <BudgetLimitRow>[
        for (final row in rows)
          BudgetLimitRow(
            id: row.data['id'] as String,
            budgetId: row.data['budget_id'] as String,
            categoryId: row.data['category_id'] as String,
            limitMinor: row.data['limit_minor'] as int,
            currency: row.data['currency'] as String,
            revision: row.data['revision'] as int,
          ),
      ],
    );
  }

  /// SPEC 4.4: the month's total limit, or null when it has no limit.
  Future<Money?> totalLimit(String month) async {
    final budget = await limitsFor(month);
    return budget?.totalLimit;
  }

  /// The live template rows, used to fill a fresh month.
  Future<List<BudgetTemplateRow>> templates() async {
    final rows = await _db
        .customSelect(
          'SELECT id, category_id, limit_minor, currency, revision '
          'FROM budget_templates WHERE deleted_at IS NULL '
          'ORDER BY category_id',
        )
        .get();
    return <BudgetTemplateRow>[
      for (final row in rows)
        BudgetTemplateRow(
          id: row.data['id'] as String,
          categoryId: row.data['category_id'] as String,
          limitMinor: row.data['limit_minor'] as int,
          currency: row.data['currency'] as String,
          revision: row.data['revision'] as int,
        ),
    ];
  }

  /// X33 / DATABASE_DESIGN 5: the `SaveLimits` plan.
  ///
  /// [limits] maps a category identity to its limit in minor units. Zero
  /// removes the limit. A negative amount is a caller error. The plan creates
  /// the month's budget when at least one limit remains, edits changed limits
  /// and soft-deletes removed ones. The template set follows the same values,
  /// so the next month starts with them (X33 "each month fresh").
  ///
  /// The command writer runs the plan; `apply` writes no payment row.
  Future<WritePlan> planSaveLimits({
    required String month,
    required String currency,
    required String startDate,
    required String endDate,
    required Map<String, int> limits,
    String? name,
    String? budgetId,
  }) async {
    _checkMonth(month);
    _checkDates(month, startDate, endDate);
    for (final entry in limits.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          'limits[${entry.key}]',
          'A limit must be zero or positive',
        );
      }
    }
    final positive = <String, int>{
      for (final entry in limits.entries)
        if (entry.value > 0) entry.key: entry.value,
    };

    final existing = await limitsFor(month);
    final existingTemplates = await templates();
    final existingByCategory = <String, BudgetLimitRow>{
      if (existing != null)
        for (final row in existing.limits) row.categoryId: row,
    };
    final templatesByCategory = <String, BudgetTemplateRow>{
      for (final row in existingTemplates) row.categoryId: row,
    };

    final now = _nowMs();
    final changes = <ChangeLogEntry>[];
    final statements = <Future<void> Function()>[];

    String? resolvedBudgetId = existing?.budgetId;
    if (existing == null && positive.isNotEmpty) {
      resolvedBudgetId = budgetId ?? _nextId();
      final id = resolvedBudgetId;
      changes.add(
        ChangeLogEntry(
          entityId: id,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'month': month,
            'currency': currency,
            'startDate': startDate,
            'endDate': endDate,
            if (name != null) 'name': name,
          }),
          schemaVersion: 1,
        ),
      );
      statements.add(() async {
        await _db.customStatement(
          'INSERT INTO budgets (id, created_at, updated_at, deleted_at, '
          'revision, month, period_type, name, currency, start_date, '
          'end_date) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?)',
          [id, now, now, month, 'monthly', name, currency, startDate, endDate],
        );
      });
    }
    if (existing != null && existing.currency != currency) {
      throw ArgumentError.value(
        currency,
        'currency',
        'The budget month uses ${existing.currency}',
      );
    }

    final budgetRowId = resolvedBudgetId;
    if (budgetRowId != null) {
      for (final entry in positive.entries) {
        final current = existingByCategory[entry.key];
        if (current == null) {
          final id = _nextId();
          changes.add(
            ChangeLogEntry(
              entityId: id,
              toRevision: 1,
              changeKind: 'create',
              afterJson: jsonEncode(<String, Object?>{
                'month': month,
                'categoryId': entry.key,
                'limitMinor': entry.value,
              }),
              schemaVersion: 1,
            ),
          );
          statements.add(() async {
            await _db.customStatement(
              'INSERT INTO budget_limits (id, created_at, updated_at, '
              'deleted_at, revision, budget_id, category_id, limit_minor, '
              'currency) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?)',
              [id, now, now, budgetRowId, entry.key, entry.value, currency],
            );
          });
        } else if (current.limitMinor != entry.value) {
          changes.add(
            ChangeLogEntry(
              entityId: current.id,
              fromRevision: current.revision,
              toRevision: current.revision + 1,
              changeKind: 'edit',
              beforeJson: jsonEncode(<String, Object?>{
                'limitMinor': current.limitMinor,
              }),
              afterJson: jsonEncode(<String, Object?>{
                'limitMinor': entry.value,
              }),
              schemaVersion: 1,
            ),
          );
          statements.add(() async {
            await _db.customStatement(
              'UPDATE budget_limits SET limit_minor = ?, updated_at = ?, '
              'revision = revision + 1 WHERE id = ?',
              [entry.value, now, current.id],
            );
          });
        }
      }
      for (final current in existingByCategory.values) {
        if (positive.containsKey(current.categoryId)) {
          continue;
        }
        changes.add(
          ChangeLogEntry(
            entityId: current.id,
            fromRevision: current.revision,
            toRevision: current.revision + 1,
            changeKind: 'softDelete',
            beforeJson: jsonEncode(<String, Object?>{
              'limitMinor': current.limitMinor,
            }),
            afterJson: '{"deleted":true}',
            schemaVersion: 1,
          ),
        );
        statements.add(() async {
          await _db.customStatement(
            'UPDATE budget_limits SET deleted_at = ?, updated_at = ?, '
            'revision = revision + 1 WHERE id = ?',
            [now, now, current.id],
          );
        });
      }
    }

    for (final entry in positive.entries) {
      final current = templatesByCategory[entry.key];
      if (current == null) {
        final id = _nextId();
        changes.add(
          ChangeLogEntry(
            entityId: id,
            toRevision: 1,
            changeKind: 'create',
            afterJson: jsonEncode(<String, Object?>{
              'categoryId': entry.key,
              'limitMinor': entry.value,
            }),
            schemaVersion: 1,
          ),
        );
        statements.add(() async {
          await _db.customStatement(
            'INSERT INTO budget_templates (id, created_at, updated_at, '
            'deleted_at, revision, category_id, limit_minor, currency) '
            'VALUES (?, ?, ?, NULL, 1, ?, ?, ?)',
            [id, now, now, entry.key, entry.value, currency],
          );
        });
      } else if (current.limitMinor != entry.value ||
          current.currency != currency) {
        changes.add(
          ChangeLogEntry(
            entityId: current.id,
            fromRevision: current.revision,
            toRevision: current.revision + 1,
            changeKind: 'edit',
            beforeJson: jsonEncode(<String, Object?>{
              'limitMinor': current.limitMinor,
            }),
            afterJson: jsonEncode(<String, Object?>{
              'limitMinor': entry.value,
            }),
            schemaVersion: 1,
          ),
        );
        statements.add(() async {
          await _db.customStatement(
            'UPDATE budget_templates SET limit_minor = ?, currency = ?, '
            'updated_at = ?, revision = revision + 1 WHERE id = ?',
            [entry.value, currency, now, current.id],
          );
        });
      }
    }
    for (final current in templatesByCategory.values) {
      if (positive.containsKey(current.categoryId)) {
        continue;
      }
      changes.add(
        ChangeLogEntry(
          entityId: current.id,
          fromRevision: current.revision,
          toRevision: current.revision + 1,
          changeKind: 'softDelete',
          beforeJson: jsonEncode(<String, Object?>{
            'limitMinor': current.limitMinor,
          }),
          afterJson: '{"deleted":true}',
          schemaVersion: 1,
        ),
      );
      statements.add(() async {
        await _db.customStatement(
          'UPDATE budget_templates SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ?',
          [now, now, current.id],
        );
      });
    }

    final scopeKeyValue = scopeKey(month);
    if (changes.isEmpty) {
      // A repeated save changes no authored row: it writes no revision and
      // no dirty range, so the projection is not rebuilt for nothing.
      return WritePlan(changes: const <ChangeLogEntry>[], apply: () async {});
    }
    return WritePlan(
      changes: changes,
      apply: () async {
        for (final statement in statements) {
          await statement();
        }
        final revision = await _bumpScope(scopeKind, scopeKeyValue);
        await _markDirty(
          scopeKind: scopeKind,
          scopeKey: scopeKeyValue,
          startDate: startDate,
          endDate: endDate,
          requiredRevision: revision,
        );
      },
    );
  }

  Future<int> _bumpScope(String kind, String key) async {
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
    await _db.customStatement(
      'UPDATE dependency_revisions SET revision = revision + 1 '
      'WHERE scope_id = (SELECT id FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      [kind, key],
    );
    final row = await _db.customSelect(
      'SELECT r.revision FROM dependency_revisions r '
      'JOIN dependency_scopes s ON s.id = r.scope_id '
      'WHERE s.kind = ? AND s.scope_key = ?',
      variables: [Variable(kind), Variable(key)],
    ).getSingle();
    return row.data['revision'] as int;
  }

  Future<void> _markDirty({
    required String scopeKind,
    required String scopeKey,
    required String startDate,
    required String endDate,
    required int requiredRevision,
  }) async {
    await _db.customStatement(
      'INSERT INTO dirty_ranges (scope_id, projection_kind, start_date, '
      'end_date, required_revision) '
      'SELECT id, ?, ?, ?, ? FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ? '
      'ON CONFLICT(scope_id, projection_kind) DO UPDATE SET '
      'start_date = MIN(dirty_ranges.start_date, excluded.start_date), '
      'end_date = CASE WHEN dirty_ranges.end_date IS NULL '
      'OR excluded.end_date IS NULL THEN NULL '
      'ELSE MAX(dirty_ranges.end_date, excluded.end_date) END, '
      'required_revision = MAX(dirty_ranges.required_revision, '
      'excluded.required_revision)',
      [
        projectionKind,
        startDate,
        endDate,
        requiredRevision,
        scopeKind,
        scopeKey,
      ],
    );
  }

  static void _checkMonth(String month) {
    final match = RegExp(r'^([0-9]{4})-([0-9]{2})$').firstMatch(month);
    if (match == null) {
      throw ArgumentError.value(month, 'month', 'Must be YYYY-MM');
    }
    final monthNumber = int.parse(match.group(2)!);
    if (monthNumber < 1 || monthNumber > 12) {
      throw ArgumentError.value(month, 'month', 'Must be a real month');
    }
  }

  static void _checkDates(String month, String startDate, String endDate) {
    final start = LocalDate.parse(startDate);
    final end = LocalDate.parse(endDate);
    if (start.compareTo(end) > 0) {
      throw ArgumentError('The month start must not be after its end');
    }
    // A budget month starts on the user's start day, so it can end in the
    // next calendar month (25 Sep - 24 Oct). The month key is the calendar
    // month of its first day.
    if (_yearMonth(start) != month) {
      throw ArgumentError('The budget month must start inside $month');
    }
    if (daysBetween(start, end) + 1 > 31) {
      throw ArgumentError('A budget month is at most 31 days');
    }
  }

  static String _yearMonth(LocalDate date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';
}
