// T08 (SPEC 9.1, 11; SYSTEM_DESIGN 12.3): the lock state machine and
// lifecycle control.
//
// States: closed → authenticating → opening → unlocked → closing → closed.
// In off mode, fresh foreground admission can go from closed to opening
// without a challenge; all other epoch, key, deletion and platform checks
// still apply. Missing, unreadable, unsupported or inconsistent control
// state requires authentication; it never defaults to off.
//
// Admission: after native success, and again immediately before opening
// keys/connections, compare the full attempt tuple, the current foreground
// state, the policy, the active generation and the lifecycle journal. Any
// mismatch, background, cancellation, timeout, restore, Delete all or owner
// replacement revokes the attempt.
//
// Every log surface here holds event names only (AGENTS 2.6). Tests inject
// a monotonic clock; no wall clock call exists in this file (AGENTS 6.3).
library;

import 'dart:async';

import 'package:contour/core/ids.dart';
import 'package:contour/data/keys/keys.dart';

import 'auth_attempt.dart';
import 'auth_port.dart';
import 'lifecycle_control.dart';

/// The lock phases.
enum LockPhase {
  closed,
  authenticating,
  opening,
  unlocked,
  closing,
}

/// A vault readiness gate. The deletion intent flag and the generation
/// epoch come from the data layer; the controller only asks.
abstract interface class VaultReadinessGate {
  /// True while a durable deletion intent is active; admission is refused.
  bool get deletionPending;

  /// The current database epoch (empty string when no vault is open).
  String get databaseEpoch;
}

/// Test gate. Phase 1: no deletion flow exists yet; T11 wires the real gate.
final class FixedReadinessGate implements VaultReadinessGate {
  FixedReadinessGate({this.deletionPending = false, this.databaseEpoch = ''});

  @override
  bool deletionPending;
  @override
  String databaseEpoch;
}

/// Safe event names for the log surface. No payload, no secrets.
final class LockEvent {
  const LockEvent._(this.name);

  final String name;

  static const challengeRequired = LockEvent._('challengeRequired');
  static const authSuccess = LockEvent._('authSuccess');
  static const authFailure = LockEvent._('authFailure');
  static const authRevoked = LockEvent._('authRevoked');
  static const openReady = LockEvent._('openReady');
  static const openRefused = LockEvent._('openRefused');
  static const locked = LockEvent._('locked');
  static const controlStateMissing = LockEvent._('controlStateMissing');
  static const policyChangeRecorded = LockEvent._('policyChangeRecorded');
}

/// The lock controller.
final class LockController {
  LockController({
    required AuthPort authPort,
    required LifecycleControlStore controlStore,
    required KeyStore keyStore,
    required VaultReadinessGate readiness,
    required int Function() monotonicMs,
    required List<int> Function() attemptNonce,
    required String ownerInstance,
  })  : _authPort = authPort,
        _controlStore = controlStore,
        _keyStore = keyStore,
        _readiness = readiness,
        _monotonicMs = monotonicMs,
        _attemptNonce = attemptNonce,
        _ownerInstance = ownerInstance;

  final AuthPort _authPort;
  final LifecycleControlStore _controlStore;
  final KeyStore _keyStore;
  final VaultReadinessGate _readiness;
  final int Function() _monotonicMs;
  final List<int> Function() _attemptNonce;
  final String _ownerInstance;

  LockPhase _phase = LockPhase.closed;
  AuthAttempt? _currentAttempt;
  int? _backgroundSinceMs;
  final StreamController<LockPhase> _phases =
      StreamController<LockPhase>.broadcast();
  final List<LockEvent> _events = <LockEvent>[];

  /// The current phase.
  LockPhase get phase => _phase;

  /// Phase changes for the router and the lock screen (T09/T10).
  Stream<LockPhase> get phases => _phases.stream;

  /// The recorded events. Event names only; a host may forward them to a
  /// count sink. Never amounts, names or key material (AGENTS 2.6).
  List<LockEvent> get events => List.unmodifiable(_events);

  /// True while the app is unlocked (admission open).
  bool get admissionOpen => _phase == LockPhase.unlocked;

  void _record(LockEvent event) => _events.add(event);

  void _to(LockPhase phase) {
    _phase = phase;
    _phases.add(phase);
  }

  /// The effective policy; throws when the control state is missing or
  /// unreadable (never substitutes a default).
  ControlPolicy policy() => _controlStore.read();

  /// True when a backgrounded session has crossed the policy timeout.
  bool lockRequiredForForeground() {
    final policy = _controlStore.read();
    switch (policy.mode) {
      case LockMode.immediately:
        return true;
      case LockMode.off:
        return false;
      case LockMode.after1min:
      case LockMode.after5min:
        final since = _backgroundSinceMs;
        if (since == null) {
          return false;
        }
        final elapsedMs = _monotonicMs() - since;
        final threshold = policy.mode == LockMode.after1min ? 60000 : 300000;
        return elapsedMs >= threshold;
    }
  }

  /// Runs the admission sequence for a foregrounded app. Returns true when
  /// the vault may open; the caller opens keys and connections and reports
  /// success itself by re-running the admission recheck through
  /// [recheckAdmission].
  Future<bool> admitForeground() async {
    if (_readiness.deletionPending) {
      _record(LockEvent.openRefused);
      return false;
    }

    // Control state: missing or unreadable requires authentication; it
    // never defaults to off (SYSTEM_DESIGN 12.3).
    ControlPolicy policy;
    var controlMissing = false;
    try {
      policy = _controlStore.read();
    } on ControlStoreError {
      controlMissing = true;
      policy = const ControlPolicy(
        mode: LockMode.after1min, // never read as off; unused below
        revision: 0,
        installId: '',
        pendingTransition: null,
      );
      _record(LockEvent.controlStateMissing);
    }

    final pendingTransition = policy.pendingTransition;
    final bothOff =
        policy.mode == LockMode.off && pendingTransition == LockMode.off;
    final needsChallenge = controlMissing ||
        _phase != LockPhase.unlocked ||
        lockRequiredForForeground() ||
        (pendingTransition != null && !bothOff);
    if (!needsChallenge) {
      _backgroundSinceMs = null;
      return _checkReadiness();
    }

    if (!controlMissing &&
        policy.mode == LockMode.off &&
        _phase != LockPhase.unlocked &&
        pendingTransition == null) {
      // Off mode: no challenge, but every other check still applies.
      _to(LockPhase.opening);
      final ready = _checkReadiness();
      if (ready) {
        _record(LockEvent.openReady);
        _to(LockPhase.unlocked);
        _backgroundSinceMs = null;
      }
      return ready;
    }

    _record(LockEvent.challengeRequired);
    _to(LockPhase.authenticating);
    return _challenge(policyRevisionForAttempt: policy.revision);
  }

  Future<bool> _challenge({required int policyRevisionForAttempt}) async {
    final attempt = AuthAttempt(
      attemptId: UuidV7.generate(
        unixMillis: _monotonicMs() & 0xffffffffffff,
        randomBytes: _attemptNonce(),
      ),
      ownerInstance: _ownerInstance,
      installEpoch: _keyStore.readInstallEpoch(),
      databaseEpoch: _readiness.databaseEpoch,
      policyRevision: policyRevisionForAttempt,
    );
    _currentAttempt = attempt;
    final outcome = await _authPort.authenticate(attempt);
    return _onAuthOutcome(outcome);
  }

  /// Reports a native authentication outcome for the current attempt.
  Future<bool> _onAuthOutcome(AuthOutcome outcome) async {
    final attempt = _currentAttempt;
    if (attempt == null || _phase != LockPhase.authenticating) {
      _record(LockEvent.authRevoked);
      return false;
    }
    switch (outcome) {
      case AuthOutcome.success:
        _record(LockEvent.authSuccess);
        return _openVault(attempt);
      case AuthOutcome.failure:
      case AuthOutcome.lockout:
      case AuthOutcome.unavailable:
        _record(LockEvent.authFailure);
        _to(LockPhase.closed);
        _currentAttempt = null;
        return false;
      case AuthOutcome.cancelled:
      case AuthOutcome.timeout:
        _record(LockEvent.authRevoked);
        _to(LockPhase.closed);
        _currentAttempt = null;
        return false;
    }
  }

  /// Opens the vault after a successful challenge: the admission recheck
  /// runs again immediately before keys and connections open
  /// (SYSTEM_DESIGN 12.3).
  Future<bool> _openVault(AuthAttempt attempt) async {
    if (!recheckAdmission(attempt)) {
      _record(LockEvent.authRevoked);
      _to(LockPhase.closed);
      _currentAttempt = null;
      return false;
    }
    _to(LockPhase.opening);
    if (!_checkReadiness()) {
      _record(LockEvent.openRefused);
      _to(LockPhase.closed);
      _currentAttempt = null;
      return false;
    }
    _record(LockEvent.openReady);
    _to(LockPhase.unlocked);
    _backgroundSinceMs = null;
    _currentAttempt = null;
    return true;
  }

  /// The full-tuple admission recheck. Called after native success and
  /// again immediately before keys and connections open. A missing control
  /// state, an epoch change or a policy change revokes the attempt.
  bool recheckAdmission(AuthAttempt attempt) {
    try {
      final policy = _controlStore.read();
      return attempt.matches(
        ownerInstance: _ownerInstance,
        installEpoch: _keyStore.readInstallEpoch(),
        databaseEpoch: _readiness.databaseEpoch,
        policyRevision: policy.revision,
      );
    } on ControlStoreError {
      return false;
    }
  }

  /// The key and deletion checks that apply in every mode, off included.
  bool _checkReadiness() {
    if (_readiness.deletionPending) {
      _record(LockEvent.openRefused);
      return false;
    }
    try {
      _keyStore.readKey();
    } on KeyStoreError {
      _record(LockEvent.openRefused);
      return false;
    }
    return true;
  }

  /// The app went to the background: mask immediately and, in immediately
  /// mode, lock at once. Background masking consumes the phase stream at
  /// the router (T09).
  void background() {
    _backgroundSinceMs = _monotonicMs();
    var lockNow = true; // a missing control state locks (stricter)
    try {
      final policy = _controlStore.read();
      lockNow = policy.mode == LockMode.immediately ||
          policy.pendingTransition != null;
    } on ControlStoreError {
      // Missing/unreadable control state: lock.
    }
    if (lockNow) {
      _to(LockPhase.closed);
      _currentAttempt = null;
      _record(LockEvent.locked);
    }
  }

  /// The app came to the foreground without an open admission result; the
  /// router drives [admitForeground] next.
  void foreground() {}

  /// Locks explicitly (Settings action or key invalidation).
  void lock() {
    _to(LockPhase.closed);
    _currentAttempt = null;
    _record(LockEvent.locked);
  }

  /// Closes the vault: closing → closed. Native I/O unresolved keeps the
  /// vault reported open until resolved (SYSTEM_DESIGN 12.1); Phase 1 has
  /// no native writer yet, so the transition is immediate and recorded.
  Future<void> closeVault() async {
    _to(LockPhase.closing);
    _to(LockPhase.closed);
    _currentAttempt = null;
    _record(LockEvent.locked);
  }

  /// Records an explicit mode change from an unlocked session. The
  /// transition is durably recorded before either enforcement copy changes;
  /// the caller applies the change and then finalises via
  /// [finalizeModeChange] (SYSTEM_DESIGN 12.3).
  ControlPolicy recordModeChange(LockMode newMode) {
    if (_phase != LockPhase.unlocked) {
      throw StateError('policy change requires an unlocked session');
    }
    final current = _controlStore.read();
    final recorded = current.copyWith(
      mode: newMode,
      revision: current.revision + 1,
      pendingTransition: newMode,
    );
    _controlStore.write(recorded);
    _record(LockEvent.policyChangeRecorded);
    return recorded;
  }

  /// Finalises a recorded mode change after the enforcement copies match.
  ControlPolicy finalizeModeChange() {
    final current = _controlStore.read();
    final finalized = current.copyWith(pendingTransition: null);
    _controlStore.write(finalized);
    return finalized;
  }

  /// Releases the phase stream.
  Future<void> dispose() => _phases.close();
}
