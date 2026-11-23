// P17 (SYSTEM_DESIGN 6; DATABASE_DESIGN 6; SCHEMA.sql `inbox_items`,
// `staged_rows`, `source_claims`, `source_identities`): Inbox staging,
// decisions and the one-confirmation command.
//
// Reads follow Q13 (query-contracts): at most 101 candidates per extraction,
// at most 100 visible rows per display page, and a cursor that consumes only
// examined candidates. Opening or paging the Inbox writes no ledger record.
//
// `ConfirmInboxBatch` admits at most 5,000 selected source rows, 100,000
// logical row effects and 16 MiB of prepared plan. It validates the whole
// selected set against the current database and writes every selected effect
// in one transaction or none. A repeated confirmation returns the recorded
// receipt. `Undo` is a separate command on the whole batch.
//
// Log privacy (AGENTS 2.6): this file never logs or prints an amount, a
// merchant, an account name or a proposal. Errors carry safe codes and local
// entity ids only.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../db/app_database.dart';
import '../db/command_repository.dart';

/// The user's decision about a match candidate (SPEC 8.17).
enum InboxMatchDecision { accept, reject }

/// Safe Inbox failure codes.
enum InboxErrorCode {
  notFound,
  notEligible,
  revisionConflict,
  invalidProposal,
  unsupportedSuggestion,
  emptySelection,
  amountOverflow,
  admissionRows,
  admissionEffects,
  admissionPlan,
  cursorStale,
  replayMismatch,
  undoNotFound,
  undoBlocked,
}

/// A typed Inbox failure. It holds a code and local ids only.
class InboxError implements Exception {
  const InboxError(
    this.code, {
    this.itemId,
    this.blockedIds = const <String>[],
    this.admission,
  });

  final InboxErrorCode code;
  final int? itemId;
  final List<String> blockedIds;
  final InboxAdmission? admission;

  @override
  String toString() => 'InboxError(${code.name})';
}

/// SYSTEM_DESIGN 6 / DATABASE_DESIGN 6: the physical Confirm bounds.
final class InboxAdmissionLimits {
  const InboxAdmissionLimits({
    this.maxSelectedRows = 5000,
    this.maxLogicalEffects = 100000,
    this.maxPlanBytes = 16 * 1024 * 1024,
  })  : assert(maxSelectedRows > 0),
        assert(maxLogicalEffects > 0),
        assert(maxPlanBytes > 0);

  /// Maximum selected source rows (Inbox items).
  final int maxSelectedRows;

  /// Maximum logical row effects, registry, history and trigger rows included.
  final int maxLogicalEffects;

  /// Maximum encoded prepared plan.
  final int maxPlanBytes;
}

/// One measured admission check for a Confirm.
final class InboxAdmission {
  const InboxAdmission({
    required this.selectedRows,
    required this.logicalEffects,
    required this.planBytes,
    required this.limits,
  });

  final int selectedRows;
  final int logicalEffects;
  final int planBytes;
  final InboxAdmissionLimits limits;

  /// The first exceeded bound, or null when the plan is admitted.
  InboxErrorCode? get violation {
    if (selectedRows > limits.maxSelectedRows) {
      return InboxErrorCode.admissionRows;
    }
    if (logicalEffects > limits.maxLogicalEffects) {
      return InboxErrorCode.admissionEffects;
    }
    if (planBytes > limits.maxPlanBytes) {
      return InboxErrorCode.admissionPlan;
    }
    return null;
  }
}

/// One split inside an Inbox proposal.
final class InboxSplit {
  const InboxSplit({
    required this.categoryId,
    required this.amountMinor,
    this.note,
  });

  final String categoryId;
  final int amountMinor;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
        'categoryId': categoryId,
        'amountMinor': amountMinor,
        if (note != null) 'note': note,
      };
}

/// The structured proposal kept in `inbox_items.proposed_json` (version 1).
///
/// The proposal holds the fields the item sheet shows and the payment the
/// confirmation would create. It carries no raw source text.
final class InboxProposal {
  const InboxProposal({
    required this.amountMinor,
    required this.currency,
    required this.date,
    required this.accountId,
    required this.kind,
    this.merchantName,
    this.categoryId,
    this.note,
    this.splits = const <InboxSplit>[],
    this.tagIds = const <String>[],
    this.matchTransactionId,
    this.decision = InboxMatchDecision.accept,
  });

  final int amountMinor;
  final String currency;
  final String date;
  final String accountId;
  final String kind;
  final String? merchantName;
  final String? categoryId;
  final String? note;
  final List<InboxSplit> splits;
  final List<String> tagIds;

  /// The confirmed posting a merge, refund or transfer candidate points at.
  final String? matchTransactionId;

  /// The staged match decision. Staging writes no financial record.
  final InboxMatchDecision decision;

  static const int schemaVersion = 1;

  static const Set<String> _kinds = <String>{
    'expense',
    'income',
    'transfer',
    'refund',
    'fee',
    'loanIn',
    'saleProceeds',
  };

  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Parses a stored proposal. A malformed value is a typed failure.
  factory InboxProposal.fromJson(Object? value) {
    if (value is! Map) {
      throw const InboxError(InboxErrorCode.invalidProposal);
    }
    final map = Map<String, Object?>.from(value);
    final amount = map['amountMinor'];
    final currency = map['currency'];
    final date = map['date'];
    final accountId = map['accountId'];
    final kind = map['kind'];
    if (amount is! int ||
        currency is! String ||
        currency.isEmpty ||
        date is! String ||
        !_datePattern.hasMatch(date) ||
        accountId is! String ||
        accountId.isEmpty ||
        kind is! String ||
        !_kinds.contains(kind)) {
      throw const InboxError(InboxErrorCode.invalidProposal);
    }
    final splits = <InboxSplit>[];
    final splitsValue = map['splits'];
    if (splitsValue != null) {
      if (splitsValue is! List) {
        throw const InboxError(InboxErrorCode.invalidProposal);
      }
      for (final entry in splitsValue) {
        if (entry is! Map) {
          throw const InboxError(InboxErrorCode.invalidProposal);
        }
        final split = Map<String, Object?>.from(entry);
        final categoryId = split['categoryId'];
        final splitAmount = split['amountMinor'];
        final note = split['note'];
        if (categoryId is! String ||
            categoryId.isEmpty ||
            splitAmount is! int ||
            (note != null && note is! String)) {
          throw const InboxError(InboxErrorCode.invalidProposal);
        }
        splits.add(
          InboxSplit(
            categoryId: categoryId,
            amountMinor: splitAmount,
            note: note as String?,
          ),
        );
      }
    }
    final tags = <String>[];
    final tagsValue = map['tagIds'];
    if (tagsValue != null) {
      if (tagsValue is! List) {
        throw const InboxError(InboxErrorCode.invalidProposal);
      }
      for (final entry in tagsValue) {
        if (entry is! String || entry.isEmpty) {
          throw const InboxError(InboxErrorCode.invalidProposal);
        }
        tags.add(entry);
      }
    }
    final match = map['matchTransactionId'];
    final merchantName = map['merchantName'];
    final categoryId = map['categoryId'];
    final note = map['note'];
    final decisionValue = map['decision'];
    if ((match != null && match is! String) ||
        (merchantName != null && merchantName is! String) ||
        (categoryId != null && categoryId is! String) ||
        (note != null && note is! String) ||
        (decisionValue != null && decisionValue is! String)) {
      throw const InboxError(InboxErrorCode.invalidProposal);
    }
    final decision = switch (decisionValue) {
      null || 'accept' => InboxMatchDecision.accept,
      'reject' => InboxMatchDecision.reject,
      _ => throw const InboxError(InboxErrorCode.invalidProposal),
    };
    final splitTotal =
        splits.fold<int>(0, (sum, split) => sum + split.amountMinor);
    if (splits.isNotEmpty && splitTotal != amount) {
      throw const InboxError(InboxErrorCode.invalidProposal);
    }
    return InboxProposal(
      amountMinor: amount,
      currency: currency,
      date: date,
      accountId: accountId,
      kind: kind,
      merchantName: merchantName as String?,
      categoryId: categoryId as String?,
      note: note as String?,
      splits: List<InboxSplit>.unmodifiable(splits),
      tagIds: List<String>.unmodifiable(tags),
      matchTransactionId: match as String?,
      decision: decision,
    );
  }

  InboxProposal withDecision(InboxMatchDecision value) => InboxProposal(
        amountMinor: amountMinor,
        currency: currency,
        date: date,
        accountId: accountId,
        kind: kind,
        merchantName: merchantName,
        categoryId: categoryId,
        note: note,
        splits: splits,
        tagIds: tagIds,
        matchTransactionId: matchTransactionId,
        decision: value,
      );

  /// The canonical proposal encoding. Decoding and re-encoding gives the
  /// same bytes, so a revision check compares this text.
  String canonicalJson() => jsonEncode(toJson());

  Map<String, Object?> toJson() => <String, Object?>{
        'v': schemaVersion,
        'amountMinor': amountMinor,
        'currency': currency,
        'date': date,
        'accountId': accountId,
        'kind': kind,
        if (merchantName != null) 'merchantName': merchantName,
        if (categoryId != null) 'categoryId': categoryId,
        if (note != null) 'note': note,
        'splits': <Object?>[for (final split in splits) split.toJson()],
        'tagIds': tagIds,
        if (matchTransactionId != null)
          'matchTransactionId': matchTransactionId,
        'decision': decision.name,
      };
}

/// One Q13 list row. The payload is read separately for a bounded page.
final class InboxItemRow {
  const InboxItemRow({
    required this.id,
    required this.sourceIdentityId,
    required this.stagedRowId,
    required this.receivedAtMs,
    required this.suggestionType,
    required this.editRevision,
  });

  final int id;
  final int sourceIdentityId;
  final int? stagedRowId;
  final int receivedAtMs;
  final String suggestionType;
  final int editRevision;
}

/// One list row with its proposal (item sheet and selection totals).
final class InboxItem {
  const InboxItem({required this.row, required this.proposal});

  final InboxItemRow row;
  final InboxProposal proposal;
}

/// P25 (X60/X61): one pending item with the names the screen shows.
final class InboxDisplayItem {
  const InboxDisplayItem({
    required this.item,
    required this.source,
    this.categoryName,
    this.accountName,
    this.matchName,
  });

  final InboxItem item;

  /// The source channel (`source_identities.namespace`).
  final String source;
  final String? categoryName;
  final String? accountName;

  /// The merchant of the confirmed posting a candidate points at.
  /// The account name of the confirmed posting a candidate points at.
  final String? matchName;

  InboxProposal get proposal => item.proposal;
  InboxItemRow get row => item.row;
}

/// The (received_at, id) keyset cursor, restarted on a new epoch or Inbox
/// membership revision (Q13).
final class InboxCursor {
  const InboxCursor({
    required this.receivedAtMs,
    required this.id,
    required this.dbEpoch,
    required this.inboxRevision,
  });

  final int receivedAtMs;
  final int id;
  final String dbEpoch;
  final int inboxRevision;
}

/// One display page of the pending Inbox.
final class InboxPage {
  const InboxPage({
    required this.rows,
    required this.next,
    required this.inboxRevision,
  });

  final List<InboxItemRow> rows;

  /// The next cursor, or null when the extracted candidates are exhausted.
  final InboxCursor? next;

  final int inboxRevision;
}

/// Exact selected amounts per currency (F07-B).
final class InboxAmounts {
  const InboxAmounts({
    required this.netMinor,
    required this.outMinor,
    required this.inMinor,
  });

  /// Signed sum of the selected amounts.
  final int netMinor;

  /// Sum of money-out amounts, shown as a positive number.
  final int outMinor;

  /// Sum of money-in amounts.
  final int inMinor;

  Map<String, Object?> toJson() => <String, Object?>{
        'netMinor': netMinor,
        'outMinor': outMinor,
        'inMinor': inMinor,
      };
}

/// The exact ticked count and totals. The confirm label reads this and never
/// a client-supplied total (F07-B).
final class InboxSelection {
  const InboxSelection({required this.count, required this.byCurrency});

  final int count;
  final Map<String, InboxAmounts> byCurrency;

  Map<String, Object?> toJson() => <String, Object?>{
        'count': count,
        'byCurrency': <String, Object?>{
          for (final entry in byCurrency.entries)
            entry.key: entry.value.toJson(),
        },
      };
}

/// The committed result of `ConfirmInboxBatch`.
final class InboxConfirmResult {
  const InboxConfirmResult({
    required this.operationId,
    required this.batchId,
    required this.commitSequence,
    required this.readRevision,
    required this.selection,
    required this.created,
    required this.linked,
  });

  final String operationId;
  final String batchId;
  final int commitSequence;
  final int readRevision;

  /// The exact count and totals this command confirmed.
  final InboxSelection selection;

  /// Payments created by the batch.
  final int created;

  /// Items resolved by a link to an existing confirmed posting.
  final int linked;

  factory InboxConfirmResult.fromOutcome(CommandOutcome outcome) {
    final parsed = jsonDecode(outcome.resultJson);
    if (parsed is! Map) {
      throw const InboxError(InboxErrorCode.undoNotFound);
    }
    final map = Map<String, Object?>.from(parsed);
    final totals = map['totals'];
    final byCurrency = <String, InboxAmounts>{};
    if (totals is Map) {
      for (final entry in Map<String, Object?>.from(totals).entries) {
        final value = entry.value;
        if (value is! Map) {
          throw const InboxError(InboxErrorCode.undoNotFound);
        }
        final amounts = Map<String, Object?>.from(value);
        byCurrency[entry.key] = InboxAmounts(
          netMinor: amounts['netMinor'] as int,
          outMinor: amounts['outMinor'] as int,
          inMinor: amounts['inMinor'] as int,
        );
      }
    }
    return InboxConfirmResult(
      operationId: outcome.operationId,
      batchId: map['batchId'] as String,
      commitSequence: outcome.commitSequence,
      readRevision: outcome.readRevision,
      selection: InboxSelection(
        count: map['selected'] as int,
        byCurrency: Map<String, InboxAmounts>.unmodifiable(byCurrency),
      ),
      created: map['created'] as int,
      linked: map['linked'] as int,
    );
  }
}

/// The committed result of a whole-batch Undo.
final class InboxUndoResult {
  const InboxUndoResult({
    required this.operationId,
    required this.undoOf,
    required this.commitSequence,
    required this.readRevision,
    required this.reversed,
  });

  final String operationId;
  final String undoOf;
  final int commitSequence;
  final int readRevision;

  /// Payments soft-deleted by the Undo.
  final int reversed;

  factory InboxUndoResult.fromOutcome(CommandOutcome outcome) {
    final parsed = jsonDecode(outcome.resultJson);
    if (parsed is! Map) {
      throw const InboxError(InboxErrorCode.undoNotFound);
    }
    final map = Map<String, Object?>.from(parsed);
    return InboxUndoResult(
      operationId: outcome.operationId,
      undoOf: map['undoOf'] as String,
      commitSequence: outcome.commitSequence,
      readRevision: outcome.readRevision,
      reversed: map['reversed'] as int,
    );
  }
}

/// SPEC 8.17 / flow F07: the staged Inbox and its confirmation command.
final class InboxRepository {
  InboxRepository({
    required AppDatabase db,
    required CommandRepository commands,
    required DateTime Function() clockUtc,
    String Function()? newEntityId,
    this.limits = const InboxAdmissionLimits(),
  })  : _db = db,
        _commands = commands,
        _clockUtc = clockUtc,
        _newEntityId = newEntityId;

  final AppDatabase _db;
  final CommandRepository _commands;
  final DateTime Function() _clockUtc;
  final String Function()? _newEntityId;
  final InboxAdmissionLimits limits;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  // ---------------------------------------------------------------------
  // Reads (Q13)
  // ---------------------------------------------------------------------

  /// Q13: one bounded page of pending, visible Inbox rows.
  ///
  /// At most 101 candidates are admitted per extraction and at most 100
  /// eligible rows leave a display page. A private candidate is consumed but
  /// not returned; a visible look-ahead row is not consumed when the page is
  /// full.
  Future<InboxPage> page({int limit = 100, InboxCursor? after}) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be 1 to 100');
    }
    final state = await _dbState();
    if (after != null &&
        (after.dbEpoch != state.dbEpoch ||
            after.inboxRevision != state.inboxRevision)) {
      throw const InboxError(InboxErrorCode.cursorStale);
    }
    final candidateLimit = limit + 1;
    final rows = await _db.customSelect(
      'WITH candidates AS MATERIALIZED ('
      'SELECT id, source_identity_id, staged_row_id, received_at, '
      'suggestion_type, edit_revision FROM inbox_items '
      "WHERE decision = 'pending' AND (received_at, id) > (?, ?) "
      'ORDER BY received_at, id LIMIT ?'
      ') '
      'SELECT p.id, p.source_identity_id, p.staged_row_id, p.received_at, '
      'p.suggestion_type, p.edit_revision, '
      "CASE WHEN c.status = 'staged' AND ("
      '(c.draft_id IS NOT NULL AND p.staged_row_id IS NULL) OR '
      '(c.batch_id IS NOT NULL AND b.inbox_published = 1 '
      "AND b.status = 'review' AND (p.staged_row_id IS NULL OR "
      '(s.batch_id = c.batch_id AND '
      's.source_identity_id = p.source_identity_id))))'
      ' THEN 1 ELSE 0 END AS visible '
      'FROM candidates p '
      'LEFT JOIN source_claims c '
      'ON c.source_identity_id = p.source_identity_id '
      'LEFT JOIN staged_rows s ON s.id = p.staged_row_id '
      'LEFT JOIN import_batches b ON b.id = c.batch_id '
      'ORDER BY p.received_at, p.id',
      variables: <Variable<Object>>[
        Variable(after?.receivedAtMs ?? -1),
        Variable(after?.id ?? 0),
        Variable(candidateLimit),
      ],
    ).get();

    final pageRows = <InboxItemRow>[];
    InboxItemRow? lastConsumed;
    var pageFull = false;
    for (final row in rows) {
      final visible = (row.data['visible'] as int) == 1;
      if (visible && pageRows.length >= limit) {
        pageFull = true;
        break;
      }
      final item = InboxItemRow(
        id: row.data['id'] as int,
        sourceIdentityId: row.data['source_identity_id'] as int,
        stagedRowId: row.data['staged_row_id'] as int?,
        receivedAtMs: row.data['received_at'] as int,
        suggestionType: row.data['suggestion_type'] as String,
        editRevision: row.data['edit_revision'] as int,
      );
      lastConsumed = item;
      if (visible) {
        pageRows.add(item);
      }
    }

    final exhausted = rows.length < candidateLimit && !pageFull;
    final next = exhausted || lastConsumed == null
        ? null
        : InboxCursor(
            receivedAtMs: lastConsumed.receivedAtMs,
            id: lastConsumed.id,
            dbEpoch: state.dbEpoch,
            inboxRevision: state.inboxRevision,
          );
    return InboxPage(
      rows: List<InboxItemRow>.unmodifiable(pageRows),
      next: next,
      inboxRevision: state.inboxRevision,
    );
  }

  /// The pending, visible item count for the Home badge.
  Future<int> pendingCount() async {
    final row = await _db
        .customSelect(
          'SELECT count(*) AS n FROM inbox_items p '
          'LEFT JOIN source_claims c '
          'ON c.source_identity_id = p.source_identity_id '
          'LEFT JOIN staged_rows s ON s.id = p.staged_row_id '
          'LEFT JOIN import_batches b ON b.id = c.batch_id '
          "WHERE p.decision = 'pending' AND c.status = 'staged' AND ("
          '(c.draft_id IS NOT NULL AND p.staged_row_id IS NULL) OR '
          '(c.batch_id IS NOT NULL AND b.inbox_published = 1 '
          "AND b.status = 'review' AND (p.staged_row_id IS NULL OR "
          '(s.batch_id = c.batch_id AND '
          's.source_identity_id = p.source_identity_id))))',
        )
        .getSingle();
    return row.data['n'] as int;
  }

  /// One pending, visible item with its proposal, or null.
  Future<InboxItem?> item(int id) async {
    final loaded = await _loadPending(<int>[id], allowMissing: true);
    if (loaded.isEmpty) {
      return null;
    }
    final entry = loaded.single;
    return InboxItem(row: entry.row, proposal: entry.proposal);
  }

  /// A bounded set of pending, visible items with proposals.
  ///
  /// The list screen calls this with one display page; the confirm path calls
  /// it with the selected set. Any id that is not pending and visible is a
  /// typed failure, never a silent omission.
  Future<List<InboxItem>> items(List<int> ids) async {
    final loaded = await _loadPending(ids);
    return <InboxItem>[
      for (final entry in loaded)
        InboxItem(row: entry.row, proposal: entry.proposal),
    ];
  }

  /// F07-B: the exact ticked count and totals for the confirm label.
  Future<InboxSelection> selection(Set<int> ids) async {
    if (ids.isEmpty) {
      return const InboxSelection(
        count: 0,
        byCurrency: <String, InboxAmounts>{},
      );
    }
    final loaded = await _loadPending(ids.toList());
    return _selectionOf(loaded);
  }

  // ---------------------------------------------------------------------
  // Staged decisions (no ledger write)
  // ---------------------------------------------------------------------

  /// Stages a match decision in the proposal. Only Confirm writes records.
  Future<void> stageDecision({
    required int itemId,
    required int expectedRevision,
    required InboxMatchDecision decision,
  }) async {
    final loaded = await _loadPending(<int>[itemId]);
    final entry = loaded.single;
    if (entry.row.editRevision != expectedRevision) {
      throw InboxError(
        InboxErrorCode.revisionConflict,
        itemId: itemId,
      );
    }
    final updated = entry.proposal.withDecision(decision);
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE inbox_items SET proposed_json = ?, '
        'edit_revision = edit_revision + 1 '
        "WHERE id = ? AND decision = 'pending' AND edit_revision = ?",
        <Object?>[
          updated.canonicalJson(),
          itemId,
          expectedRevision,
        ],
      );
      await _bumpInboxRevision();
    });
  }

  /// Deletes one staged item. No financial record and no ChangeLog row is
  /// written; the source identity stays reserved.
  Future<void> deleteStaged({
    required int itemId,
    required int expectedRevision,
  }) async {
    final loaded = await _loadPending(<int>[itemId]);
    final entry = loaded.single;
    if (entry.row.editRevision != expectedRevision) {
      throw InboxError(
        InboxErrorCode.revisionConflict,
        itemId: itemId,
      );
    }
    final now = _nowMs();
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE inbox_items SET decision = ?, decided_at = ?, '
        'proposed_json = NULL, staged_row_id = NULL, '
        'edit_revision = edit_revision + 1 '
        "WHERE id = ? AND decision = 'pending' AND edit_revision = ?",
        <Object?>['deleted', now, itemId, expectedRevision],
      );
      await _db.customStatement(
        'UPDATE source_claims SET status = ? '
        'WHERE source_identity_id = ? AND status = ?',
        <Object?>['discarded', entry.row.sourceIdentityId, 'staged'],
      );
      if (entry.row.stagedRowId != null) {
        await _db.customStatement(
          'DELETE FROM staged_rows WHERE id = ?',
          <Object?>[entry.row.stagedRowId],
        );
      }
      await _bumpInboxRevision();
    });
  }

  // ---------------------------------------------------------------------
  // ConfirmInboxBatch
  // ---------------------------------------------------------------------

  /// Confirms the selected Inbox items as one command (DATABASE_DESIGN 6).
  ///
  /// The receipt is checked first, so a repeated confirmation returns the
  /// recorded result. Admission runs before the intent is persisted, so an
  /// over-limit batch keeps every draft and changes nothing. The effects
  /// recheck every revision and eligibility inside the write transaction.
  Future<InboxConfirmResult> confirmBatch({
    required String operationId,
    required Set<int> selectedIds,
    String? batchId,
  }) async {
    final ids = selectedIds.toList()..sort();
    if (ids.isEmpty) {
      throw const InboxError(InboxErrorCode.emptySelection);
    }

    final existing = await _commands.receiptOf(operationId);
    if (existing != null) {
      await _checkReplay(operationId, ids);
      return InboxConfirmResult.fromOutcome(existing);
    }

    final loaded = await _loadPending(ids);
    final found = <int>{for (final entry in loaded) entry.row.id};
    for (final id in ids) {
      if (!found.contains(id)) {
        throw InboxError(InboxErrorCode.notEligible, itemId: id);
      }
    }

    final plan = _plan(loaded);
    final admission = _admission(plan);
    final violation = admission.violation;
    if (violation != null) {
      throw InboxError(violation, admission: admission);
    }

    final selection = _selectionOf(loaded);
    final batch = batchId ?? _nextId();
    final created = plan.entries.where((entry) => entry.createsPayment).length;
    final linked = plan.entries
        .where((entry) => entry.outcome == _Outcome.mergeLink)
        .length;
    final resultJson = jsonEncode(<String, Object?>{
      'kind': 'inbox.confirmBatch',
      'batchId': batch,
      'selected': selection.count,
      'created': created,
      'linked': linked,
      'totals': <String, Object?>{
        for (final entry in selection.byCurrency.entries)
          entry.key: entry.value.toJson(),
      },
    });

    await _commands.prepare(
      operationId: operationId,
      commandType: 'inbox.confirmBatch',
      draftId: batch,
      formType: 'inboxBatch',
      payloadJson: _manifest(ids, loaded, batch),
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );

    final outcome = await _commands.execute(
      operationId: operationId,
      changes: plan.changes,
      effects: () => _applyConfirm(plan, operationId),
      resultJson: resultJson,
    );
    return InboxConfirmResult.fromOutcome(outcome);
  }

  // ---------------------------------------------------------------------
  // Undo of the whole batch
  // ---------------------------------------------------------------------

  /// SPEC 8.18: reverses one confirmed Inbox batch as a new command.
  ///
  /// A later edit, settlement or link blocks the Undo and writes nothing.
  Future<InboxUndoResult> undoBatch({
    required String operationId,
    required String originalOperationId,
    String? undoDraftId,
  }) async {
    final existing = await _commands.receiptOf(operationId);
    if (existing != null) {
      return InboxUndoResult.fromOutcome(existing);
    }
    final original = await _commands.receiptOf(originalOperationId);
    if (original == null) {
      throw const InboxError(InboxErrorCode.undoNotFound);
    }
    final parsed = jsonDecode(original.resultJson);
    if (parsed is! Map ||
        Map<String, Object?>.from(parsed)['kind'] != 'inbox.confirmBatch') {
      throw const InboxError(InboxErrorCode.undoNotFound);
    }

    final created = await _createdEntities(originalOperationId);
    final blocked = await _undoBlockers(created, originalOperationId);
    if (blocked.isNotEmpty) {
      throw InboxError(
        InboxErrorCode.undoBlocked,
        blockedIds: List<String>.unmodifiable(blocked),
      );
    }
    final changes = <ChangeLogEntry>[
      for (final row in created)
        ChangeLogEntry(
          entityId: row.id,
          fromRevision: row.revision,
          toRevision: row.revision + 1,
          changeKind: 'compensate',
          beforeJson: '{"deleted":false}',
          afterJson: '{"deleted":true}',
          schemaVersion: 1,
        ),
    ];
    final resultJson = jsonEncode(<String, Object?>{
      'kind': 'inbox.undoBatch',
      'undoOf': originalOperationId,
      'reversed': _countKind(created, 'transactions'),
    });

    await _commands.prepare(
      operationId: operationId,
      commandType: 'inbox.undoBatch',
      draftId: undoDraftId ?? _nextId(),
      formType: 'inboxUndo',
      payloadJson: jsonEncode(<String, Object?>{
        'v': 1,
        'kind': 'inbox.undoBatch',
        'undoOf': originalOperationId,
      }),
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );

    final outcome = await _commands.execute(
      operationId: operationId,
      changes: changes,
      effects: () => _applyUndo(created, originalOperationId, operationId),
      resultJson: resultJson,
    );
    return InboxUndoResult.fromOutcome(outcome);
  }

  // ---------------------------------------------------------------------
  // Confirm internals
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // P25 display reads (X60, X61)
  // ---------------------------------------------------------------------

  /// One display page with the names the screens show.
  ///
  /// The list and the item sheet need a category name, an account name and the
  /// source channel. This read joins them for the current page only; it writes
  /// nothing and never resolves a decision.
  Future<List<InboxDisplayItem>> displayItems({
    int limit = 100,
    InboxCursor? after,
  }) async {
    final pageResult = await page(limit: limit, after: after);
    if (pageResult.rows.isEmpty) {
      return const <InboxDisplayItem>[];
    }
    final loaded = await items(
      <int>[for (final row in pageResult.rows) row.id],
    );
    final sourceIds = <int>{
      for (final row in pageResult.rows) row.sourceIdentityId,
    };
    final namespaces = await _nameMap(
      table: 'source_identities',
      nameColumn: 'namespace',
      ids: sourceIds,
    );
    final categoryIds = <String>{
      for (final item in loaded)
        if (item.proposal.categoryId != null) item.proposal.categoryId!,
    };
    final accountIds = <String>{
      for (final item in loaded) item.proposal.accountId,
    };
    final matchIds = <String>{
      for (final item in loaded)
        if (item.proposal.matchTransactionId != null)
          item.proposal.matchTransactionId!,
    };
    final categories = await _nameMap(
      table: 'categories',
      nameColumn: 'name',
      ids: categoryIds,
    );
    final accounts = await _nameMap(
      table: 'accounts',
      nameColumn: 'name',
      ids: accountIds,
    );
    final matches = await _matchAccountMap(matchIds);
    return <InboxDisplayItem>[
      for (final item in loaded)
        InboxDisplayItem(
          item: item,
          source: namespaces[item.row.sourceIdentityId] ?? '',
          categoryName: categories[item.proposal.categoryId],
          accountName: accounts[item.proposal.accountId],
          matchName: matches[item.proposal.matchTransactionId],
        ),
    ];
  }

  /// The account name of the confirmed posting a candidate points at.
  Future<Map<Object, String>> _matchAccountMap(Set<Object> ids) async {
    if (ids.isEmpty) {
      return <Object, String>{};
    }
    final list = ids.toList(growable: false);
    final placeholders = List<String>.filled(list.length, '?').join(',');
    final rows = await _db.customSelect(
      'SELECT t.id, a.name AS name FROM transactions t '
      'JOIN accounts a ON a.id = t.account_id '
      'WHERE t.id IN ($placeholders)',
      variables: <Variable<Object>>[for (final id in list) Variable(id)],
    ).get();
    return <Object, String>{
      for (final row in rows)
        if (row.data['name'] != null)
          row.data['id']! as Object: row.data['name']! as String,
    };
  }

  Future<Map<Object, String>> _nameMap({
    required String table,
    required String nameColumn,
    required Set<Object> ids,
  }) async {
    if (ids.isEmpty) {
      return <Object, String>{};
    }
    final list = ids.toList(growable: false);
    final placeholders = List<String>.filled(list.length, '?').join(',');
    final rows = await _db.customSelect(
      'SELECT id, $nameColumn AS name FROM $table '
      'WHERE id IN ($placeholders)',
      variables: <Variable<Object>>[for (final id in list) Variable(id)],
    ).get();
    return <Object, String>{
      for (final row in rows)
        if (row.data['name'] != null)
          row.data['id']! as Object: row.data['name']! as String,
    };
  }

  Future<void> _checkReplay(String operationId, List<int> ids) async {
    final row = await _db.customSelect(
      'SELECT payload_json FROM operation_payload_chunks '
      'WHERE operation_id = ? AND chunk_index = 0',
      variables: <Variable<Object>>[Variable(operationId)],
    ).getSingleOrNull();
    if (row == null) {
      return;
    }
    final parsed = jsonDecode(row.data['payload_json'] as String);
    if (parsed is! Map) {
      throw const InboxError(InboxErrorCode.replayMismatch);
    }
    final stored = Map<String, Object?>.from(parsed)['selectionDigest'];
    if (stored is! String || stored != _selectionDigest(ids)) {
      throw const InboxError(InboxErrorCode.replayMismatch);
    }
  }

  String _manifest(
    List<int> ids,
    List<_LoadedItem> loaded,
    String batchId,
  ) {
    final revisions = <String, Object?>{
      for (final entry in loaded) '${entry.row.id}': entry.row.editRevision,
    };
    return jsonEncode(<String, Object?>{
      'v': 1,
      'kind': 'inbox.confirmBatch',
      'selectionDigest': _selectionDigest(ids),
      'batchId': batchId,
      'items': <Object?>[
        for (final id in ids) <Object?>[id, revisions['$id']],
      ],
    });
  }

  String _selectionDigest(List<int> ids) {
    final sorted = <int>[...ids]..sort();
    return sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
  }

  InboxAdmission _admission(_BatchPlan plan) {
    var bytes = 0;
    var effects = 0;
    for (final entry in plan.entries) {
      bytes += utf8.encode(entry.loaded.proposal.canonicalJson()).length +
          128 +
          (64 * entry.loaded.proposal.splits.length) +
          (36 * entry.loaded.proposal.tagIds.length);
      effects += _effectsOf(entry);
    }
    return InboxAdmission(
      selectedRows: plan.entries.length,
      logicalEffects: effects,
      planBytes: bytes,
      limits: limits,
    );
  }

  int _effectsOf(_PlannedItem item) {
    final proposal = item.loaded.proposal;
    // One event, one transaction, the item and claim updates, the staged-row
    // delete and the registry/audit rows around them.
    var count = 14;
    count += 4 * proposal.splits.length;
    count += 2 * proposal.tagIds.length;
    if (item.outcome != _Outcome.mergeLink) {
      count += 2;
    }
    return count;
  }

  InboxSelection _selectionOf(List<_LoadedItem> loaded) {
    final sums = <String, ({BigInt net, BigInt out, BigInt inn})>{};
    for (final entry in loaded) {
      final amount = BigInt.from(entry.proposal.amountMinor);
      final current = sums[entry.proposal.currency] ??
          (net: BigInt.zero, out: BigInt.zero, inn: BigInt.zero);
      final out = entry.proposal.amountMinor < 0
          ? current.out + amount.abs()
          : current.out;
      final inn =
          entry.proposal.amountMinor > 0 ? current.inn + amount : current.inn;
      sums[entry.proposal.currency] = (
        net: current.net + amount,
        out: out,
        inn: inn,
      );
    }
    final byCurrency = <String, InboxAmounts>{};
    for (final entry in sums.entries) {
      byCurrency[entry.key] = InboxAmounts(
        netMinor: _toMinor(entry.value.net),
        outMinor: _toMinor(entry.value.out),
        inMinor: _toMinor(entry.value.inn),
      );
    }
    return InboxSelection(
      count: loaded.length,
      byCurrency: Map<String, InboxAmounts>.unmodifiable(byCurrency),
    );
  }

  int _toMinor(BigInt value) {
    if (value > _maxMinor || value < _minMinor) {
      throw const InboxError(InboxErrorCode.amountOverflow);
    }
    return value.toInt();
  }

  _BatchPlan _plan(List<_LoadedItem> loaded) {
    final entries = <_PlannedItem>[];
    final changes = <ChangeLogEntry>[];
    for (final entry in loaded) {
      final outcome = _outcomeOf(entry);
      final eventId = outcome == _Outcome.mergeLink ? '' : _nextId();
      final transactionId = outcome == _Outcome.mergeLink ? '' : _nextId();
      final splitIds = <String>[
        for (final _ in entry.proposal.splits) _nextId(),
      ];
      final linkId = switch (outcome) {
        _Outcome.refundLink || _Outcome.transferLink => _nextId(),
        _ => null,
      };
      entries.add(
        _PlannedItem(
          loaded: entry,
          outcome: outcome,
          eventId: eventId,
          transactionId: transactionId,
          splitIds: splitIds,
          linkId: linkId,
        ),
      );
      if (outcome == _Outcome.mergeLink) {
        continue;
      }
      changes.add(
        ChangeLogEntry(
          entityId: eventId,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'type': 'financial_event',
            'date': entry.proposal.date,
          }),
          schemaVersion: 1,
        ),
      );
      changes.add(
        ChangeLogEntry(
          entityId: transactionId,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'amountMinor': entry.proposal.amountMinor,
            'currency': entry.proposal.currency,
            'kind': entry.proposal.kind,
            'accountId': entry.proposal.accountId,
          }),
          schemaVersion: 1,
        ),
      );
      for (final (index, split) in entry.proposal.splits.indexed) {
        changes.add(
          ChangeLogEntry(
            entityId: splitIds[index],
            toRevision: 1,
            changeKind: 'create',
            afterJson: jsonEncode(<String, Object?>{
              'amountMinor': split.amountMinor,
              'categoryId': split.categoryId,
            }),
            schemaVersion: 1,
          ),
        );
      }
      if (linkId != null) {
        changes.add(
          ChangeLogEntry(
            entityId: linkId,
            toRevision: 1,
            changeKind: 'create',
            afterJson: jsonEncode(<String, Object?>{
              'type': 'link',
              'kind': outcome.name,
            }),
            schemaVersion: 1,
          ),
        );
      }
    }
    return _BatchPlan(
      entries: List<_PlannedItem>.unmodifiable(entries),
      changes: List<ChangeLogEntry>.unmodifiable(changes),
    );
  }

  _Outcome _outcomeOf(_LoadedItem entry) {
    final type = entry.row.suggestionType;
    final accept = entry.proposal.decision == InboxMatchDecision.accept;
    if (type != 'transfer' && entry.proposal.kind == 'transfer') {
      throw InboxError(
        InboxErrorCode.unsupportedSuggestion,
        itemId: entry.row.id,
      );
    }
    return switch (type) {
      'new' => _Outcome.payment,
      'merge' => accept ? _Outcome.mergeLink : _Outcome.payment,
      'refund' => accept ? _Outcome.refundLink : _Outcome.payment,
      'transfer' => accept
          ? _Outcome.transferLink
          : throw InboxError(
              InboxErrorCode.unsupportedSuggestion,
              itemId: entry.row.id,
            ),
      _ => throw InboxError(
          InboxErrorCode.unsupportedSuggestion,
          itemId: entry.row.id,
        ),
    };
  }

  Future<void> _applyConfirm(_BatchPlan plan, String operationId) async {
    // `inbox_items.operation_id`, `source_claims.decided_operation_id` and
    // `source_event_links.operation_id` reference the receipt that the writer
    // inserts later in this same transaction.
    await _db.customStatement('PRAGMA defer_foreign_keys = ON');
    final now = _nowMs();
    final accounts = <String>{};
    final stagedRows = <int>[];

    for (final planned in plan.entries) {
      final current = await _loadOne(planned.loaded.row.id);
      if (current == null ||
          current.row.editRevision != planned.loaded.row.editRevision ||
          current.proposal.canonicalJson() !=
              planned.loaded.proposal.canonicalJson()) {
        throw InboxError(
          InboxErrorCode.revisionConflict,
          itemId: planned.loaded.row.id,
        );
      }
      final proposal = current.proposal;
      switch (planned.outcome) {
        case _Outcome.mergeLink:
          await _insertMergeLink(planned, proposal, operationId);
        case _Outcome.payment:
          await _insertPayment(planned, proposal, operationId, now);
          accounts.add(proposal.accountId);
        case _Outcome.refundLink:
          await _insertRefund(planned, proposal, operationId, now);
          accounts.add(proposal.accountId);
        case _Outcome.transferLink:
          await _insertTransfer(planned, proposal, operationId, now);
          accounts.add(proposal.accountId);
          final match = proposal.matchTransactionId;
          if (match != null) {
            final other = await _db.customSelect(
              'SELECT account_id FROM transactions WHERE id = ?',
              variables: <Variable<Object>>[Variable(match)],
            ).getSingleOrNull();
            if (other != null) {
              accounts.add(other.data['account_id'] as String);
            }
          }
      }
      if (current.row.stagedRowId != null) {
        stagedRows.add(current.row.stagedRowId!);
      }
      await _db.customStatement(
        'UPDATE inbox_items SET decision = ?, decided_at = ?, '
        'operation_id = ?, proposed_json = NULL, staged_row_id = NULL, '
        'edit_revision = edit_revision + 1 WHERE id = ?',
        <Object?>['accepted', now, operationId, current.row.id],
      );
      await _db.customStatement(
        'UPDATE source_claims SET status = ?, decided_operation_id = ? '
        'WHERE source_identity_id = ? AND status = ?',
        <Object?>[
          'accepted',
          operationId,
          current.row.sourceIdentityId,
          'staged',
        ],
      );
    }
    for (final id in stagedRows) {
      await _db.customStatement(
        'DELETE FROM staged_rows WHERE id = ?',
        <Object?>[id],
      );
    }
    for (final accountId in accounts) {
      await _bumpAccountRevision(accountId);
    }
    await _bumpInboxRevision();
  }

  Future<void> _insertPayment(
    _PlannedItem planned,
    InboxProposal proposal,
    String operationId,
    int now,
  ) async {
    final kind = planned.loaded.row.suggestionType == 'refund'
        ? 'refund'
        : proposal.kind;
    await _validateAccount(
      proposal.accountId,
      proposal.currency,
      planned.loaded.row.id,
    );
    await _validateCategory(proposal.categoryId, planned.loaded.row.id);
    for (final split in proposal.splits) {
      await _validateCategory(split.categoryId, planned.loaded.row.id);
    }
    for (final tagId in proposal.tagIds) {
      await _validateTag(tagId, planned.loaded.row.id);
    }
    await _db.customStatement(
      'INSERT INTO financial_events (id, created_at, updated_at, '
      'deleted_at, revision, event_type, date, operation_id, '
      'supersedes_event_id) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, NULL)',
      <Object?>[
        planned.eventId,
        now,
        now,
        _eventType(kind),
        proposal.date,
        operationId,
      ],
    );
    await _db.customStatement(
      'INSERT INTO transactions (id, created_at, updated_at, deleted_at, '
      'revision, event_id, account_id, date, amount_minor, currency, '
      'kind, merchant_name, note, category_id, source, is_estimated) '
      'VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
      <Object?>[
        planned.transactionId,
        now,
        now,
        planned.eventId,
        proposal.accountId,
        proposal.date,
        proposal.amountMinor,
        proposal.currency,
        kind,
        proposal.merchantName,
        proposal.note,
        proposal.categoryId,
        planned.loaded.source,
      ],
    );
    for (final (index, split) in proposal.splits.indexed) {
      await _db.customStatement(
        'INSERT INTO transaction_splits (id, created_at, updated_at, '
        'deleted_at, revision, transaction_id, category_id, amount_minor, '
        'currency, note) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?)',
        <Object?>[
          planned.splitIds[index],
          now,
          now,
          planned.transactionId,
          split.categoryId,
          split.amountMinor,
          proposal.currency,
          split.note,
        ],
      );
    }
    for (final tagId in proposal.tagIds) {
      await _db.customStatement(
        'INSERT INTO transaction_tags (transaction_id, tag_id) '
        'VALUES (?, ?)',
        <Object?>[planned.transactionId, tagId],
      );
    }
  }

  Future<void> _insertMergeLink(
    _PlannedItem planned,
    InboxProposal proposal,
    String operationId,
  ) async {
    final match = proposal.matchTransactionId;
    if (match == null) {
      throw InboxError(
        InboxErrorCode.invalidProposal,
        itemId: planned.loaded.row.id,
      );
    }
    final row = await _db.customSelect(
      'SELECT event_id, currency, deleted_at FROM transactions WHERE id = ?',
      variables: <Variable<Object>>[Variable(match)],
    ).getSingleOrNull();
    if (row == null ||
        row.data['deleted_at'] != null ||
        row.data['currency'] != proposal.currency) {
      throw InboxError(
        InboxErrorCode.invalidProposal,
        itemId: planned.loaded.row.id,
      );
    }
    await _db.customStatement(
      'INSERT INTO source_event_links (source_identity_id, event_id, '
      'operation_id) VALUES (?, ?, ?)',
      <Object?>[
        planned.loaded.row.sourceIdentityId,
        row.data['event_id'] as String,
        operationId,
      ],
    );
  }

  Future<void> _insertRefund(
    _PlannedItem planned,
    InboxProposal proposal,
    String operationId,
    int now,
  ) async {
    final match = proposal.matchTransactionId;
    if (match == null || proposal.amountMinor <= 0) {
      throw InboxError(
        InboxErrorCode.invalidProposal,
        itemId: planned.loaded.row.id,
      );
    }
    await _insertPayment(planned, proposal, operationId, now);
    final original = await _db.customSelect(
      'SELECT currency, deleted_at FROM transactions WHERE id = ?',
      variables: <Variable<Object>>[Variable(match)],
    ).getSingleOrNull();
    if (original == null ||
        original.data['deleted_at'] != null ||
        original.data['currency'] != proposal.currency) {
      throw InboxError(
        InboxErrorCode.invalidProposal,
        itemId: planned.loaded.row.id,
      );
    }
    await _db.customStatement(
      'INSERT INTO refund_links (id, created_at, updated_at, deleted_at, '
      'revision, refund_transaction_id, original_transaction_id, '
      'amount_minor, currency) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?)',
      <Object?>[
        planned.linkId!,
        now,
        now,
        planned.transactionId,
        match,
        proposal.amountMinor,
        proposal.currency,
      ],
    );
  }

  Future<void> _insertTransfer(
    _PlannedItem planned,
    InboxProposal proposal,
    String operationId,
    int now,
  ) async {
    final match = proposal.matchTransactionId;
    if (match == null) {
      throw InboxError(
        InboxErrorCode.invalidProposal,
        itemId: planned.loaded.row.id,
      );
    }
    final other = await _db.customSelect(
      'SELECT account_id, amount_minor, currency, deleted_at '
      'FROM transactions WHERE id = ?',
      variables: <Variable<Object>>[Variable(match)],
    ).getSingleOrNull();
    final sum = other == null
        ? null
        : BigInt.from(other.data['amount_minor'] as int) +
            BigInt.from(proposal.amountMinor);
    if (other == null ||
        other.data['deleted_at'] != null ||
        other.data['currency'] != proposal.currency ||
        other.data['account_id'] == proposal.accountId ||
        proposal.amountMinor == 0 ||
        sum != BigInt.zero) {
      throw InboxError(
        InboxErrorCode.invalidProposal,
        itemId: planned.loaded.row.id,
      );
    }
    await _insertPayment(planned, proposal, operationId, now);
    final otherIsOut = (other.data['amount_minor'] as int) < 0;
    final sending = otherIsOut ? match : planned.transactionId;
    final receiving = otherIsOut ? planned.transactionId : match;
    await _db.customStatement(
      'INSERT INTO transfer_links (id, created_at, updated_at, deleted_at, '
      'revision, event_id, sending_transaction_id, receiving_transaction_id, '
      'fee_transaction_id) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, NULL)',
      <Object?>[
        planned.linkId!,
        now,
        now,
        planned.eventId,
        sending,
        receiving,
      ],
    );
  }

  Future<void> _validateAccount(
    String accountId,
    String currency,
    int itemId,
  ) async {
    final row = await _db.customSelect(
      'SELECT currency, deleted_at FROM accounts WHERE id = ?',
      variables: <Variable<Object>>[Variable(accountId)],
    ).getSingleOrNull();
    if (row == null ||
        row.data['deleted_at'] != null ||
        row.data['currency'] != currency) {
      throw InboxError(InboxErrorCode.invalidProposal, itemId: itemId);
    }
  }

  Future<void> _validateCategory(String? categoryId, int itemId) async {
    if (categoryId == null) {
      return;
    }
    final row = await _db.customSelect(
      'SELECT deleted_at FROM categories WHERE id = ?',
      variables: <Variable<Object>>[Variable(categoryId)],
    ).getSingleOrNull();
    if (row == null || row.data['deleted_at'] != null) {
      throw InboxError(InboxErrorCode.invalidProposal, itemId: itemId);
    }
  }

  Future<void> _validateTag(String tagId, int itemId) async {
    final row = await _db.customSelect(
      'SELECT deleted_at FROM tags WHERE id = ?',
      variables: <Variable<Object>>[Variable(tagId)],
    ).getSingleOrNull();
    if (row == null || row.data['deleted_at'] != null) {
      throw InboxError(InboxErrorCode.invalidProposal, itemId: itemId);
    }
  }

  String _eventType(String kind) => switch (kind) {
        'income' => 'income',
        'transfer' => 'transfer',
        'refund' => 'refund',
        'fee' => 'fee',
        _ => 'payment',
      };

  // ---------------------------------------------------------------------
  // Undo internals
  // ---------------------------------------------------------------------

  Future<List<_CreatedEntity>> _createdEntities(String operationId) async {
    final rows = await _db.customSelect(
      'SELECT c.entity_id AS id, r.entity_kind AS kind, '
      'c.to_revision AS revision '
      'FROM change_log c JOIN entity_registry r ON r.id = c.entity_id '
      "WHERE c.operation_id = ? AND c.change_kind = 'create' "
      'ORDER BY c.ordinal',
      variables: <Variable<Object>>[Variable(operationId)],
    ).get();
    return <_CreatedEntity>[
      for (final row in rows)
        _CreatedEntity(
          id: row.data['id'] as String,
          kind: row.data['kind'] as String,
          revision: row.data['revision'] as int,
        ),
    ];
  }

  int _countKind(List<_CreatedEntity> rows, String kind) =>
      rows.where((row) => row.kind == kind).length;

  Future<List<String>> _undoBlockers(
    List<_CreatedEntity> created,
    String operationId,
  ) async {
    if (created.isEmpty) {
      return const <String>[];
    }
    final blocked = <String>{};
    final byKind = <String, List<_CreatedEntity>>{};
    for (final row in created) {
      byKind.putIfAbsent(row.kind, () => <_CreatedEntity>[]).add(row);
    }

    for (final entry in byKind.entries) {
      final table = _tableFor(entry.key);
      if (table == null) {
        continue;
      }
      final ids = entry.value.map((row) => row.id).toList();
      final rows = await _db.customSelect(
        'SELECT id, deleted_at, revision FROM $table '
        'WHERE id IN (${_placeholders(ids.length)})',
        variables: <Variable<Object>>[for (final id in ids) Variable(id)],
      ).get();
      final found = <String>{};
      for (final row in rows) {
        final id = row.data['id'] as String;
        found.add(id);
        if (row.data['deleted_at'] != null) {
          blocked.add(id);
        }
      }
      for (final expected in entry.value) {
        if (!found.contains(expected.id)) {
          blocked.add(expected.id);
        }
        for (final row in rows) {
          if (row.data['id'] == expected.id &&
              row.data['revision'] != expected.revision) {
            blocked.add(expected.id);
          }
        }
      }
    }

    final transactions = <String>[
      for (final row in byKind['transactions'] ?? const <_CreatedEntity>[])
        row.id,
    ];
    final createdLinkIds = <String>{
      for (final row in created)
        if (row.kind == 'refund_links' || row.kind == 'transfer_links') row.id,
    };
    final events = <String>[
      for (final row in byKind['financial_events'] ?? const <_CreatedEntity>[])
        row.id,
    ];

    if (transactions.isNotEmpty) {
      final placeholders = _placeholders(transactions.length);
      final settlements = await _db.customSelect(
        'SELECT transaction_id AS id FROM settlement_allocations '
        'WHERE deleted_at IS NULL AND transaction_id IN ($placeholders)',
        variables: <Variable<Object>>[
          for (final id in transactions) Variable(id),
        ],
      ).get();
      for (final row in settlements) {
        blocked.add(row.data['id'] as String);
      }
      final refunds = await _db.customSelect(
        'SELECT id FROM refund_links WHERE deleted_at IS NULL AND '
        '(refund_transaction_id IN ($placeholders) OR '
        'original_transaction_id IN ($placeholders))',
        variables: <Variable<Object>>[
          for (final id in transactions) Variable(id),
          for (final id in transactions) Variable(id),
        ],
      ).get();
      for (final row in refunds) {
        final id = row.data['id'] as String;
        if (!createdLinkIds.contains(id)) {
          blocked.add(id);
        }
      }
      final transfers = await _db.customSelect(
        'SELECT id FROM transfer_links WHERE deleted_at IS NULL AND '
        '(sending_transaction_id IN ($placeholders) OR '
        'receiving_transaction_id IN ($placeholders) OR '
        'fee_transaction_id IN ($placeholders))',
        variables: <Variable<Object>>[
          for (final id in transactions) Variable(id),
          for (final id in transactions) Variable(id),
          for (final id in transactions) Variable(id),
        ],
      ).get();
      for (final row in transfers) {
        final id = row.data['id'] as String;
        if (!createdLinkIds.contains(id)) {
          blocked.add(id);
        }
      }
    }

    if (events.isNotEmpty) {
      final links = await _db.customSelect(
        'SELECT event_id AS id FROM source_event_links '
        'WHERE operation_id <> ? AND '
        'event_id IN (${_placeholders(events.length)})',
        variables: <Variable<Object>>[
          Variable(operationId),
          for (final id in events) Variable(id),
        ],
      ).get();
      for (final row in links) {
        blocked.add(row.data['id'] as String);
      }
    }
    return blocked.toList()..sort();
  }

  Future<void> _applyUndo(
    List<_CreatedEntity> created,
    String originalOperationId,
    String undoOperationId,
  ) async {
    await _db.customStatement('PRAGMA defer_foreign_keys = ON');
    final blocked = await _undoBlockers(created, originalOperationId);
    if (blocked.isNotEmpty) {
      throw InboxError(
        InboxErrorCode.undoBlocked,
        blockedIds: List<String>.unmodifiable(blocked),
      );
    }
    final now = _nowMs();
    final accounts = <String>{};
    for (final row in created) {
      final table = _tableFor(row.kind);
      if (table == null) {
        continue;
      }
      if (row.kind == 'transactions') {
        final account = await _db.customSelect(
          'SELECT account_id FROM transactions WHERE id = ?',
          variables: <Variable<Object>>[Variable(row.id)],
        ).getSingleOrNull();
        if (account != null) {
          accounts.add(account.data['account_id'] as String);
        }
      }
      await _db.customStatement(
        'UPDATE $table SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ? AND deleted_at IS NULL',
        <Object?>[now, now, row.id],
      );
    }

    final transactionIds = <String>[
      for (final row in created)
        if (row.kind == 'transactions') row.id,
    ];
    for (final id in transactionIds) {
      await _db.customStatement(
        'DELETE FROM transaction_tags WHERE transaction_id = ?',
        <Object?>[id],
      );
    }
    await _db.customStatement(
      'DELETE FROM source_event_links WHERE operation_id = ?',
      <Object?>[originalOperationId],
    );
    await _db.customStatement(
      'UPDATE source_claims SET status = ?, decided_operation_id = ? '
      'WHERE decided_operation_id = ? AND status = ?',
      <Object?>['undone', undoOperationId, originalOperationId, 'accepted'],
    );
    for (final accountId in accounts) {
      await _bumpAccountRevision(accountId);
    }
  }

  String? _tableFor(String kind) => switch (kind) {
        'financial_events' => 'financial_events',
        'transactions' => 'transactions',
        'transaction_splits' => 'transaction_splits',
        'refund_links' => 'refund_links',
        'transfer_links' => 'transfer_links',
        _ => null,
      };

  // ---------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------

  Future<({String dbEpoch, int inboxRevision})> _dbState() async {
    final row = await _db
        .customSelect(
          'SELECT db_epoch, inbox_revision FROM db_state WHERE singleton = 1',
        )
        .getSingle();
    return (
      dbEpoch: row.data['db_epoch'] as String,
      inboxRevision: row.data['inbox_revision'] as int,
    );
  }

  Future<void> _bumpInboxRevision() async {
    await _db.customStatement(
      'UPDATE db_state SET inbox_revision = inbox_revision + 1 '
      'WHERE singleton = 1',
    );
  }

  Future<void> _bumpAccountRevision(String accountId) async {
    await _db.customStatement(
      'INSERT INTO dependency_scopes (kind, scope_key) '
      'SELECT ?, ? WHERE NOT EXISTS ('
      'SELECT 1 FROM dependency_scopes WHERE kind = ? AND scope_key = ?)',
      <Object?>['account', accountId, 'account', accountId],
    );
    await _db.customStatement(
      'UPDATE dependency_revisions SET revision = revision + 1 '
      'WHERE scope_id = (SELECT id FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      <Object?>['account', accountId],
    );
    await _db.customStatement(
      'INSERT INTO dependency_revisions (scope_id, revision) '
      'SELECT id, 1 FROM dependency_scopes WHERE kind = ? AND scope_key = ? '
      'AND NOT EXISTS (SELECT 1 FROM dependency_revisions '
      'WHERE scope_id = dependency_scopes.id)',
      <Object?>['account', accountId],
    );
  }

  Future<List<_LoadedItem>> _loadPending(
    List<int> ids, {
    bool allowMissing = false,
  }) async {
    if (ids.isEmpty) {
      return const <_LoadedItem>[];
    }
    final sorted = <int>[...ids]..sort();
    final rows = await _db.customSelect(
      'SELECT p.id, p.source_identity_id, p.staged_row_id, p.received_at, '
      'p.suggestion_type, p.payload_schema_version, p.proposed_json, '
      'p.decision, p.edit_revision, p.operation_id, '
      'c.status AS claim_status, c.batch_id, c.draft_id, '
      'b.inbox_published, b.status AS batch_status, '
      's.batch_id AS staged_batch_id, '
      's.source_identity_id AS staged_source_identity_id, '
      'd.form_type AS draft_form_type '
      'FROM inbox_items p '
      'LEFT JOIN source_claims c '
      'ON c.source_identity_id = p.source_identity_id '
      'LEFT JOIN staged_rows s ON s.id = p.staged_row_id '
      'LEFT JOIN import_batches b ON b.id = c.batch_id '
      'LEFT JOIN draft_headers d ON d.id = c.draft_id '
      'WHERE p.id IN (${_placeholders(sorted.length)}) '
      'ORDER BY p.received_at, p.id',
      variables: <Variable<Object>>[for (final id in sorted) Variable(id)],
    ).get();
    if (rows.isEmpty) {
      if (allowMissing) {
        return const <_LoadedItem>[];
      }
      throw InboxError(InboxErrorCode.notEligible, itemId: sorted.first);
    }
    final loaded = <_LoadedItem>[];
    for (final row in rows) {
      final raw = _RawInboxRow.from(row);
      if (raw.decision != 'pending' ||
          raw.proposalJson == null ||
          raw.payloadSchemaVersion != InboxProposal.schemaVersion ||
          !_isVisible(raw)) {
        if (allowMissing) {
          continue;
        }
        throw InboxError(InboxErrorCode.notEligible, itemId: raw.id);
      }
      final decoded = jsonDecode(raw.proposalJson!);
      final proposal = InboxProposal.fromJson(decoded);
      loaded.add(
        _LoadedItem(
          row: InboxItemRow(
            id: raw.id,
            sourceIdentityId: raw.sourceIdentityId,
            stagedRowId: raw.stagedRowId,
            receivedAtMs: raw.receivedAtMs,
            suggestionType: raw.suggestionType,
            editRevision: raw.editRevision,
          ),
          proposal: proposal,
          source: raw.batchId != null
              ? 'imported'
              : (raw.draftFormType == 'capture' ? 'captured' : 'manual'),
        ),
      );
    }
    return loaded;
  }

  Future<_LoadedItem?> _loadOne(int id) async {
    final rows = await _loadPending(<int>[id], allowMissing: true);
    return rows.isEmpty ? null : rows.single;
  }

  bool _isVisible(_RawInboxRow row) {
    if (row.claimStatus != 'staged') {
      return false;
    }
    if (row.draftId != null && row.batchId == null) {
      return row.stagedRowId == null;
    }
    if (row.batchId != null) {
      return row.inboxPublished == 1 &&
          row.batchStatus == 'review' &&
          (row.stagedRowId == null ||
              (row.stagedBatchId == row.batchId &&
                  row.stagedSourceIdentityId == row.sourceIdentityId));
    }
    return false;
  }

  String _placeholders(int count) => List<String>.filled(count, '?').join(', ');

  String _nextId() {
    final injected = _newEntityId;
    if (injected != null) {
      return injected();
    }
    final random = Random.secure();
    final bytes = List<int>.generate(10, (_) => random.nextInt(256));
    return UuidV7.generate(
      unixMillis: _nowMs(),
      randomBytes: bytes,
    ).toString();
  }
}

final BigInt _maxMinor = BigInt.parse('9223372036854775807');
final BigInt _minMinor = BigInt.parse('-9223372036854775808');

enum _Outcome { payment, mergeLink, refundLink, transferLink }

final class _LoadedItem {
  const _LoadedItem({
    required this.row,
    required this.proposal,
    required this.source,
  });

  final InboxItemRow row;
  final InboxProposal proposal;

  /// The ledger source token: an import batch is `imported`, a capture draft
  /// is `captured`, and any other draft claim is `manual`.
  final String source;
}

final class _PlannedItem {
  const _PlannedItem({
    required this.loaded,
    required this.outcome,
    required this.eventId,
    required this.transactionId,
    required this.splitIds,
    required this.linkId,
  });

  final _LoadedItem loaded;
  final _Outcome outcome;
  final String eventId;
  final String transactionId;
  final List<String> splitIds;
  final String? linkId;

  bool get createsPayment => outcome != _Outcome.mergeLink;
}

final class _BatchPlan {
  const _BatchPlan({required this.entries, required this.changes});

  final List<_PlannedItem> entries;
  final List<ChangeLogEntry> changes;
}

final class _CreatedEntity {
  const _CreatedEntity({
    required this.id,
    required this.kind,
    required this.revision,
  });

  final String id;
  final String kind;
  final int revision;
}

final class _RawInboxRow {
  const _RawInboxRow({
    required this.id,
    required this.sourceIdentityId,
    required this.stagedRowId,
    required this.receivedAtMs,
    required this.suggestionType,
    required this.payloadSchemaVersion,
    required this.proposalJson,
    required this.decision,
    required this.editRevision,
    required this.claimStatus,
    required this.batchId,
    required this.draftId,
    required this.inboxPublished,
    required this.batchStatus,
    required this.stagedBatchId,
    required this.stagedSourceIdentityId,
    required this.draftFormType,
  });

  final int id;
  final int sourceIdentityId;
  final int? stagedRowId;
  final int receivedAtMs;
  final String suggestionType;
  final int payloadSchemaVersion;
  final String? proposalJson;
  final String decision;
  final int editRevision;
  final String? claimStatus;
  final String? batchId;
  final String? draftId;
  final int? inboxPublished;
  final String? batchStatus;
  final String? stagedBatchId;
  final int? stagedSourceIdentityId;
  final String? draftFormType;

  factory _RawInboxRow.from(QueryRow row) => _RawInboxRow(
        id: row.data['id'] as int,
        sourceIdentityId: row.data['source_identity_id'] as int,
        stagedRowId: row.data['staged_row_id'] as int?,
        receivedAtMs: row.data['received_at'] as int,
        suggestionType: row.data['suggestion_type'] as String,
        payloadSchemaVersion: row.data['payload_schema_version'] as int,
        proposalJson: row.data['proposed_json'] as String?,
        decision: row.data['decision'] as String,
        editRevision: row.data['edit_revision'] as int,
        claimStatus: row.data['claim_status'] as String?,
        batchId: row.data['batch_id'] as String?,
        draftId: row.data['draft_id'] as String?,
        inboxPublished: row.data['inbox_published'] as int?,
        batchStatus: row.data['batch_status'] as String?,
        stagedBatchId: row.data['staged_batch_id'] as String?,
        stagedSourceIdentityId: row.data['staged_source_identity_id'] as int?,
        draftFormType: row.data['draft_form_type'] as String?,
      );
}
