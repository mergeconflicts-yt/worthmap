// P23 / SPEC 8.16: the X26 transfer draft contract.
//
// The draft holds the structured form fields only: amount text, currency, date
// and the two account ids. It never holds an amount in a log or an operation
// id. The codec is pure and versioned; an unreadable or older payload is
// reported as unsupported, never silently re-read (P01).
library;

import '../../core/dates.dart';

/// One X26 draft payload (SPEC 8.16 field table).
final class TransferFormDraft {
  const TransferFormDraft({
    required this.amountText,
    required this.currencyCode,
    required this.date,
    required this.fromAccountId,
    required this.toAccountId,
  });

  final String amountText;
  final String currencyCode;
  final LocalDate date;
  final String? fromAccountId;
  final String? toAccountId;
}

/// The result of reading a stored transfer draft.
sealed class TransferDraftLoad {
  const TransferDraftLoad();
}

/// A readable draft of the current schema.
final class LoadedTransferDraft extends TransferDraftLoad {
  const LoadedTransferDraft({required this.id, required this.draft});

  final String id;
  final TransferFormDraft draft;
}

/// No draft is stored.
final class NoTransferDraft extends TransferDraftLoad {
  const NoTransferDraft();
}

/// A draft exists but its payload is from an older schema or unreadable.
final class UnsupportedTransferDraft extends TransferDraftLoad {
  const UnsupportedTransferDraft();
}

/// The draft store port. The app composition supplies a `DraftRepository`
/// adapter; tests supply a memory store.
abstract interface class TransferDraftStore {
  Future<TransferDraftLoad> load();

  /// Writes the draft and returns its identity (P13 draft id).
  Future<String> save(TransferFormDraft draft);

  Future<void> discard();
}

/// A store with no backing database. It keeps nothing and reports no draft.
final class NoTransferDraftStore implements TransferDraftStore {
  const NoTransferDraftStore();

  @override
  Future<TransferDraftLoad> load() async => const NoTransferDraft();

  @override
  Future<String> save(TransferFormDraft draft) async => '';

  @override
  Future<void> discard() async {}
}

/// A memory store for tests and a preview.
final class MemoryTransferDraftStore implements TransferDraftStore {
  MemoryTransferDraftStore({this.id = 'transfer-draft-memory', this.draft});

  String id;
  TransferFormDraft? draft;

  @override
  Future<TransferDraftLoad> load() async => draft == null
      ? const NoTransferDraft()
      : LoadedTransferDraft(id: id, draft: draft!);

  @override
  Future<String> save(TransferFormDraft value) async {
    draft = value;
    return id;
  }

  @override
  Future<void> discard() async => draft = null;
}

/// JSON keys of the X26 draft. The schema version is the first check.
abstract final class TransferDraftJson {
  const TransferDraftJson._();

  static const int schemaVersion = 1;

  static Map<String, Object?> encode(TransferFormDraft draft) =>
      <String, Object?>{
        'schema': schemaVersion,
        'amount': draft.amountText,
        'currency': draft.currencyCode,
        'date': draft.date.toString(),
        'from': draft.fromAccountId,
        'to': draft.toAccountId,
      };

  /// Returns null for any payload that is not exactly this schema.
  static TransferFormDraft? decode(Map<String, Object?> json) {
    if (json['schema'] != schemaVersion) {
      return null;
    }
    final amount = json['amount'];
    final currency = json['currency'];
    final dateText = json['date'];
    final from = json['from'];
    final to = json['to'];
    if (amount is! String || currency is! String || dateText is! String) {
      return null;
    }
    if (from != null && from is! String) {
      return null;
    }
    if (to != null && to is! String) {
      return null;
    }
    final date = LocalDate.tryParse(dateText);
    if (date == null || currency.isEmpty) {
      return null;
    }
    return TransferFormDraft(
      amountText: amount,
      currencyCode: currency,
      date: date,
      fromAccountId: from as String?,
      toAccountId: to as String?,
    );
  }
}
