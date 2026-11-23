// T07 (SHARED_STATE 3): the read revision.
//
// `db_state.read_revision` orders committed visible-state publications. It
// advances by one per such transaction, never wraps, and is read in the same
// transaction that commits the change. Exhaustion fails explicitly.
library;

import 'app_database.dart';

/// Reads the current `read_revision` from the `db_state` singleton.
Future<int> currentReadRevision(AppDatabase db) async {
  final rows = await db
      .customSelect('SELECT read_revision FROM db_state WHERE singleton = 1')
      .get();
  if (rows.isEmpty) {
    throw StateError('vault state missing');
  }
  return rows.first.data['read_revision'] as int;
}

/// Advances the read revision by exactly one inside the caller's transaction.
/// Returns the new value. Fails explicitly before wrapping.
Future<int> advanceReadRevision(AppDatabase db) async {
  final current = await currentReadRevision(db);
  if (current == 0x7fffffffffffffff) {
    throw StateError('read revision exhausted');
  }
  await db.customStatement(
    'UPDATE db_state SET read_revision = read_revision + 1 WHERE singleton = 1',
  );
  return current + 1;
}

/// Reads the current authored commit sequence.
Future<int> currentCommitSequence(AppDatabase db) async {
  final rows = await db
      .customSelect('SELECT commit_sequence FROM db_state WHERE singleton = 1')
      .get();
  if (rows.isEmpty) {
    throw StateError('vault state missing');
  }
  return rows.first.data['commit_sequence'] as int;
}

/// Advances the authored commit sequence by exactly one inside the caller's
/// transaction. Returns the new value.
Future<int> advanceCommitSequence(AppDatabase db) async {
  final current = await currentCommitSequence(db);
  if (current == 0x7fffffffffffffff) {
    throw StateError('commit sequence exhausted');
  }
  await db.customStatement(
    'UPDATE db_state SET commit_sequence = commit_sequence + 1 WHERE singleton = 1',
  );
  return current + 1;
}
