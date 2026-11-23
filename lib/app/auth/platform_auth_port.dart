// T08 (SPEC 11; SYSTEM_DESIGN 12.1, 12.3): the platform authentication
// binding behind the `AuthPort` port.
//
// The binding runs the OS biometric/device-credential challenge through the
// `local_auth` plugin and maps its typed results to the port's outcomes. It
// performs no admission logic: the attempt tuple is issued and rechecked by
// `LockController` (auth_attempt.dart, SYSTEM_DESIGN 12.3); this binding only
// reports what the native challenge returned.
//
// Error descriptions are never logged or stored (AGENTS 2.6): the binding
// returns outcome names only. The `attempt` argument is accepted for the
// port shape; the platform call carries no identifiers.
//
// Device verification (S06, SYSTEM_DESIGN 12.3) stays open: Face ID /
// Touch ID / BiometricPrompt behaviour is device evidence, not a host test.
library;

import 'package:local_auth/local_auth.dart';

import 'auth_attempt.dart';
import 'auth_port.dart';

/// The local authentication engine seam. The real implementation calls the
/// plugin; tests inject a scripted engine.
abstract interface class LocalAuthApi {
  /// Runs the native challenge. True when the user authenticated; false when
  /// the challenge failed without a side effect. Throws [LocalAuthException]
  /// for every other native outcome.
  Future<bool> authenticate({required String localizedReason});

  /// True when the device can run the challenge (biometrics or device
  /// credentials).
  Future<bool> isDeviceSupported();
}

/// The production engine over the `local_auth` plugin.
final class LocalAuthApiImpl implements LocalAuthApi {
  const LocalAuthApiImpl();

  static final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> authenticate({required String localizedReason}) =>
      _auth.authenticate(
        localizedReason: localizedReason,
        // The fallback to the device credential (PIN, pattern, passcode) is
        // part of the unlock flow (SYSTEM_DESIGN 12.1); biometric-only is not
        // required.
        biometricOnly: false,
        // The unlock is sensitive: the platform confirmation guard stays on.
        sensitiveTransaction: true,
      );

  @override
  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();
}

/// The platform `AuthPort` implementation.
final class PlatformAuthPort implements AuthPort {
  PlatformAuthPort({
    required LocalAuthApi api,
    required String Function() localizedReason,
  })  : _api = api,
        _localizedReason = localizedReason;

  final LocalAuthApi _api;

  /// Supplies the localized unlock prompt at challenge time. The text is
  /// app copy from l10n (SPEC Appendix B), never user data.
  final String Function() _localizedReason;

  @override
  Future<AuthOutcome> authenticate(AuthAttempt attempt) async {
    try {
      final success = await _api.authenticate(
        localizedReason: _localizedReason(),
      );
      return success ? AuthOutcome.success : AuthOutcome.failure;
    } on LocalAuthException catch (exception) {
      // The exception description is dropped on purpose: the log surface
      // carries outcome names only (AGENTS 2.6).
      return _outcomeFor(exception.code);
    } on UnsupportedError {
      return AuthOutcome.unavailable;
    }
  }

  /// Maps the typed native failure codes to the port outcomes (SYSTEM_DESIGN
  /// 12.3 S06 classes). Unknown codes map to `unavailable` (fail closed).
  AuthOutcome _outcomeFor(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return AuthOutcome.cancelled;
      case LocalAuthExceptionCode.timeout:
        return AuthOutcome.timeout;
      case LocalAuthExceptionCode.authInProgress:
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return AuthOutcome.lockout;
      case LocalAuthExceptionCode.uiUnavailable:
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return AuthOutcome.unavailable;
    }
  }
}
