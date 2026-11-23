// P23 (SPEC 4.2, 4.10, 6.3, 8.16; flow F05; SCREENS X26): the transfer form
// contract.
//
// The feature talks to one port. The app composition supplies the SQL
// implementation over the transfer repository and the single command writer;
// tests supply an in-memory port. No widget reads the database (AGENTS 6.2).
//
// The principal is neither spending nor income (F05-A). X26 has no fee field in
// Phase 2: a charged fee enters from a captured or imported record
// (DECISIONS CLOSED-G13-TRANSFER-FEES). Cross-currency is X26b and stays v1.1.
library;

import '../../core/dates.dart';
import '../accounts/account_models.dart';

/// F05 step 1: one validated transfer between two owned accounts.
final class TransferSetup {
  const TransferSetup({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountMinor,
    required this.currencyCode,
    required this.date,
    this.note,
  });

  final String fromAccountId;
  final String toAccountId;

  /// The principal, positive. The sending posting stores it negative.
  final int amountMinor;
  final String currencyCode;
  final LocalDate date;
  final String? note;
}

/// The confirmed result of one Save transfer. It carries no personal text.
final class SavedTransfer {
  const SavedTransfer({
    required this.eventId,
    required this.sendingId,
    required this.receivingId,
    required this.operationId,
    required this.amountMinor,
    required this.currencyCode,
    required this.date,
  });

  final String eventId;
  final String sendingId;
  final String receivingId;
  final String operationId;
  final int amountMinor;
  final String currencyCode;
  final LocalDate date;
}

/// The data the form needs before the first entry (X26).
final class TransferFormData {
  const TransferFormData({
    required this.accounts,
    required this.currencyCode,
  });

  final List<AccountSummary> accounts;

  /// The default currency: the first account's, then USD.
  final String currencyCode;
}

/// The transfer data port. One call is one commit boundary group.
abstract interface class TransferGateway {
  /// The owned accounts and the default currency.
  Future<TransferFormData> loadForm();

  /// `SaveTransfer` for one validated transfer.
  ///
  /// [draftId] and [payloadJson] name the stored draft and its frozen payload
  /// (SPEC 8.16). A repeated Save returns the recorded result.
  Future<SavedTransfer> saveTransfer({
    required TransferSetup setup,
    String? draftId,
    String? payloadJson,
  });

  /// SPEC 8.18: one compensating command for one confirmed transfer.
  Future<void> undoTransfer(SavedTransfer saved);
}

/// Typed, safe failure codes (no amount, account or id in the text).
enum TransferErrorCode {
  /// The app composition has not mounted a gateway (vault closed or unwired).
  notWired,

  /// The form values failed validation; nothing is written.
  invalidTransfer,

  /// The write failed or the receipt could not be read.
  saveFailed,

  /// The compensating command failed; the record stays.
  undoFailed,
}

class TransferFormError implements Exception {
  const TransferFormError(this.code);

  final TransferErrorCode code;

  @override
  String toString() => 'TransferFormError(${code.name})';
}

/// The placeholder gateway before the app composition mounts the vault.
final class UnavailableTransferGateway implements TransferGateway {
  const UnavailableTransferGateway();

  @override
  Future<TransferFormData> loadForm() async =>
      throw const TransferFormError(TransferErrorCode.notWired);

  @override
  Future<SavedTransfer> saveTransfer({
    required TransferSetup setup,
    String? draftId,
    String? payloadJson,
  }) async =>
      throw const TransferFormError(TransferErrorCode.notWired);

  @override
  Future<void> undoTransfer(SavedTransfer saved) async =>
      throw const TransferFormError(TransferErrorCode.notWired);
}
