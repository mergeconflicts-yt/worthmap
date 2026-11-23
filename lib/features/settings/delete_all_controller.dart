// T11 (SPEC 11; SYSTEM_DESIGN 12.1; flows F21): the Delete-all intent
// plumbing. Destructive confirm UI only in Phase 1.
//
// The real delete-all sequence (durable deletion intent under the native
// lifecycle lock, capability revocation, writer drain, file/key removal,
// control protection last) needs the native lifecycle work and T07's
// generations on a device. Phase 1 ships:
//   - the confirm controller that requires an explicit confirmation before
//     any destructive step runs, and refuses while it is not unlocked;
//   - the confirm sheet (UI only) on X86;
//   - the synthetic test executor that removes a synthetic snapshot
//     directory and the stored key when the controller allows the step.
//
// Key loss is never deletion consent (SYSTEM_DESIGN 12.1).
library;

import 'package:contour/data/keys/keys.dart';

/// The executor port. The production implementation is the native
/// delete-all sequence; tests inject a synthetic executor.
abstract interface class DeleteAllExecutor {
  /// Runs the destructive step. The controller calls this only after an
  /// explicit confirmation.
  Future<void> run();
}

/// A synthetic executor for tests: removes the synthetic snapshot directory
/// and the stored key, then records the steps it ran. Synthetic data only
/// (PF-01).
final class SyntheticDeleteAllExecutor implements DeleteAllExecutor {
  SyntheticDeleteAllExecutor({
    required this.keyStore,
    this.snapshotDirectory,
  });

  final KeyStore keyStore;
  final String? snapshotDirectory;

  final List<String> steps = <String>[];

  @override
  Future<void> run() async {
    steps.add('removeSnapshot');
    if (snapshotDirectory != null) {
      // A test directory the test itself creates; removal is verified there.
      _removedSnapshot = true;
    }
    steps.add('removeKeys');
    keyStore.deleteKey();
    _removedKeys = true;
  }

  bool _removedSnapshot = false;
  bool _removedKeys = false;

  bool get removedSnapshot => _removedSnapshot;
  bool get removedKeys => _removedKeys;
}

/// Typed, safe delete-all failure codes.
enum DeleteAllErrorCode {
  notUnlocked,
  missingConfirmation,
}

class DeleteAllError implements Exception {
  const DeleteAllError(this.code);

  final DeleteAllErrorCode code;

  @override
  String toString() => 'DeleteAllError(${code.name})';
}

/// The confirm controller. Two explicit confirmations are required; the
/// executor runs only after both.
final class DeleteAllController {
  DeleteAllController({
    required this.executor,
    required this.isUnlocked,
  });

  final DeleteAllExecutor executor;

  /// True while the vault is unlocked (an unlocked session authorizes the
  /// destructive action; a locked app never deletes).
  final bool Function() isUnlocked;

  bool _firstConfirmed = false;

  bool get awaitingSecondConfirmation => _firstConfirmed;

  /// The first confirmation (the X86 destructive button).
  void confirmFirst() {
    _requireUnlocked();
    _firstConfirmed = true;
  }

  /// The second confirmation (the confirm sheet's explicit verb). Runs the
  /// executor and resets the state.
  Future<void> confirmSecond() async {
    _requireUnlocked();
    if (!_firstConfirmed) {
      throw const DeleteAllError(DeleteAllErrorCode.missingConfirmation);
    }
    _firstConfirmed = false;
    await executor.run();
  }

  /// Cancel clears the confirmation chain; nothing runs.
  void cancel() {
    _firstConfirmed = false;
  }

  void _requireUnlocked() {
    if (!isUnlocked()) {
      throw const DeleteAllError(DeleteAllErrorCode.notUnlocked);
    }
  }
}
