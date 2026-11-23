// P25 (flow F07; SPEC 5.5, 8.17, 8.18): the app composition for the Inbox.
//
// The adapter maps the P17 repository types to the feature port. It formats no
// money and logs nothing (AGENTS 2.6). `ConfirmInboxBatch` is the only write
// that creates payments; a decision only stages.
library;

import 'dart:convert';

import '../core/dates.dart';
import '../data/repositories/inbox.dart';
import '../features/inbox/inbox_models.dart';

/// P17 behind the Inbox feature port.
final class SqlInboxGateway implements InboxGateway {
  SqlInboxGateway({
    required this.inbox,
    required this.today,
    required this.newId,
  });

  final InboxRepository inbox;

  /// A UUID v7 source for one confirm or undo command.
  final String Function() newId;

  /// The cut-off for a date that an older staged row does not carry.
  final LocalDate Function() today;

  @override
  Future<InboxPageView> loadPage({String? cursor}) async {
    final after = _decode(cursor);
    final page = await inbox.page(after: after);
    final display = await inbox.displayItems(
      limit: page.rows.length.clamp(1, 100),
      after: after,
    );
    final pending = await inbox.pendingCount();
    final rows = <InboxRow>[
      for (final entry in display)
        InboxRow(
          id: entry.row.id,
          title: entry.proposal.merchantName ?? '',
          source: entry.source,
          date: LocalDate.tryParse(entry.proposal.date) ?? today(),
          amountMinor: entry.proposal.amountMinor,
          currencyCode: entry.proposal.currency,
          editRevision: entry.row.editRevision,
          suggestion: entry.row.suggestionType,
          categoryName: entry.categoryName,
          accountName: entry.accountName,
          matchName: entry.matchName,
          isUnsure: entry.proposal.categoryId == null,
        ),
    ];
    InboxDecision? decision;
    for (final entry in display) {
      if (entry.row.suggestionType != 'transfer') {
        continue;
      }
      decision = InboxDecision(
        itemId: entry.row.id,
        editRevision: entry.row.editRevision,
        fromName: entry.accountName ?? '',
        toName: entry.matchName ?? '',
        amountMinor: entry.proposal.amountMinor,
        currencyCode: entry.proposal.currency,
        date: LocalDate.tryParse(entry.proposal.date) ?? today(),
      );
      break;
    }
    return InboxPageView(
      rows: List<InboxRow>.unmodifiable(rows),
      pendingCount: pending,
      nextCursor: page.next == null ? null : _encode(page.next!),
      decision: decision,
    );
  }

  @override
  Future<InboxTotals> totals(Set<int> ids) async {
    if (ids.isEmpty) {
      return const InboxTotals(count: 0, netMinor: 0, currencyCode: 'USD');
    }
    final selection = await inbox.selection(ids);
    final entries = selection.byCurrency.entries;
    final first = entries.isEmpty ? null : entries.first;
    return InboxTotals(
      count: selection.count,
      netMinor: first?.value.netMinor ?? 0,
      currencyCode: first?.key ?? 'USD',
    );
  }

  @override
  Future<void> decide({
    required int itemId,
    required int expectedRevision,
    required bool accept,
  }) async {
    try {
      await inbox.stageDecision(
        itemId: itemId,
        expectedRevision: expectedRevision,
        decision:
            accept ? InboxMatchDecision.accept : InboxMatchDecision.reject,
      );
    } on InboxError catch (error) {
      throw InboxViewError(
        error.code == InboxErrorCode.revisionConflict
            ? InboxViewErrorCode.loadFailed
            : InboxViewErrorCode.decisionFailed,
      );
    }
  }

  @override
  Future<InboxConfirmation> confirm(Set<int> ids) async {
    try {
      final result = await inbox.confirmBatch(
        operationId: newId(),
        selectedIds: ids,
      );
      final entries = result.selection.byCurrency.entries;
      final first = entries.isEmpty ? null : entries.first;
      return InboxConfirmation(
        operationId: result.operationId,
        batchId: result.batchId,
        count: result.selection.count,
        currencyCode: first?.key ?? 'USD',
        netMinor: first?.value.netMinor ?? 0,
      );
    } on InboxError catch (error) {
      final overLimit = error.admission?.violation != null;
      throw InboxViewError(
        overLimit
            ? InboxViewErrorCode.overLimit
            : InboxViewErrorCode.confirmFailed,
      );
    }
  }

  @override
  Future<void> undoBatch(String operationId) async {
    try {
      await inbox.undoBatch(
        operationId: newId(),
        originalOperationId: operationId,
      );
    } on InboxError {
      throw const InboxViewError(InboxViewErrorCode.undoFailed);
    }
  }

  @override
  Future<void> deleteStaged({
    required int itemId,
    required int editRevision,
  }) async {
    try {
      await inbox.deleteStaged(
        itemId: itemId,
        expectedRevision: editRevision,
      );
    } on InboxError {
      throw const InboxViewError(InboxViewErrorCode.deleteFailed);
    }
  }

  String _encode(InboxCursor cursor) => jsonEncode(<String, Object?>{
        'at': cursor.receivedAtMs,
        'id': cursor.id,
        'epoch': cursor.dbEpoch,
        'revision': cursor.inboxRevision,
      });

  InboxCursor? _decode(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(token);
      if (json is! Map) {
        return null;
      }
      final at = json['at'];
      final id = json['id'];
      final epoch = json['epoch'];
      final revision = json['revision'];
      if (at is! int || id is! int || epoch is! String || revision is! int) {
        return null;
      }
      return InboxCursor(
        receivedAtMs: at,
        id: id,
        dbEpoch: epoch,
        inboxRevision: revision,
      );
    } on FormatException {
      return null;
    }
  }
}
