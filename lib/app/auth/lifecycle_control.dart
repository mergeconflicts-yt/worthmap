// T08 (SYSTEM_DESIGN 12.3): the device-protected lifecycle control store.
//
// The control store keeps only the lock mode, the policy revision, the
// installation identity and an interrupted-policy-change marker. It is
// outside the replaceable financial generations and contains no financial
// values. Missing, unreadable, unsupported or inconsistent control state
// requires authentication before vault admission; it never defaults to off.
library;

/// The app-lock modes (SPEC 9.1): immediately, 1 minute (default),
/// 5 minutes, or off.
enum LockMode {
  immediately,
  after1min,
  after5min,
  off;

  /// The default mode for a fresh installation.
  static LockMode get defaultMode => LockMode.after1min;
}

/// The control policy state.
final class ControlPolicy {
  const ControlPolicy({
    required this.mode,
    required this.revision,
    required this.installId,
    required this.pendingTransition,
  });

  /// The current lock mode. Missing state never reads as [LockMode.off].
  final LockMode mode;

  /// Monotonic policy revision; changes only through an explicit recorded
  /// transition.
  final int revision;

  /// The installation identity (opaque token; no financial values).
  final String installId;

  /// A pending (interrupted) mode transition marker, or null.
  final LockMode? pendingTransition;

  ControlPolicy copyWith({
    LockMode? mode,
    int? revision,
    LockMode? pendingTransition,
  }) =>
      ControlPolicy(
        mode: mode ?? this.mode,
        revision: revision ?? this.revision,
        installId: installId,
        pendingTransition: pendingTransition,
      );
}

/// Typed control-store failure codes.
enum ControlStoreErrorCode {
  missing,
  unreadable,
  unsupported,
}

class ControlStoreError implements Exception {
  const ControlStoreError(this.code);

  final ControlStoreErrorCode code;

  @override
  String toString() => 'ControlStoreError(${code.name})';
}

/// The control store port. The device-backed implementation is
/// `FileControlStore` in `file_control_store.dart` (one small protected
/// shared file outside the financial generations; iOS file-protection
/// hardening stays with the S06 evidence gate).
abstract interface class LifecycleControlStore {
  /// The current policy, or [ControlStoreError] when missing/unreadable.
  /// Never substitutes a default.
  ControlPolicy read();

  /// Writes the policy durably before the enforcement copies change.
  void write(ControlPolicy policy);
}

/// In-memory store for tests only (PF-01: synthetic data).
final class InMemoryControlStore implements LifecycleControlStore {
  ControlPolicy? _policy;

  InMemoryControlStore([ControlPolicy? initial]) : _policy = initial;

  @override
  ControlPolicy read() {
    final policy = _policy;
    if (policy == null) {
      throw const ControlStoreError(ControlStoreErrorCode.missing);
    }
    return policy;
  }

  @override
  void write(ControlPolicy policy) => _policy = policy;

  /// Test helper: clears the store to model a missing control state.
  void clear() => _policy = null;
}
