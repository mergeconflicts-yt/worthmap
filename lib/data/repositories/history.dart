// P29 (SPEC 8.18; SYSTEM_DESIGN 6): the activity history read.
//
// A history entry is a committed operation receipt with its command type and
// result. It shows what happened and whether Undo is still possible. The read
// writes nothing and holds no source text.

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// One committed operation of the history.
final class HistoryOperationRow {
  const HistoryOperationRow({
    required this.operationId,
    required this.commandType,
    required this.committedAtMs,
    required this.resultJson,
    required this.compensated,
  });

  final String operationId;
  final String commandType;
  final int committedAtMs;
  final String resultJson;

  /// True when another receipt names this operation as its target.
  final bool compensated;
}

/// The history read.
final class HistoryRepository {
  HistoryRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  /// Committed operations, newest first.
  Future<List<HistoryOperationRow>> list({int limit = 100}) async {
    final rows = await _db.customSelect(
      'SELECT r.operation_id, i.command_type, r.committed_at, r.result_json, '
      'CASE WHEN c.operation_id IS NULL THEN 0 ELSE 1 END AS compensated '
      'FROM operation_receipts r '
      'JOIN operation_intents i ON i.operation_id = r.operation_id '
      'LEFT JOIN operation_receipts c '
      'ON c.compensates_operation_id = r.operation_id '
      'ORDER BY r.commit_sequence DESC LIMIT ?',
      variables: <Variable<Object>>[Variable(limit)],
    ).get();
    return <HistoryOperationRow>[
      for (final row in rows)
        HistoryOperationRow(
          operationId: row.data['operation_id'] as String,
          commandType: row.data['command_type'] as String,
          committedAtMs: row.data['committed_at'] as int,
          resultJson: row.data['result_json'] as String,
          compensated: (row.data['compensated'] as int) == 1,
        ),
    ];
  }

  /// True when the payment row is soft-deleted.
  Future<bool> paymentDeleted(String id) async {
    final row = await _db.customSelect(
      'SELECT deleted_at FROM transactions WHERE id = ?',
      variables: <Variable<Object>>[Variable(id)],
    ).getSingleOrNull();
    return row == null || row.data['deleted_at'] != null;
  }

  /// True when the financial event is soft-deleted.
  Future<bool> eventDeleted(String id) async {
    final row = await _db.customSelect(
      'SELECT deleted_at FROM financial_events WHERE id = ?',
      variables: <Variable<Object>>[Variable(id)],
    ).getSingleOrNull();
    return row == null || row.data['deleted_at'] != null;
  }
}
