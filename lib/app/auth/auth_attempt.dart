// T08 (SYSTEM_DESIGN 12.3): one authentication attempt.
//
// Every native attempt carries a fresh attempt id, owner instance, install
// epoch, database epoch and control-policy revision. The admission recheck
// compares the full tuple; a mismatch revokes the attempt.
library;

import 'package:contour/core/ids.dart';

/// One current authentication attempt.
final class AuthAttempt {
  AuthAttempt({
    required this.attemptId,
    required this.ownerInstance,
    required this.installEpoch,
    required this.databaseEpoch,
    required this.policyRevision,
  });

  /// A fresh UUID per attempt (owner-issued; never reused).
  final UuidV7 attemptId;

  /// The owner instance identity of this process run.
  final String ownerInstance;

  /// The install epoch from the key store.
  final int installEpoch;

  /// The database epoch from `db_state`.
  final String databaseEpoch;

  /// The control-policy revision the attempt was opened under.
  final int policyRevision;

  /// True when the tuple still matches a freshly observed tuple. The
  /// admission check calls this again immediately before opening keys and
  /// connections (SYSTEM_DESIGN 12.3).
  bool matches({
    required String ownerInstance,
    required int installEpoch,
    required String databaseEpoch,
    required int policyRevision,
  }) {
    return this.ownerInstance == ownerInstance &&
        this.installEpoch == installEpoch &&
        this.databaseEpoch == databaseEpoch &&
        this.policyRevision == policyRevision;
  }
}
