import 'package:contour/app/auth/auth_attempt.dart';
import 'package:contour/app/auth/auth_port.dart';
import 'package:contour/app/auth/platform_auth_port.dart';
import 'package:contour/core/ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

// T08: the platform `AuthPort` binding over the scripted local-auth engine.
// The native challenge itself is device evidence (S06); these tests cover
// the outcome mapping and the seam contract on the host.

class _FakeLocalAuthApi implements LocalAuthApi {
  _FakeLocalAuthApi({this.result, this.exception});

  final bool? result;
  final LocalAuthException? exception;
  String? lastReason;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    lastReason = localizedReason;
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }
    return result ?? false;
  }

  @override
  Future<bool> isDeviceSupported() async => true;
}

AuthAttempt attempt() => AuthAttempt(
      attemptId: UuidV7.generate(
        unixMillis: 1,
        randomBytes: <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      ),
      ownerInstance: 'owner-1',
      installEpoch: 0,
      databaseEpoch: 'db-1',
      policyRevision: 1,
    );

void main() {
  test('success maps to the success outcome and passes the prompt text',
      () async {
    final api = _FakeLocalAuthApi(result: true);
    final port = PlatformAuthPort(api: api, localizedReason: () => 'Unlock');
    final outcome = await port.authenticate(attempt());
    expect(outcome, AuthOutcome.success);
    expect(api.lastReason, 'Unlock');
  });

  test('a failed challenge without side effects maps to failure', () async {
    final api = _FakeLocalAuthApi(result: false);
    final port = PlatformAuthPort(api: api, localizedReason: () => 'Unlock');
    expect(await port.authenticate(attempt()), AuthOutcome.failure);
  });

  test('cancellation-shaped native codes map to cancelled', () async {
    for (final code in <LocalAuthExceptionCode>[
      LocalAuthExceptionCode.userCanceled,
      LocalAuthExceptionCode.systemCanceled,
      LocalAuthExceptionCode.userRequestedFallback,
    ]) {
      final api = _FakeLocalAuthApi(
        exception: LocalAuthException(code: code),
      );
      final port = PlatformAuthPort(api: api, localizedReason: () => 'Unlock');
      expect(
        await port.authenticate(attempt()),
        AuthOutcome.cancelled,
        reason: code.name,
      );
    }
  });

  test('timeout maps to timeout', () async {
    final api = _FakeLocalAuthApi(
      exception: const LocalAuthException(code: LocalAuthExceptionCode.timeout),
    );
    final port = PlatformAuthPort(api: api, localizedReason: () => 'Unlock');
    expect(await port.authenticate(attempt()), AuthOutcome.timeout);
  });

  test('lockout-shaped native codes map to lockout', () async {
    for (final code in <LocalAuthExceptionCode>[
      LocalAuthExceptionCode.authInProgress,
      LocalAuthExceptionCode.temporaryLockout,
      LocalAuthExceptionCode.biometricLockout,
    ]) {
      final api = _FakeLocalAuthApi(
        exception: LocalAuthException(code: code),
      );
      final port = PlatformAuthPort(api: api, localizedReason: () => 'Unlock');
      expect(
        await port.authenticate(attempt()),
        AuthOutcome.lockout,
        reason: code.name,
      );
    }
  });

  test('unavailable-shaped native codes map to unavailable', () async {
    for (final code in <LocalAuthExceptionCode>[
      LocalAuthExceptionCode.uiUnavailable,
      LocalAuthExceptionCode.noCredentialsSet,
      LocalAuthExceptionCode.noBiometricsEnrolled,
      LocalAuthExceptionCode.noBiometricHardware,
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
      LocalAuthExceptionCode.deviceError,
      LocalAuthExceptionCode.unknownError,
    ]) {
      final api = _FakeLocalAuthApi(
        exception: LocalAuthException(code: code),
      );
      final port = PlatformAuthPort(api: api, localizedReason: () => 'Unlock');
      expect(
        await port.authenticate(attempt()),
        AuthOutcome.unavailable,
        reason: code.name,
      );
    }
  });
}
