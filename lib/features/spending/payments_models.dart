// P27 (SCREENS X36–X39b; flow F08 steps 2–4): the payment list, detail and
// category detail contract.
//
// The filter is a draft until X38 "Show" returns it (F08-A). Delete is one
// command; Undo is its compensating restore (F08-C). No widget reads the
// database (AGENTS 6.2).
library;

import '../../core/dates.dart';

/// X38 "Period".
enum PaymentPeriod { thisMonth, lastMonth, thisYear }

/// X38 "Show".
enum PaymentShowFilter { moneyOut, moneyIn, transfers, noCategory }

/// The X38 draft. The list uses only a returned filter.
final class PaymentFilter {
  const PaymentFilter({
    required this.period,
    required this.show,
    this.accountId,
    this.categoryId,
  });

  final PaymentPeriod period;
  final PaymentShowFilter show;
  final String? accountId;
  final String? categoryId;

  PaymentFilter copyWith({
    PaymentPeriod? period,
    PaymentShowFilter? show,
    String? accountId,
    String? categoryId,
    bool clearAccount = false,
    bool clearCategory = false,
  }) =>
      PaymentFilter(
        period: period ?? this.period,
        show: show ?? this.show,
        accountId: clearAccount ? null : (accountId ?? this.accountId),
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      );
}

/// One row of X37.
final class PaymentListItem {
  const PaymentListItem({
    required this.id,
    required this.date,
    required this.amountMinor,
    required this.currencyCode,
    required this.kind,
    required this.revision,
    this.merchantName,
    this.categoryName,
    required this.accountName,
  });

  final String id;
  final LocalDate date;
  final int amountMinor;
  final String currencyCode;
  final String kind;
  final int revision;
  final String? merchantName;
  final String? categoryName;
  final String accountName;
}

/// The applied page with its exact count and the filter it used.
final class PaymentListPage {
  const PaymentListPage({
    required this.items,
    required this.count,
    required this.filter,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final List<PaymentListItem> items;
  final int count;
  final PaymentFilter filter;
  final LocalDate rangeStart;
  final LocalDate rangeEnd;
}

/// One split of X39.
final class PaymentSplitView {
  const PaymentSplitView({
    required this.categoryName,
    required this.amountMinor,
  });

  final String categoryName;
  final int amountMinor;
}

/// X39: one payment.
final class PaymentDetailView {
  const PaymentDetailView({
    required this.id,
    required this.date,
    required this.amountMinor,
    required this.currencyCode,
    required this.kind,
    required this.revision,
    required this.accountName,
    this.merchantName,
    this.note,
    this.categoryName,
    this.splits = const <PaymentSplitView>[],
    this.tags = const <String>[],
  });

  final String id;
  final LocalDate date;
  final int amountMinor;
  final String currencyCode;
  final String kind;
  final int revision;
  final String accountName;
  final String? merchantName;
  final String? note;
  final String? categoryName;
  final List<PaymentSplitView> splits;
  final List<String> tags;
}

/// One month column of X36.
final class CategoryMonthPoint {
  const CategoryMonthPoint({required this.month, required this.amountMinor});

  /// The first day of the month.
  final LocalDate month;
  final int amountMinor;
}

/// One merchant share of X36 "Where".
final class MerchantShare {
  const MerchantShare({
    required this.name,
    required this.amountMinor,
  });

  /// Null for rows with no merchant text.
  final String? name;
  final int amountMinor;
}

/// X36: one category and its numbers.
final class CategoryDetailView {
  const CategoryDetailView({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.rangeStart,
    required this.rangeEnd,
    required this.spentMinor,
    required this.limitMinor,
    required this.averageMinor,
    required this.monthGonePercent,
    required this.months,
    required this.merchants,
    required this.payments,
  });

  final String id;
  final String name;
  final String currencyCode;
  final LocalDate rangeStart;
  final LocalDate rangeEnd;

  /// Net money out in the period. Null when no row is recorded.
  final int? spentMinor;

  /// Null when the category has no limit.
  final int? limitMinor;

  /// The 12-month average of the complete months. Null when none is recorded.
  final int? averageMinor;

  /// Today's share of the budget month.
  final int monthGonePercent;
  final List<CategoryMonthPoint> months;
  final List<MerchantShare> merchants;
  final List<PaymentListItem> payments;
}

/// One account or category choice in X38.
final class FilterOption {
  const FilterOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// The committed delete, used by the 5 s Undo.
final class DeletedPayment {
  const DeletedPayment({
    required this.paymentId,
    required this.operationId,
  });

  final String paymentId;
  final String operationId;
}

/// The payment reads and the two compensating commands.
abstract interface class PaymentsReadGateway {
  /// X37 with the applied filter.
  Future<PaymentListPage> loadPayments(PaymentFilter filter);

  /// The exact count of one draft filter, for the X38 "Show" label.
  Future<int> countPayments(PaymentFilter filter);

  /// The accounts and categories of X38.
  Future<({List<FilterOption> accounts, List<FilterOption> categories})>
      filterOptions();

  /// X39: one payment, or null when it is gone.
  Future<PaymentDetailView?> loadPayment(String id);

  /// X36.
  Future<CategoryDetailView> loadCategory(
    String categoryId, {
    PaymentPeriod period = PaymentPeriod.thisMonth,
  });

  /// `DeletePayment`. Returns the committed delete for Undo.
  Future<DeletedPayment> deletePayment(PaymentDetailView payment);

  /// The compensating restore of one delete (F08-C).
  Future<void> restorePayment(DeletedPayment deleted);
}

/// Safe failure codes (no amount, merchant or id in the text).
enum PaymentsReadErrorCode {
  notWired,
  loadFailed,
  deleteFailed,
  restoreFailed,
}

class PaymentsReadError implements Exception {
  const PaymentsReadError(this.code);

  final PaymentsReadErrorCode code;

  @override
  String toString() => 'PaymentsReadError(${code.name})';
}

/// The placeholder gateway before the app composition mounts the vault.
final class UnavailablePaymentsReadGateway implements PaymentsReadGateway {
  const UnavailablePaymentsReadGateway();

  @override
  Future<PaymentListPage> loadPayments(PaymentFilter filter) async =>
      throw const PaymentsReadError(PaymentsReadErrorCode.notWired);

  @override
  Future<int> countPayments(PaymentFilter filter) async =>
      throw const PaymentsReadError(PaymentsReadErrorCode.notWired);

  @override
  Future<({List<FilterOption> accounts, List<FilterOption> categories})>
      filterOptions() async =>
          throw const PaymentsReadError(PaymentsReadErrorCode.notWired);

  @override
  Future<PaymentDetailView?> loadPayment(String id) async =>
      throw const PaymentsReadError(PaymentsReadErrorCode.notWired);

  @override
  Future<CategoryDetailView> loadCategory(
    String categoryId, {
    PaymentPeriod period = PaymentPeriod.thisMonth,
  }) async =>
      throw const PaymentsReadError(PaymentsReadErrorCode.notWired);

  @override
  Future<DeletedPayment> deletePayment(PaymentDetailView payment) async =>
      throw const PaymentsReadError(PaymentsReadErrorCode.notWired);

  @override
  Future<void> restorePayment(DeletedPayment deleted) async =>
      throw const PaymentsReadError(PaymentsReadErrorCode.notWired);
}
