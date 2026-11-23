// P27 (flow F08 steps 2–4; SPEC 4.4, 4.11, 8.18): the app composition for the
// payment list, detail and category detail.
//
// Reads come from the P27 payment and category reads; the two writes are
// `DeletePayment` (a soft delete) and its restore. Money is never formatted
// here (AGENTS 6.4).
library;

import 'package:decimal/decimal.dart';

import '../core/dates.dart';
import '../data/db/command_repository.dart';
import '../data/projections/category_read.dart';
import '../data/repositories/accounts.dart';
import '../data/repositories/budgets.dart';
import '../data/repositories/categories.dart';
import '../data/repositories/payments.dart';
import '../data/repositories/payments_read.dart';
import '../domain/periods/budget_month.dart';
import '../domain/periods/period_math.dart';
import '../features/spending/payments_models.dart';

/// P12 + P27 + P15 behind the payment feature port.
final class SqlPaymentsReadGateway implements PaymentsReadGateway {
  SqlPaymentsReadGateway({
    required this.payments,
    required this.paymentReads,
    required this.categoryReads,
    required this.budgets,
    required this.accounts,
    required this.categories,
    required this.commands,
    required this.today,
    required this.newOperationId,
    this.currencyCode = 'USD',
    this.startDay = 1,
  });

  final PaymentRepository payments;
  final PaymentReadRepository paymentReads;
  final CategoryReadRepository categoryReads;
  final BudgetRepository budgets;
  final AccountRepository accounts;
  final CategoryRepository categories;
  final CommandRepository commands;
  final LocalDate Function() today;
  final String Function() newOperationId;
  final String currencyCode;
  final int startDay;

  @override
  Future<PaymentListPage> loadPayments(PaymentFilter filter) async {
    final range = _range(filter.period);
    final query = PaymentQuery(
      from: range.start.toString(),
      to: range.end.toString(),
      show: _show(filter.show),
      accountId: filter.accountId,
      categoryId: filter.categoryId,
    );
    final rows = await paymentReads.list(query);
    final count = await paymentReads.count(query);
    return PaymentListPage(
      items: <PaymentListItem>[
        for (final row in rows)
          PaymentListItem(
            id: row.id,
            date: LocalDate.tryParse(row.date) ?? today(),
            amountMinor: row.amountMinor,
            currencyCode: row.currency,
            kind: row.kind,
            revision: row.revision,
            merchantName: row.merchantName,
            categoryName: row.categoryName,
            accountName: row.accountName,
          ),
      ],
      count: count,
      filter: filter,
      rangeStart: range.start,
      rangeEnd: range.end,
    );
  }

  @override
  Future<int> countPayments(PaymentFilter filter) async {
    final range = _range(filter.period);
    return paymentReads.count(
      PaymentQuery(
        from: range.start.toString(),
        to: range.end.toString(),
        show: _show(filter.show),
        accountId: filter.accountId,
        categoryId: filter.categoryId,
      ),
    );
  }

  @override
  Future<({List<FilterOption> accounts, List<FilterOption> categories})>
      filterOptions() async {
    final accountRows = await accounts.list();
    final categoryRows = <CategoryRow>[
      ...await categories.list(kind: 'expense'),
      ...await categories.list(kind: 'income'),
    ];
    return (
      accounts: <FilterOption>[
        for (final row in accountRows) FilterOption(id: row.id, name: row.name),
      ],
      categories: <FilterOption>[
        for (final row in categoryRows)
          FilterOption(id: row.id, name: row.name),
      ],
    );
  }

  @override
  Future<PaymentDetailView?> loadPayment(String id) async {
    final row = await paymentReads.detail(id);
    if (row == null) {
      return null;
    }
    return PaymentDetailView(
      id: row.id,
      date: LocalDate.tryParse(row.date) ?? today(),
      amountMinor: row.amountMinor,
      currencyCode: row.currency,
      kind: row.kind,
      revision: row.revision,
      accountName: row.accountName,
      merchantName: row.merchantName,
      note: row.note,
      categoryName: row.categoryName,
      splits: <PaymentSplitView>[
        for (final split in row.splits)
          PaymentSplitView(
            categoryName: split.categoryName ?? '',
            amountMinor: split.amountMinor,
          ),
      ],
      tags: row.tags,
    );
  }

  @override
  Future<CategoryDetailView> loadCategory(
    String categoryId, {
    PaymentPeriod period = PaymentPeriod.thisMonth,
  }) async {
    final range = _range(period);
    final series = await categoryReads.months(
      categoryId: categoryId,
      from: '${today().year}-01-01',
      to: today().toString(),
    );
    final periodMonths = await categoryReads.months(
      categoryId: categoryId,
      from: range.start.toString(),
      to: range.end.toString(),
    );
    var spent = 0;
    for (final month in periodMonths) {
      spent += month.amountMinor;
    }
    final complete = await categoryReads.months(
      categoryId: categoryId,
      from:
          addMonths(LocalDate(today().year, today().month, 1), -12).toString(),
      to: addDays(LocalDate(today().year, today().month, 1), -1).toString(),
    );
    final average = complete.isEmpty
        ? null
        : complete.fold<int>(0, (sum, row) => sum + row.amountMinor) ~/
            complete.length;
    final month = BudgetMonth.containing(today(), startDay: startDay);
    final key = '${month.start.year.toString().padLeft(4, '0')}-'
        '${month.start.month.toString().padLeft(2, '0')}';
    final limits = await budgets.limitsFor(key);
    int? limit;
    if (limits != null) {
      for (final row in limits.limits) {
        if (row.categoryId == categoryId) {
          limit = row.limitMinor;
        }
      }
    }
    final merchants = await categoryReads.merchants(
      categoryId: categoryId,
      from: range.start.toString(),
      to: range.end.toString(),
    );
    final paymentRows = await paymentReads.list(
      PaymentQuery(
        from: range.start.toString(),
        to: range.end.toString(),
        categoryId: categoryId,
      ),
    );
    final name = await categoryReads.name(categoryId);
    return CategoryDetailView(
      id: categoryId,
      name: name,
      currencyCode: currencyCode,
      rangeStart: range.start,
      rangeEnd: range.end,
      spentMinor: periodMonths.isEmpty ? null : spent.abs(),
      limitMinor: limit,
      averageMinor: average?.abs(),
      monthGonePercent:
          month.monthGone(shareOfToday: Decimal.one).value.toDouble().round(),
      months: <CategoryMonthPoint>[
        for (final row in series)
          CategoryMonthPoint(
            month: LocalDate.parse('${row.month}-01'),
            amountMinor: row.amountMinor.abs(),
          ),
      ],
      merchants: <MerchantShare>[
        for (final row in merchants)
          MerchantShare(
            name: row.merchantName,
            amountMinor: row.amountMinor.abs(),
          ),
      ],
      payments: <PaymentListItem>[
        for (final row in paymentRows)
          PaymentListItem(
            id: row.id,
            date: LocalDate.tryParse(row.date) ?? today(),
            amountMinor: row.amountMinor,
            currencyCode: row.currency,
            kind: row.kind,
            revision: row.revision,
            merchantName: row.merchantName,
            categoryName: row.categoryName,
            accountName: row.accountName,
          ),
      ],
    );
  }

  @override
  Future<DeletedPayment> deletePayment(PaymentDetailView payment) async {
    final plan = await payments.planUndoCreate(paymentId: payment.id);
    final operationId = newOperationId();
    await commands.prepare(
      operationId: operationId,
      commandType: 'payment.delete',
      draftId: newOperationId(),
      formType: 'paymentDelete',
      payloadJson: '{"payment":"${payment.id}"}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    try {
      await commands.execute(
        operationId: operationId,
        changes: plan.changes,
        effects: plan.apply,
        resultJson: '{"payment":"${payment.id}"}',
      );
    } on Object {
      final receipt = await commands.receiptOf(operationId);
      if (receipt == null) {
        throw const PaymentsReadError(PaymentsReadErrorCode.deleteFailed);
      }
    }
    return DeletedPayment(
      paymentId: payment.id,
      operationId: operationId,
    );
  }

  @override
  Future<void> restorePayment(DeletedPayment deleted) async {
    final plan = await payments.planRestore(paymentId: deleted.paymentId);
    final operationId = newOperationId();
    await commands.prepare(
      operationId: operationId,
      commandType: 'payment.restore',
      draftId: newOperationId(),
      formType: 'paymentRestore',
      payloadJson: '{"undoOf":"${deleted.operationId}"}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    try {
      await commands.execute(
        operationId: operationId,
        changes: plan.changes,
        effects: plan.apply,
        resultJson: '{}',
      );
    } on Object {
      final receipt = await commands.receiptOf(operationId);
      if (receipt == null) {
        throw const PaymentsReadError(PaymentsReadErrorCode.restoreFailed);
      }
    }
  }

  ({LocalDate start, LocalDate end}) _range(PaymentPeriod period) {
    final month = BudgetMonth.containing(today(), startDay: startDay);
    return switch (period) {
      PaymentPeriod.thisMonth => (start: month.start, end: today()),
      PaymentPeriod.lastMonth => (
          start: addMonths(month.start, -1),
          end: addDays(month.start, -1),
        ),
      PaymentPeriod.thisYear => (
          start: LocalDate(today().year, 1, 1),
          end: today(),
        ),
    };
  }

  PaymentShow _show(PaymentShowFilter show) => switch (show) {
        PaymentShowFilter.moneyOut => PaymentShow.moneyOut,
        PaymentShowFilter.moneyIn => PaymentShow.moneyIn,
        PaymentShowFilter.transfers => PaymentShow.transfers,
        PaymentShowFilter.noCategory => PaymentShow.noCategory,
      };
}
