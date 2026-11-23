// P25 (SCREENS X60–X62; flow F07; SPEC 5.5, 8.18): the Inbox feature contract.
//
// The feature reads staged items, ticks ready rows, stages match decisions and
// confirms once. It never writes a payment outside `ConfirmInboxBatch`. The
// confirm label reads the exact count and totals from the gateway, never a
// client sum (F07-B).
//
// Phase 2 has no producer for staged items (DECISIONS P2-INBOX-PRODUCER): the
// screens are complete and the empty state is the normal state until imports
// arrive in Phase 3.
library;

import '../../core/dates.dart';

/// One pending row for the list (X60) and the item sheet (X61).
final class InboxRow {
  const InboxRow({
    required this.id,
    required this.title,
    required this.source,
    required this.date,
    required this.amountMinor,
    required this.currencyCode,
    required this.editRevision,
    required this.suggestion,
    this.categoryName,
    this.accountName,
    this.matchName,
    this.isUnsure = false,
  });

  final int id;

  /// The merchant, or a neutral payment label.
  final String title;

  /// The source channel token from the source identity.
  final String source;
  final LocalDate date;
  final int amountMinor;
  final String currencyCode;
  final int editRevision;

  /// The staged suggestion (`new`, `merge`, `transfer`, `refund`, ...).
  final String suggestion;
  final String? categoryName;
  final String? accountName;

  /// The counterpart account name of a transfer candidate.
  final String? matchName;

  /// True when the category or the account needs a check.
  final bool isUnsure;

  /// A transfer candidate asks one question before it can be ticked.
  bool get needsDecision => suggestion == 'transfer';
}

/// The open decision card (X60 step 3).
///
/// The feature formats the two amounts; the data layer never formats money.
final class InboxDecision {
  const InboxDecision({
    required this.itemId,
    required this.editRevision,
    required this.fromName,
    required this.toName,
    required this.amountMinor,
    required this.currencyCode,
    required this.date,
  });

  final int itemId;
  final int editRevision;
  final String fromName;
  final String toName;
  final int amountMinor;
  final String currencyCode;
  final LocalDate date;
}

/// The exact ticked count and totals from the gateway (F07-B).
final class InboxTotals {
  const InboxTotals({
    required this.count,
    required this.netMinor,
    required this.currencyCode,
  });

  final int count;
  final int netMinor;
  final String currencyCode;
}

/// One loaded page.
final class InboxPageView {
  const InboxPageView({
    required this.rows,
    required this.pendingCount,
    this.nextCursor,
    this.decision,
  });

  final List<InboxRow> rows;

  /// Every pending and visible item, not only this page.
  final int pendingCount;

  /// An opaque cursor for the next page, or null at the end.
  final String? nextCursor;
  final InboxDecision? decision;
}

/// The committed result of `ConfirmInboxBatch` (no personal text).
final class InboxConfirmation {
  const InboxConfirmation({
    required this.operationId,
    required this.batchId,
    required this.count,
    required this.currencyCode,
    required this.netMinor,
  });

  /// The confirm operation, used by the whole-batch Undo.
  final String operationId;
  final String batchId;
  final int count;
  final String currencyCode;
  final int netMinor;
}

/// The Inbox data port. One call is one read or one commit boundary group.
abstract interface class InboxGateway {
  /// The pending page. [cursor] is opaque to the feature.
  Future<InboxPageView> loadPage({String? cursor});

  /// F07-B: the exact count and totals for the ticked ids.
  Future<InboxTotals> totals(Set<int> ids);

  /// Stages a match decision. It writes no ledger record (SPEC 8.17).
  Future<void> decide({
    required int itemId,
    required int expectedRevision,
    required bool accept,
  });

  /// `ConfirmInboxBatch` for the ticked ids. All or none (F07-C).
  Future<InboxConfirmation> confirm(Set<int> ids);

  /// SPEC 8.18: one compensating command for the whole confirmed batch.
  Future<void> undoBatch(String batchId);

  /// Deletes one staged item only; no payment exists yet.
  Future<void> deleteStaged({required int itemId, required int editRevision});
}

/// Safe Inbox failure codes (no amount, merchant, account or id in the text).
enum InboxViewErrorCode {
  notWired,
  loadFailed,
  decisionFailed,
  confirmFailed,
  overLimit,
  undoFailed,
  deleteFailed,
}

class InboxViewError implements Exception {
  const InboxViewError(this.code);

  final InboxViewErrorCode code;

  @override
  String toString() => 'InboxViewError(${code.name})';
}

/// The placeholder gateway before the app composition mounts the vault.
final class UnavailableInboxGateway implements InboxGateway {
  const UnavailableInboxGateway();

  @override
  Future<InboxPageView> loadPage({String? cursor}) async =>
      const InboxPageView(rows: <InboxRow>[], pendingCount: 0);

  @override
  Future<InboxTotals> totals(Set<int> ids) async => const InboxTotals(
        count: 0,
        netMinor: 0,
        currencyCode: 'USD',
      );

  @override
  Future<void> decide({
    required int itemId,
    required int expectedRevision,
    required bool accept,
  }) async =>
      throw const InboxViewError(InboxViewErrorCode.notWired);

  @override
  Future<InboxConfirmation> confirm(Set<int> ids) async =>
      throw const InboxViewError(InboxViewErrorCode.notWired);

  @override
  Future<void> undoBatch(String batchId) async =>
      throw const InboxViewError(InboxViewErrorCode.notWired);

  @override
  Future<void> deleteStaged({
    required int itemId,
    required int editRevision,
  }) async =>
      throw const InboxViewError(InboxViewErrorCode.notWired);
}
