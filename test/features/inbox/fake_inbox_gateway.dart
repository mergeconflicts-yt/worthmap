import 'package:contour/core/dates.dart';
import 'package:contour/features/inbox/inbox_models.dart';

/// An in-memory Inbox port for the P25 tests. It writes no database.
final class FakeInboxGateway implements InboxGateway {
  FakeInboxGateway({
    List<InboxRow>? rows,
    this.pendingCount,
    this.decision,
  }) : rows = rows ?? _defaultRows();

  static List<InboxRow> _defaultRows() => <InboxRow>[
        InboxRow(
          id: 1,
          title: 'Starbucks',
          source: 'notification',
          date: _day,
          amountMinor: -640,
          currencyCode: 'USD',
          editRevision: 1,
          suggestion: 'new',
          categoryName: 'Coffee',
          accountName: 'Visa card',
        ),
        InboxRow(
          id: 2,
          title: 'PX Market',
          source: 'statement',
          date: _day,
          amountMinor: -3175,
          currencyCode: 'USD',
          editRevision: 1,
          suggestion: 'new',
          categoryName: null,
          accountName: 'Checking',
          isUnsure: true,
        ),
        InboxRow(
          id: 3,
          title: 'Visa card',
          source: 'notification',
          date: _day,
          amountMinor: -124000,
          currencyCode: 'USD',
          editRevision: 4,
          suggestion: 'transfer',
          categoryName: null,
          accountName: 'Checking',
          matchName: 'Visa card',
        ),
        InboxRow(
          id: 4,
          title: 'Whole Foods',
          source: 'notification',
          date: _day,
          amountMinor: -4218,
          currencyCode: 'USD',
          editRevision: 1,
          suggestion: 'new',
          categoryName: 'Groceries',
          accountName: 'Visa card',
        ),
      ];

  static final LocalDate _day = LocalDate(2026, 10, 22);

  List<InboxRow> rows;
  int? pendingCount;
  InboxDecision? decision;

  final List<Set<int>> confirmed = <Set<int>>[];
  final List<bool> decisions = <bool>[];
  final List<int> deleted = <int>[];
  int undoCount = 0;
  int loadCount = 0;
  Object? loadFailure;
  Object? confirmFailure;

  @override
  Future<InboxPageView> loadPage({String? cursor}) async {
    loadCount += 1;
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return InboxPageView(
      rows: rows,
      pendingCount: pendingCount ?? rows.length,
      decision: decision ?? _firstTransfer(rows),
    );
  }

  InboxDecision? _firstTransfer(List<InboxRow> rows) {
    for (final row in rows) {
      if (!row.needsDecision) {
        continue;
      }
      return InboxDecision(
        itemId: row.id,
        editRevision: row.editRevision,
        fromName: row.accountName ?? '',
        toName: row.matchName ?? '',
        amountMinor: row.amountMinor,
        currencyCode: row.currencyCode,
        date: row.date,
      );
    }
    return null;
  }

  @override
  Future<InboxTotals> totals(Set<int> ids) async {
    var count = 0;
    var net = 0;
    for (final row in rows) {
      if (ids.contains(row.id)) {
        count += 1;
        net += row.amountMinor;
      }
    }
    return InboxTotals(count: count, netMinor: net, currencyCode: 'USD');
  }

  @override
  Future<void> decide({
    required int itemId,
    required int expectedRevision,
    required bool accept,
  }) async {
    decisions.add(accept);
    decision = null;
  }

  @override
  Future<InboxConfirmation> confirm(Set<int> ids) async {
    final failure = confirmFailure;
    if (failure != null) {
      throw failure;
    }
    confirmed.add(Set<int>.from(ids));
    final totals = await this.totals(ids);
    rows = <InboxRow>[
      for (final row in rows)
        if (!ids.contains(row.id)) row,
    ];
    pendingCount = rows.length;
    return InboxConfirmation(
      operationId: 'operation-${confirmed.length}',
      batchId: 'batch-${confirmed.length}',
      count: totals.count,
      currencyCode: totals.currencyCode,
      netMinor: totals.netMinor,
    );
  }

  @override
  Future<void> undoBatch(String operationId) async {
    undoCount += 1;
  }

  @override
  Future<void> deleteStaged({
    required int itemId,
    required int editRevision,
  }) async {
    deleted.add(itemId);
    rows = <InboxRow>[
      for (final row in rows)
        if (row.id != itemId) row,
    ];
    pendingCount = rows.length;
  }
}
