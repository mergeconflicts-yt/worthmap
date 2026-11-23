// P26 (flow F08; SPEC 4.4, 6.5): the app composition for Spending.
//
// Reads come from the P15 projection, the P26 money-in read and the P14/P12
// category list. The only write is `SaveLimits`, which writes limits,
// ChangeLog and dirty ranges and never a payment (F08-E).
library;

import '../core/dates.dart';
import '../core/money.dart';
import '../data/db/command_repository.dart';
import '../data/projections/money_in.dart';
import '../data/projections/spending.dart';
import '../data/repositories/budgets.dart';
import '../data/repositories/categories.dart';
import '../domain/numbers/spending_totals.dart';
import '../domain/periods/budget_month.dart';
import '../domain/periods/period_range.dart';
import '../features/spending/spending_models.dart';

/// P15 + P26 + P12 behind the Spending feature port.
final class SqlSpendingGateway implements SpendingGateway {
  SqlSpendingGateway({
    required this.spending,
    required this.moneyIn,
    required this.budgets,
    required this.categories,
    required this.commands,
    required this.today,
    required this.newOperationId,
    this.currencyCode = 'USD',
    this.startDay = 1,
  });

  final SpendingProjection spending;
  final MoneyInProjection moneyIn;
  final BudgetRepository budgets;
  final CategoryRepository categories;
  final CommandRepository commands;
  final LocalDate Function() today;
  final String Function() newOperationId;
  final String currencyCode;
  final int startDay;

  Currency get _currency => Currency.of(currencyCode);

  @override
  Future<SpendingView> loadSpending(SpendingPeriod period) async {
    final request = SpendingRequest(
      chip: _chip(period),
      today: today(),
      currency: _currency,
      startDay: startDay,
    );
    final snapshot = await spending.project(request);
    final names = await _categoryNames();
    final buckets = <SpendingBucketView>[
      for (final bucket in snapshot.buckets)
        SpendingBucketView(
          index: bucket.index,
          firstDate: bucket.firstDate,
          lastDate: bucket.lastDate,
          amountMinor: bucket.amount?.minor,
        ),
    ];
    // The chart is extended to the range so an empty bucket is a gap, not a
    // missing column.
    final categoriesView = <SpendingCategoryView>[
      for (final category in snapshot.categories)
        SpendingCategoryView(
          id: category.categoryId,
          name: names[category.categoryId] ?? '',
          amountMinor: category.amount.minor,
          currencyCode: category.amount.currency.code,
        ),
    ];
    return SpendingView(
      period: period,
      rangeStart: snapshot.range.start,
      rangeEnd: snapshot.range.end,
      currencyCode: currencyCode,
      partial: snapshot.partial,
      moneyOutMinor: _minorOf(snapshot.moneyOut),
      limitMinor: snapshot.limit?.minor,
      leftMinor: snapshot.left?.minor,
      used: snapshot.used,
      sameDaysPreviousMinor: snapshot.sameDaysPrevious?.minor,
      monthGone: snapshot.monthGone,
      monthDay: request.budgetMonth.dayNumber,
      monthDays: request.budgetMonth.lengthInDays,
      categories: categoriesView,
      buckets: buckets,
    );
  }

  @override
  Future<MoneyInView> loadMoneyIn(SpendingPeriod period) async {
    final range = moneyInPeriod(today(), _kind(period), startDay: startDay);
    final snapshot = await moneyIn.read(
      range: range,
      currency: _currency,
      level: period == SpendingPeriod.week || period == SpendingPeriod.month
          ? 0
          : 1,
    );
    return MoneyInView(
      period: period,
      rangeStart: range.start,
      rangeEnd: range.end,
      currencyCode: currencyCode,
      amountMinor: snapshot.amount?.minor,
      count: snapshot.count,
      buckets: <SpendingBucketView>[
        for (final bucket in snapshot.buckets)
          SpendingBucketView(
            index: bucket.index,
            firstDate: bucket.firstDate,
            lastDate: bucket.lastDate,
            amountMinor: bucket.amount?.minor,
          ),
      ],
    );
  }

  @override
  Future<LimitsView> loadLimits() async {
    final month = BudgetMonth.containing(today(), startDay: startDay);
    final key = _monthKey(month.start);
    final existing = await budgets.limitsFor(key);
    final byCategory = <String, int>{
      if (existing != null)
        for (final row in existing.limits) row.categoryId: row.limitMinor,
    };
    final rows = await categories.list(kind: 'expense');
    return LimitsView(
      month: key,
      currencyCode: currencyCode,
      rows: <LimitView>[
        for (final row in rows)
          LimitView(
            categoryId: row.id,
            name: row.name,
            limitMinor: byCategory[row.id] ?? 0,
            currencyCode: currencyCode,
          ),
      ],
    );
  }

  @override
  Future<void> saveLimits(Map<String, int> limits) async {
    final month = BudgetMonth.containing(today(), startDay: startDay);
    final key = _monthKey(month.start);
    final plan = await budgets.planSaveLimits(
      month: key,
      currency: currencyCode,
      startDate: month.start.toString(),
      endDate: month.end.toString(),
      limits: limits,
    );
    final operationId = newOperationId();
    await commands.prepare(
      operationId: operationId,
      commandType: 'budget.saveLimits',
      draftId: newOperationId(),
      formType: 'budget',
      payloadJson: '{"month":"$key"}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    try {
      await commands.execute(
        operationId: operationId,
        changes: plan.changes,
        effects: plan.apply,
        resultJson: '{"month":"$key"}',
      );
    } on Object {
      final receipt = await commands.receiptOf(operationId);
      if (receipt == null) {
        throw const SpendingError(SpendingErrorCode.saveFailed);
      }
    }
  }

  Future<Map<String, String>> _categoryNames() async {
    final rows = await categories.list(kind: 'expense');
    return <String, String>{
      for (final row in rows) row.id: row.name,
    };
  }

  int? _minorOf(Total total) => switch (total) {
        KnownTotal(:final amount) => amount.minor,
        NoneRecordedTotal() || NotAvailableTotal() => null,
      };

  SpendingChip _chip(SpendingPeriod period) => switch (period) {
        SpendingPeriod.week => SpendingChip.week,
        SpendingPeriod.month => SpendingChip.month,
        SpendingPeriod.sixMonths => SpendingChip.sixMonths,
        SpendingPeriod.year => SpendingChip.year,
      };

  PeriodKind _kind(SpendingPeriod period) => switch (period) {
        SpendingPeriod.week => PeriodKind.week,
        SpendingPeriod.month => PeriodKind.month,
        SpendingPeriod.sixMonths => PeriodKind.sixMonths,
        SpendingPeriod.year => PeriodKind.year,
      };

  String _monthKey(LocalDate date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';
}
