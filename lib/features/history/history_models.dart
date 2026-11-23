// P29 (SCREENS C06; SPEC 8.18): the activity history contract.
//
// An entry is one confirmed operation. Its state is reversible, reversed or a
// change that Undo does not reverse (a settings, category or rule change).
// Undo is one new command with its own receipt; it never rewrites the original
// row.
library;

/// The state of one history entry.
enum HistoryEntryState {
  /// Undo can still run.
  reversible,

  /// A compensating command already ran.
  reversed,

  /// A change that is corrected by editing it again (no Undo).
  change,
}

/// One row of C06.
final class HistoryEntry {
  const HistoryEntry({
    required this.operationId,
    required this.commandType,
    required this.committedAtMs,
    required this.state,
  });

  final String operationId;
  final String commandType;
  final int committedAtMs;
  final HistoryEntryState state;
}

/// The history port.
abstract interface class HistoryGateway {
  Future<List<HistoryEntry>> load();

  /// Runs the one compensating command for [entry]. Returns true on success.
  Future<bool> undo(HistoryEntry entry);
}

/// Safe failure codes (no amount, name or id in the text).
enum HistoryErrorCode { notWired, loadFailed, undoFailed }

class HistoryError implements Exception {
  const HistoryError(this.code);

  final HistoryErrorCode code;

  @override
  String toString() => 'HistoryError(${code.name})';
}

/// The placeholder gateway before the vault is mounted.
final class UnavailableHistoryGateway implements HistoryGateway {
  const UnavailableHistoryGateway();

  @override
  Future<List<HistoryEntry>> load() async => const <HistoryEntry>[];

  @override
  Future<bool> undo(HistoryEntry entry) async =>
      throw const HistoryError(HistoryErrorCode.notWired);
}
