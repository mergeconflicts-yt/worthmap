// P15 (SPEC 4.4; SCREENS X32, X33): the budget limit write path.
//
// SaveLimits writes authored limit rows, their ChangeLog, the budget
// dependency revision and the dirty range. It changes no payment. The total
// limit is the sum of the live category limits; a zero limit is removed.

import 'package:contour/core/money.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/budgets.dart';
import 'package:contour/data/repositories/write_plan.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _account = '00000000-0000-7000-8000-0000000000a1';

String _id(int n) => '00000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

Future<int?> _budgetRevision(Vault vault) async {
  final row = await vault.database.customSelect(
    'SELECT r.revision FROM dependency_revisions r '
    'JOIN dependency_scopes s ON s.id = r.scope_id '
    'WHERE s.kind = ? AND s.scope_key = ?',
    variables: [
      const Variable('settings'),
      const Variable('budget:2026-10'),
    ],
  ).getSingleOrNull();
  return row?.data['revision'] as int?;
}

String _categoryId(int n) =>
    '00000000-0000-7000-8000-0000000000c${n.toString().padLeft(1, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late BudgetRepository budgets;
  var nowMs = 1700000000000;
  var operation = 0;
  var nextId = 100;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newOperationId: () {
        operation += 1;
        return _id(80 + operation);
      },
    );
    budgets = BudgetRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newId: () {
        nextId += 1;
        return _id(nextId);
      },
    );
    operation = 0;
    nextId = 100;
    await vault.database.customStatement(
      "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
    );
    await vault.database.customStatement(
      'INSERT INTO accounts (id, created_at, updated_at, deleted_at, '
      'revision, name, type, currency, institution, is_liability, is_liquid, '
      'include_in_net_worth, archived) '
      "VALUES (?, ?, ?, NULL, 1, 'Checking', 'bank', 'USD', NULL, 0, 1, 1, 0)",
      [_account, nowMs, nowMs],
    );
    for (var index = 1; index <= 8; index++) {
      await vault.database.customStatement(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        'VALUES (?, ?, ?, NULL, 1, ?, NULL, ?, 0, 0)',
        [_categoryId(index), nowMs, nowMs, 'Category $index', 'expense'],
      );
    }
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<void> run(WritePlan plan) async {
    final op = _id(60 + operation);
    await commands.prepare(
      operationId: op,
      commandType: 'budget.saveLimits',
      draftId: _id(40 + operation),
      formType: 'budget',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    await commands.execute(
      operationId: op,
      changes: plan.changes,
      effects: plan.apply,
      resultJson: '{}',
    );
    operation += 1;
  }

  Map<String, int> octoberLimits() => <String, int>{
        _categoryId(1): 180000,
        _categoryId(2): 120000,
        _categoryId(3): 60000,
        _categoryId(4): 50000,
        _categoryId(5): 40000,
        _categoryId(6): 30000,
        _categoryId(7): 30000,
        _categoryId(8): 10000,
      };

  Future<int> transactionCount() async => (await vault.database
          .customSelect('SELECT count(*) AS n FROM transactions')
          .getSingle())
      .data['n'] as int;

  test('SaveLimits creates the month, its limits and its templates', () async {
    final plan = await budgets.planSaveLimits(
      month: '2026-10',
      currency: 'USD',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      limits: octoberLimits(),
    );
    expect(plan.changes, hasLength(8 + 8 + 1));
    expect(await transactionCount(), 0);

    await run(plan);

    final saved = await budgets.limitsFor('2026-10');
    expect(saved, isNotNull);
    expect(saved!.categoryCount, 8);
    expect(saved.totalLimit, Money.fromMinor(520000, Currency.usd));
    expect(await budgets.totalLimit('2026-10'), saved.totalLimit);
    expect(await transactionCount(), 0);

    final templates = await budgets.templates();
    expect(templates, hasLength(8));

    final dirty = await vault.database.customSelect(
      'SELECT d.start_date, d.end_date, d.required_revision '
      'FROM dirty_ranges d JOIN dependency_scopes s ON s.id = d.scope_id '
      'WHERE s.kind = ? AND s.scope_key = ? AND d.projection_kind = ?',
      variables: [
        const Variable('settings'),
        const Variable('budget:2026-10'),
        const Variable('metric.spendingPeriod'),
      ],
    ).getSingle();
    expect(dirty.data['start_date'], '2026-10-01');
    expect(dirty.data['end_date'], '2026-10-31');
    expect(dirty.data['required_revision'], greaterThanOrEqualTo(1));

    final changeLog = await vault.database
        .customSelect('SELECT count(*) AS n FROM change_log')
        .getSingle();
    expect(changeLog.data['n'], 17);
  });

  test('a second save edits, removes and keeps limits', () async {
    await run(
      await budgets.planSaveLimits(
        month: '2026-10',
        currency: 'USD',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        limits: <String, int>{
          _categoryId(1): 180000,
          _categoryId(2): 120000,
          _categoryId(3): 60000,
        },
      ),
    );
    final before = await budgets.limitsFor('2026-10');
    final groceries =
        before!.limits.firstWhere((row) => row.categoryId == _categoryId(2));

    await run(
      await budgets.planSaveLimits(
        month: '2026-10',
        currency: 'USD',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        limits: <String, int>{
          _categoryId(1): 180000,
          _categoryId(2): 100000,
          _categoryId(4): 50000,
          _categoryId(3): 0,
        },
      ),
    );

    final after = await budgets.limitsFor('2026-10');
    expect(after!.categoryCount, 3);
    expect(after.totalLimit, Money.fromMinor(330000, Currency.usd));
    final edited =
        after.limits.firstWhere((row) => row.categoryId == _categoryId(2));
    expect(edited.limitMinor, 100000);
    expect(edited.revision, groceries.revision + 1);
    expect(
      after.limits.any((row) => row.categoryId == _categoryId(3)),
      isFalse,
    );
    final templates = await budgets.templates();
    expect(templates.map((row) => row.categoryId).toSet(), <String>{
      _categoryId(1),
      _categoryId(2),
      _categoryId(4),
    });

    final softDeleted = await vault.database.customSelect(
      'SELECT count(*) AS n FROM budget_limits '
      'WHERE deleted_at IS NOT NULL AND category_id = ?',
      variables: [Variable(_categoryId(3))],
    ).getSingle();
    expect(softDeleted.data['n'], 1);
  });

  test('a zero limit leaves no limit and the total is null', () async {
    await run(
      await budgets.planSaveLimits(
        month: '2026-10',
        currency: 'USD',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        limits: <String, int>{_categoryId(1): 0},
      ),
    );
    final saved = await budgets.limitsFor('2026-10');
    expect(saved, isNull);
    expect(await budgets.totalLimit('2026-10'), isNull);
  });

  test('a negative limit is a caller error', () async {
    await expectLater(
      budgets.planSaveLimits(
        month: '2026-10',
        currency: 'USD',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        limits: <String, int>{_categoryId(1): -1},
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('a start day of 25 gives a month that ends in the next calendar month',
      () async {
    await run(
      await budgets.planSaveLimits(
        month: '2026-09',
        currency: 'USD',
        startDate: '2026-09-25',
        endDate: '2026-10-24',
        limits: <String, int>{_categoryId(1): 180000},
      ),
    );
    final saved = await budgets.limitsFor('2026-09');
    expect(saved, isNotNull);
    expect(saved!.startDate, '2026-09-25');
    expect(saved.endDate, '2026-10-24');
    expect(saved.totalLimit, Money.fromMinor(180000, Currency.usd));
  });

  test('a start date outside the month key is a caller error', () async {
    await expectLater(
      budgets.planSaveLimits(
        month: '2026-10',
        currency: 'USD',
        startDate: '2026-09-25',
        endDate: '2026-10-24',
        limits: <String, int>{_categoryId(1): 180000},
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('an unknown month has no limit', () async {
    expect(await budgets.limitsFor('2026-11'), isNull);
    expect(await budgets.totalLimit('2026-11'), isNull);
  });

  test('a repeated identical save writes no new authored row', () async {
    final limits = <String, int>{_categoryId(1): 180000};
    await run(
      await budgets.planSaveLimits(
        month: '2026-10',
        currency: 'USD',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        limits: limits,
      ),
    );
    final first = await budgets.limitsFor('2026-10');
    final before = await _budgetRevision(vault);
    final second = await budgets.planSaveLimits(
      month: '2026-10',
      currency: 'USD',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      limits: limits,
    );
    expect(second.changes, isEmpty);
    await run(second);
    final after = await budgets.limitsFor('2026-10');
    expect(after!.limits.single.revision, first!.limits.single.revision);
    expect(await _budgetRevision(vault), before);
  });
}
