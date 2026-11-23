// P22 (SPEC 3.1, 3.2, 8.3, 8.16, 9.3; flow F03; SCREENS X20–X23): the
// payment form contract.
//
// The feature talks to one port. The app composition supplies the SQL
// implementation over the P12 payment repository, the P13 draft store and the
// single command writer; tests supply an in-memory or fake port. No widget
// reads the database (AGENTS 6.2).
//
// Money stays integer minor units (SPEC 4.1). A draft carries no identity of a
// stored record beyond the optional edit target (SPEC 8.16).
library;

import '../../core/dates.dart';
import '../accounts/account_models.dart';

/// SPEC 8.3: the payment type of X20. Transfer is X26 (P23).
enum PaymentKind {
  expense,
  income;

  /// The authored `transactions.kind` value.
  String get databaseType => switch (this) {
        PaymentKind.expense => 'expense',
        PaymentKind.income => 'income',
      };

  bool get isIncome => this == PaymentKind.income;
}

/// X21, X23: one selectable category.
final class CategorySummary {
  const CategorySummary({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

/// X22: one selectable tag.
final class TagSummary {
  const TagSummary({required this.id, required this.name});

  final String id;
  final String name;
}

/// X23: one part of a split, in minor units of the payment currency.
final class PaymentSplitSetup {
  const PaymentSplitSetup({
    required this.categoryId,
    required this.amountMinor,
  });

  final String categoryId;

  /// The signed part. Its sign matches the parent payment.
  final int amountMinor;
}

/// F03 step 1: the record an edit changes. A create has none.
final class PaymentEdit {
  const PaymentEdit({
    required this.paymentId,
    required this.eventId,
    required this.expectedRevision,
  });

  final String paymentId;
  final String eventId;

  /// DATABASE_DESIGN 4.1: the revision the form read.
  final int expectedRevision;
}

/// F03 step 5: one validated payment, frozen for Save.
final class PaymentSetup {
  const PaymentSetup({
    required this.kind,
    required this.amountMinor,
    required this.currencyCode,
    required this.date,
    required this.accountId,
    required this.merchantName,
    required this.tagIds,
    required this.splits,
    this.categoryId,
    this.note,
    this.edit,
  });

  final PaymentKind kind;

  /// The signed amount: an expense is negative, income positive (P09).
  final int amountMinor;
  final String currencyCode;
  final LocalDate date;
  final String accountId;

  /// The trimmed merchant text; empty becomes null.
  final String? merchantName;
  final String? note;

  /// An uncategorised payment saves (F03-A).
  final String? categoryId;
  final List<String> tagIds;

  /// Empty for a plain payment. A split is saved only at a zero remainder.
  final List<PaymentSplitSetup> splits;

  final PaymentEdit? edit;
}

/// The confirmed result of one Save. It carries no personal text.
final class SavedPayment {
  const SavedPayment({
    required this.paymentId,
    required this.eventId,
    required this.operationId,
    required this.amountMinor,
    required this.currencyCode,
    required this.kind,
    required this.date,
    this.edit = false,
  });

  final String paymentId;
  final String eventId;
  final String operationId;
  final int amountMinor;
  final String currencyCode;
  final PaymentKind kind;
  final LocalDate date;

  /// True when this Save changed an existing payment instead of adding one.
  final bool edit;
}

/// The data the form needs before the first entry (X20, X21, X22).
final class PaymentFormData {
  const PaymentFormData({
    required this.accounts,
    required this.categories,
    required this.tags,
    required this.lastCurrencyCode,
  });

  final List<AccountSummary> accounts;
  final List<CategorySummary> categories;
  final List<TagSummary> tags;

  /// SPEC 3.2: currency is the last one used.
  final String lastCurrencyCode;
}

/// The payment data port. One call is one commit boundary group.
abstract interface class PaymentsGateway {
  /// Accounts, the categories of [kind], tags and the last currency used.
  Future<PaymentFormData> loadForm({required PaymentKind kind});

  /// `SavePayment` for one validated payment.
  ///
  /// [draftId] and [payloadJson] name the stored draft and its frozen
  /// canonical payload (SPEC 8.16). A repeated Save of the same draft returns
  /// the recorded result. A null [draftId] is a save with no resume path.
  Future<SavedPayment> savePayment({
    required PaymentSetup setup,
    String? draftId,
    String? payloadJson,
  });

  /// SPEC 8.18: one compensating command for one confirmed creation.
  Future<void> undoPayment(SavedPayment saved);
}

/// Typed, safe failure codes (no amount, merchant or id in the text).
enum PaymentsErrorCode {
  /// The app composition has not mounted a gateway (vault closed or unwired).
  notWired,

  /// The form values failed validation; nothing is written.
  invalidPayment,

  /// The write failed or the receipt could not be read.
  saveFailed,

  /// The compensating command failed; the record stays.
  undoFailed,
}

class PaymentsError implements Exception {
  const PaymentsError(this.code);

  final PaymentsErrorCode code;

  @override
  String toString() => 'PaymentsError(${code.name})';
}

/// The placeholder gateway before the app composition mounts the vault.
final class UnavailablePaymentsGateway implements PaymentsGateway {
  const UnavailablePaymentsGateway();

  @override
  Future<PaymentFormData> loadForm({required PaymentKind kind}) async =>
      throw const PaymentsError(PaymentsErrorCode.notWired);

  @override
  Future<SavedPayment> savePayment({
    required PaymentSetup setup,
    String? draftId,
    String? payloadJson,
  }) async =>
      throw const PaymentsError(PaymentsErrorCode.notWired);

  @override
  Future<void> undoPayment(SavedPayment saved) async =>
      throw const PaymentsError(PaymentsErrorCode.notWired);
}
