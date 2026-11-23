// T11 (SPEC 11; SYSTEM_DESIGN 12.2): the backup and transfer exclusion
// stub.
//
// The device work (Android no-backup + explicit cloud/transfer exclusions
// per OS version; iOS backup exclusion on every protected path) is
// implemented in `backup_exclusions_native.dart` with the native handlers
// in ios/Runner and android/.../MainActivity.kt. Device evidence (S01
// backup/transfer proof) stays open, and PF-01 stays open: exclusion flags
// and device tests cannot prove universal phone confinement. The stub
// below records the required exclusion claims per path kind so the policy
// is testable and the composition can fall back to a verified-only state.
//
// No path here ever holds user text, amounts or original filenames; path
// kinds are structural tokens only (AGENTS 2.6).
library;

/// The protected path kinds (SYSTEM_DESIGN 12.2).
enum ProtectedPathKind {
  databaseGeneration,
  staging,
  attachments,
  recovery,
  appGroup,
}

/// The exclusion flags port. The native implementation returns the OS-level
/// truth (allowBackup=false plus per-transfer exclusions, backup exclusion
/// markers after every creation); the stub records the claims in memory.
abstract interface class BackupExclusions {
  /// Records the exclusion claim for a path kind. Idempotent.
  void exclude(ProtectedPathKind kind);

  /// True when the exclusion claim is recorded.
  bool isExcluded(ProtectedPathKind kind);

  /// Every recorded exclusion kind, for the startup verification.
  Set<ProtectedPathKind> get recorded;
}

/// The Phase 1 stub. Records claims in memory only; no OS call is made.
///
/// DECISION-PENDING: PF-01. No real-user persistence claim is possible on
/// this path; the stub exists so Phase 1 prototypes with synthetic data
/// carry the exclusion policy shape.
final class BackupExclusionsStub implements BackupExclusions {
  final Set<ProtectedPathKind> _recorded = <ProtectedPathKind>{};

  @override
  void exclude(ProtectedPathKind kind) => _recorded.add(kind);

  @override
  bool isExcluded(ProtectedPathKind kind) => _recorded.contains(kind);

  @override
  Set<ProtectedPathKind> get recorded => Set.unmodifiable(_recorded);
}
