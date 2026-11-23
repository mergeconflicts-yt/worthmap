// P12: a prepared write for the single command writer.
//
// A repository returns the rows it will write (as ChangeLog entries) and a
// closure that writes them inside the caller's transaction. The command
// writer freezes the entries and calls `apply` as its effect
// (DATABASE_DESIGN 6).

import '../db/command_repository.dart';

/// A prepared write: the ChangeLog entries and the effect.
final class WritePlan {
  WritePlan({required this.changes, required this.apply});

  /// One entry per authored row the plan creates, edits or soft-deletes.
  final List<ChangeLogEntry> changes;

  /// Runs inside the command's write transaction.
  final Future<void> Function() apply;
}
