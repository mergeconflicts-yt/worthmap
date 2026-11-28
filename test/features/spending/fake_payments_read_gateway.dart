import 'package:contour/core/dates.dart';
import 'package:contour/domain/periods/period_math.dart';
import 'package:contour/features/spending/payments_models.dart';

/// In-memory payment reads for the P27 tests. It writes no database.
final class FakePaymentsReadGateway implements PaymentsReadGateway {
  /// The default local date of the synthetic rows.
  ///
  /// It is fixed, not the wall clock: tests and goldens must not change with
  /// the day they run. A test that needs another date passes one.
  static final LocalDate defaultToday = LocalDate(2026, 11, 24);

  FakePaymentsReadGateway({LocalDate? today}) : _today = today ?? defaultToday {
    items = <PaymentListItem>[
      PaymentListItem(
        id: 'p1',
        date: _today,
        amountMinor: -640,
        currencyCode: 'USD',
        kind: 'expense',
        revision: 1,
        merchantName: 'Starbucks',
        categoryName: 'Coffee',
        accountName: 'Visa card',
      ),
      PaymentListItem(
        id: 'p2',
        date: _today,
        amountMinor: -1500,
        currencyCode: 'USD',
        kind: 'expense',
        revision: 1,
        merchantName: 'PX Market',
        categoryName: 'Groceries',
        accountName: 'Checking',
      ),
      PaymentListItem(
        id: 'p3',
        date: _yesterday,
        amountMinor: -12130,
        currencyCode: 'USD',
        kind: 'expense',
        revision: 2,
        merchantName: 'Whole Foods',
        categoryName: 'Groceries',
        accountName: 'Visa card',
      ),
      PaymentListItem(
        id: 'p4',
        date: _before,
        amountMinor: -3175,
        currencyCode: 'USD',
        kind: 'expense',
        revision: 1,
        merchantName: 'PX Market',
        categoryName: 'Groceries',
        accountName: 'Checking',
      ),
    ];
  }

  final LocalDate _today;
  late final LocalDate _yesterday = addDays(_today, -1);
  late final LocalDate _before = addDays(_today, -2);
  late List<PaymentListItem> items;

  final List<PaymentFilter> counted = <PaymentFilter>[];
  final List<String> deleted = <String>[];
  final List<String> restored = <String>[];
  Object? loadFailure;
  Object? deleteFailure;
  Object? restoreFailure;

  @override
  Future<PaymentListPage> loadPayments(PaymentFilter filter) async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    final matching = _matching(filter);
    return PaymentListPage(
      items: matching,
      count: matching.length,
      filter: filter,
      rangeStart: _today,
      rangeEnd: _today,
    );
  }

  @override
  Future<int> countPayments(PaymentFilter filter) async {
    counted.add(filter);
    return _matching(filter).length;
  }

  @override
  Future<({List<FilterOption> accounts, List<FilterOption> categories})>
      filterOptions() async => (
            accounts: const <FilterOption>[
              FilterOption(id: 'account-checking', name: 'Checking'),
              FilterOption(id: 'account-card', name: 'Visa card'),
            ],
            categories: const <FilterOption>[
              FilterOption(id: 'cat-coffee', name: 'Coffee'),
              FilterOption(id: 'cat-groceries', name: 'Groceries'),
            ],
          );

  @override
  Future<PaymentDetailView?> loadPayment(String id) async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    final item = items.firstWhere(
      (row) => row.id == id,
      orElse: () => items.first,
    );
    return PaymentDetailView(
      id: item.id,
      date: item.date,
      amountMinor: item.amountMinor,
      currencyCode: item.currencyCode,
      kind: item.kind,
      revision: item.revision,
      accountName: item.accountName,
      merchantName: item.merchantName,
      note: item.id == 'p3' ? 'Weekly shop' : null,
      categoryName: item.categoryName,
      splits: item.id == 'p3'
          ? const <PaymentSplitView>[
              PaymentSplitView(categoryName: 'Groceries', amountMinor: -8412),
              PaymentSplitView(categoryName: 'Household', amountMinor: -2500),
              PaymentSplitView(categoryName: 'Gifts', amountMinor: -1218),
            ]
          : const <PaymentSplitView>[],
      tags: item.id == 'p3' ? const <String>['Household'] : const <String>[],
    );
  }

  @override
  Future<CategoryDetailView> loadCategory(
    String categoryId, {
    PaymentPeriod period = PaymentPeriod.thisMonth,
  }) async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    final months = <CategoryMonthPoint>[
      for (var index = 9; index >= 0; index -= 1)
        CategoryMonthPoint(
          month: addMonths(LocalDate(_today.year, _today.month, 1), -index),
          amountMinor: 62000,
        ),
    ];
    return CategoryDetailView(
      id: categoryId,
      name: 'Groceries',
      currencyCode: 'USD',
      rangeStart: LocalDate(_today.year, _today.month, 1),
      rangeEnd: _today,
      spentMinor: 62000,
      limitMinor: 120000,
      averageMinor: 70000,
      monthGonePercent: 72,
      months: months,
      merchants: const <MerchantShare>[
        MerchantShare(name: 'Whole Foods', amountMinor: 32240),
        MerchantShare(name: 'PX Market', amountMinor: 17360),
        MerchantShare(name: 'Others', amountMinor: 12400),
      ],
      payments: items,
    );
  }

  @override
  Future<DeletedPayment> deletePayment(PaymentDetailView payment) async {
    final failure = deleteFailure;
    if (failure != null) {
      throw failure;
    }
    deleted.add(payment.id);
    items = <PaymentListItem>[
      for (final item in items)
        if (item.id != payment.id) item,
    ];
    return DeletedPayment(
      paymentId: payment.id,
      operationId: 'operation-delete',
    );
  }

  @override
  Future<void> restorePayment(DeletedPayment deletedPayment) async {
    final failure = restoreFailure;
    if (failure != null) {
      throw failure;
    }
    restored.add(deletedPayment.paymentId);
  }

  List<PaymentListItem> _matching(PaymentFilter filter) => <PaymentListItem>[
        for (final item in items)
          if (filter.accountId == null ||
              item.accountName == _accountName(filter.accountId!))
            if (filter.categoryId == null ||
                item.categoryName == _categoryName(filter.categoryId!))
              item,
      ];

  String _accountName(String id) =>
      id == 'account-checking' ? 'Checking' : 'Visa card';

  String _categoryName(String id) =>
      id == 'cat-coffee' ? 'Coffee' : 'Groceries';
}
