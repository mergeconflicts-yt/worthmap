// P25 (flow F07; SPEC 5.5, 8.18): the X60 Inbox state.
//
// Loads one page, ticks the ready rows, holds at most one open decision, and
// confirms once. The confirm label reads the gateway's exact totals (F07-B).
// Uncertainty stays unticked (F07-A). Nothing is written outside
// `ConfirmInboxBatch`; a decision only stages (SPEC 8.17).
library;

import 'package:flutter/foundation.dart';

import 'inbox_models.dart';

/// The list lifecycle.
enum InboxViewState { loading, ready, failed }

/// The Inbox list and its confirmation state.
final class InboxController extends ChangeNotifier {
  InboxController({required this.gateway});

  final InboxGateway gateway;

  InboxViewState _state = InboxViewState.loading;
  List<InboxRow> _rows = const <InboxRow>[];
  int _pendingCount = 0;
  InboxDecision? _decision;
  final Set<int> _decided = <int>{};
  final Set<int> _ticked = <int>{};
  InboxTotals? _totals;
  InboxViewErrorCode? _errorCode;
  bool _confirming = false;

  InboxViewState get state => _state;
  List<InboxRow> get rows => List<InboxRow>.unmodifiable(_rows);
  int get pendingCount => _pendingCount;
  InboxDecision? get decision => _decision;
  Set<int> get ticked => Set<int>.unmodifiable(_ticked);
  InboxTotals? get totals => _totals;
  InboxViewErrorCode? get errorCode => _errorCode;
  bool get confirming => _confirming;

  /// A decision is open until the person answers it (SPEC 5.5).
  bool get decisionOpen =>
      _decision != null && !_decided.contains(_decision!.itemId);

  /// X60: the ready rows (a decision candidate is not ticked).
  List<InboxRow> get readyRows => <InboxRow>[
        for (final row in _rows)
          if (!row.needsDecision && !row.isUnsure) row,
      ];

  /// The rows that a confirm can include: ticked, not unsure, not a decision.
  int get tickedCount => _ticked.length;

  /// True when the confirm bar can act: no open decision and a ticked row.
  bool get canConfirm => !_confirming && !decisionOpen && _ticked.isNotEmpty;

  /// Reads the first page. A failed read keeps the factual empty list.
  Future<void> load() async {
    _state = InboxViewState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      final page = await gateway.loadPage();
      _rows = page.rows;
      _pendingCount = page.pendingCount;
      _decision = page.decision;
      _ticked
        ..clear()
        ..addAll(
          <int>{
            for (final row in page.rows)
              if (!row.needsDecision && !row.isUnsure) row.id,
          },
        );
      _decided.clear();
      _state = InboxViewState.ready;
      await refreshTotals();
    } on Object {
      _rows = const <InboxRow>[];
      _pendingCount = 0;
      _totals = null;
      _state = InboxViewState.failed;
      _errorCode = InboxViewErrorCode.loadFailed;
      notifyListeners();
    }
  }

  /// One checkbox tap. An unsure row is never ticked (F07-A).
  Future<void> toggle(int id) async {
    final row = _rowById(id);
    if (row == null || row.isUnsure || row.needsDecision) {
      return;
    }
    if (!_ticked.remove(id)) {
      _ticked.add(id);
    }
    notifyListeners();
    await refreshTotals();
  }

  /// X61: the item sheet returns a changed tick state.
  Future<void> setTicked(int id, bool value) async {
    final row = _rowById(id);
    if (row == null || row.isUnsure || row.needsDecision) {
      return;
    }
    if (value) {
      _ticked.add(id);
    } else {
      _ticked.remove(id);
    }
    notifyListeners();
    await refreshTotals();
  }

  /// F07-B: the exact totals of the ticked set.
  Future<void> refreshTotals() async {
    if (_ticked.isEmpty) {
      _totals = null;
      notifyListeners();
      return;
    }
    try {
      _totals = await gateway.totals(_ticked);
    } on Object {
      _totals = null;
    }
    notifyListeners();
  }

  /// Accepts or rejects the open decision. A rejection keeps the row out of
  /// the ticked set; no second payment is invented (P17).
  Future<void> decide(bool accept) async {
    final current = _decision;
    if (current == null || !decisionOpen) {
      return;
    }
    try {
      await gateway.decide(
        itemId: current.itemId,
        expectedRevision: current.editRevision,
        accept: accept,
      );
      _decided.add(current.itemId);
      if (accept) {
        _ticked.add(current.itemId);
      } else {
        _ticked.remove(current.itemId);
      }
      _nextDecision();
      notifyListeners();
      await refreshTotals();
    } on InboxViewError catch (error) {
      _errorCode = error.code;
      notifyListeners();
    }
  }

  void _nextDecision() {
    for (final row in _rows) {
      if (row.needsDecision && !_decided.contains(row.id)) {
        _decision = InboxDecision(
          itemId: row.id,
          editRevision: row.editRevision,
          fromName: row.accountName ?? '',
          toName: row.matchName ?? '',
          amountMinor: row.amountMinor,
          currencyCode: row.currencyCode,
          date: row.date,
        );
        return;
      }
    }
    _decision = null;
  }

  /// `ConfirmInboxBatch` for the ticked rows. Returns the committed result so
  /// the screen can show the 5 s toast with Undo; null on a failure.
  Future<InboxConfirmation?> confirm() async {
    if (!canConfirm) {
      return null;
    }
    _confirming = true;
    _errorCode = null;
    notifyListeners();
    try {
      final confirmation = await gateway.confirm(_ticked);
      _confirming = false;
      await load();
      return confirmation;
    } on InboxViewError catch (error) {
      _confirming = false;
      _errorCode = error.code;
      notifyListeners();
      return null;
    } on Object {
      _confirming = false;
      _errorCode = InboxViewErrorCode.confirmFailed;
      notifyListeners();
      return null;
    }
  }

  /// SPEC 8.18: one compensating command for the whole batch.
  Future<void> undo(InboxConfirmation confirmation) async {
    try {
      await gateway.undoBatch(confirmation.operationId);
      await load();
    } on Object {
      // The records stay; the list shows their current state.
    }
  }

  /// X61 Delete: removes the staged item; no payment exists yet.
  Future<void> deleteRow(InboxRow row) async {
    try {
      await gateway.deleteStaged(
        itemId: row.id,
        editRevision: row.editRevision,
      );
      _rows = <InboxRow>[
        for (final item in _rows)
          if (item.id != row.id) item,
      ];
      _ticked.remove(row.id);
      _decided.remove(row.id);
      if (_decision?.itemId == row.id) {
        _nextDecision();
      }
      _pendingCount = _pendingCount > 0 ? _pendingCount - 1 : 0;
      notifyListeners();
      await refreshTotals();
    } on InboxViewError catch (error) {
      _errorCode = error.code;
      notifyListeners();
    }
  }

  InboxRow? _rowById(int id) {
    for (final row in _rows) {
      if (row.id == id) {
        return row;
      }
    }
    return null;
  }
}
