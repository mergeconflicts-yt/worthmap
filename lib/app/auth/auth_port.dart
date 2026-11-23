// T08 (SPEC 9.1, 11; SYSTEM_DESIGN 12.3): the native authentication port.
//
// "Use passcode" invokes the operating system's device credential; there is
// no separate Contour PIN, PIN hash or PIN-derived vault key. Native
// failure, cancellation and lockout return typed local states. No secret or
// biometric result enters a log (AGENTS 2.6).
//
// The native binding is `PlatformAuthPort` in `platform_auth_port.dart`
// (local authentication on iOS, BiometricPrompt plus device credentials on
// Android via the `local_auth` package). Device evidence (S06,
// SYSTEM_DESIGN 12.3) stays open. The app composition wires the platform
// implementation behind this interface only, and stays unwired until PF-01
// and DB-A close (no real-user persistence on a noncompliant path).
library;

import 'auth_attempt.dart';

/// Typed authentication outcomes. No payload beyond the outcome.
enum AuthOutcome {
  success,
  failure,
  cancelled,
  timeout,
  lockout,
  unavailable,
}

/// The authentication port for the lock screen and Settings.
abstract interface class AuthPort {
  /// Runs one authentication attempt for [attempt]. Exactly one attempt is
  /// current; the controller supersedes older attempts (SYSTEM_DESIGN 12.3).
  Future<AuthOutcome> authenticate(AuthAttempt attempt);
}

/// Test double. Returns the scripted outcome and records the attempt it saw.
final class ScriptedAuthPort implements AuthPort {
  ScriptedAuthPort([this._outcomes = const <AuthOutcome>[]]);

  final List<AuthOutcome> _outcomes;
  final List<AuthAttempt> attempts = <AuthAttempt>[];
  int _cursor = 0;

  @override
  Future<AuthOutcome> authenticate(AuthAttempt attempt) async {
    attempts.add(attempt);
    if (_cursor >= _outcomes.length) {
      return AuthOutcome.success;
    }
    return _outcomes[_cursor++];
  }
}
