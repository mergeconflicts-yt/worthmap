import 'dart:math';

import 'package:contour/app/auth/auth_port.dart';
import 'package:contour/app/auth/lifecycle_control.dart';
import 'package:contour/app/auth/lock_controller.dart';
import 'package:contour/data/keys/keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryControlStore control;
  late InMemoryKeyStore keys;
  late FixedReadinessGate readiness;
  late ScriptedAuthPort auth;
  late LockController controller;
  var monotonicMs = 0;
  var nonce = 0;

  ControlPolicy freshPolicy() => const ControlPolicy(
        mode: LockMode.after1min,
        revision: 1,
        installId: 'install-1',
        pendingTransition: null,
      );

  LockController build() => LockController(
        authPort: auth,
        controlStore: control,
        keyStore: keys,
        readiness: readiness,
        monotonicMs: () => monotonicMs,
        attemptNonce: () => List.generate(10, (i) => (nonce + i) & 0xff),
        ownerInstance: 'owner-1',
      );

  setUp(() {
    monotonicMs = 0;
    nonce = 0;
    control = InMemoryControlStore(freshPolicy());
    keys = InMemoryKeyStore()..writeKey(generateVaultKey(Random(42)));
    readiness = FixedReadinessGate(databaseEpoch: 'db-epoch-1');
    auth = ScriptedAuthPort();
    controller = build();
  });

  tearDown(() => controller.dispose());

  test('immediately mode challenges on every foreground', () async {
    control.write(
      freshPolicy().copyWith(mode: LockMode.immediately, revision: 2),
    );
    // Fresh session: closed → challenge.
    await expectLater(
      controller.admitForeground(),
      completion(isTrue),
    );
    expect(controller.phase, LockPhase.unlocked);
    expect(controller.events, contains(LockEvent.challengeRequired));
    // The attempt tuple carries the observed epochs and revision.
    expect(auth.attempts.single.installEpoch, keys.readInstallEpoch());
    expect(auth.attempts.single.databaseEpoch, 'db-epoch-1');
    expect(auth.attempts.single.policyRevision, 2);
  });

  test('a timeout policy locks only after the threshold', () async {
    await controller.admitForeground(); // on open: one challenge
    expect(auth.attempts, hasLength(1));
    controller.background();
    // Under the threshold: still unlocked, no new challenge.
    monotonicMs += 59999;
    await expectLater(
      controller.admitForeground(),
      completion(isTrue),
    );
    expect(controller.phase, LockPhase.unlocked);
    expect(auth.attempts, hasLength(1));
    // Over the threshold: locked, a second challenge runs.
    controller.background();
    monotonicMs += 60000;
    await expectLater(
      controller.admitForeground(),
      completion(isTrue),
    );
    expect(auth.attempts, hasLength(2));
  });

  test('five minute mode uses a 5 minute threshold', () async {
    control.write(
      freshPolicy().copyWith(mode: LockMode.after5min, revision: 2),
    );
    await controller.admitForeground();
    controller.background();
    monotonicMs += 299999;
    await expectLater(
      controller.admitForeground(),
      completion(isTrue),
    );
    expect(auth.attempts, hasLength(1));
    controller.background();
    monotonicMs += 300000;
    await expectLater(
      controller.admitForeground(),
      completion(isTrue),
    );
    expect(auth.attempts, hasLength(2));
  });

  test('off mode opens without a challenge but still checks keys', () async {
    control.write(freshPolicy().copyWith(mode: LockMode.off, revision: 2));
    await expectLater(
      controller.admitForeground(),
      completion(isTrue),
    );
    expect(controller.phase, LockPhase.unlocked);
    expect(auth.attempts, isEmpty);
    expect(controller.events, contains(LockEvent.openReady));

    // Off mode still refuses when the key is gone (epoch/key/deletion
    // checks always apply).
    keys.deleteKey();
    await expectLater(
      controller.admitForeground(),
      completion(isFalse),
    );
    expect(controller.events.last, LockEvent.openRefused);
  });

  test('missing control state requires authentication and never opens off',
      () async {
    control.clear();
    keys.deleteKey();
    await expectLater(
      controller.admitForeground(),
      completion(isFalse), // the challenge succeeds, but the key is gone
    );
    expect(controller.events, contains(LockEvent.controlStateMissing));
    expect(controller.events, contains(LockEvent.challengeRequired));
    // The challenge succeeded, but the admission recheck fails without a
    // control state: the attempt is revoked and the vault stays closed.
    expect(controller.events, contains(LockEvent.authRevoked));
    expect(controller.phase, LockPhase.closed);
  });

  test('a failed challenge leaves the vault closed', () async {
    auth = ScriptedAuthPort([AuthOutcome.failure]);
    controller = build();
    await expectLater(
      controller.admitForeground(),
      completion(isFalse),
    );
    expect(controller.phase, LockPhase.closed);
    expect(controller.events, contains(LockEvent.authFailure));
  });

  test('a cancelled challenge is revoked, not a failure', () async {
    auth = ScriptedAuthPort([AuthOutcome.cancelled]);
    controller = build();
    await expectLater(
      controller.admitForeground(),
      completion(isFalse),
    );
    expect(controller.phase, LockPhase.closed);
    expect(controller.events, contains(LockEvent.authRevoked));
  });

  test('background in immediately mode locks at once and masks', () async {
    control.write(
      freshPolicy().copyWith(mode: LockMode.immediately, revision: 2),
    );
    await controller.admitForeground();
    controller.background();
    expect(controller.phase, LockPhase.closed);
    expect(controller.events, contains(LockEvent.locked));
  });

  test('a deletion intent refuses admission in every mode', () async {
    readiness.deletionPending = true;
    await expectLater(
      controller.admitForeground(),
      completion(isFalse),
    );
    expect(controller.events, contains(LockEvent.openRefused));
    // Even off mode refuses while a deletion intent is active.
    control.write(freshPolicy().copyWith(mode: LockMode.off, revision: 2));
    await expectLater(
      controller.admitForeground(),
      completion(isFalse),
    );
  });

  test('policy changes are recorded before the mode takes effect', () async {
    await controller.admitForeground(); // unlocked session
    final recorded = controller.recordModeChange(LockMode.immediately);
    expect(recorded.revision, 2);
    expect(recorded.pendingTransition, LockMode.immediately);
    // The store holds the recorded transition.
    expect(control.read().pendingTransition, LockMode.immediately);
    final finalized = controller.finalizeModeChange();
    expect(finalized.mode, LockMode.immediately);
    expect(finalized.pendingTransition, isNull);
    expect(control.read().revision, 2);
    expect(controller.events, contains(LockEvent.policyChangeRecorded));
  });

  test('an interrupted off transition still challenges (stricter mode)',
      () async {
    control.write(
      freshPolicy().copyWith(
        mode: LockMode.off,
        revision: 2,
        pendingTransition: LockMode.off,
      ),
    );
    // Stricter enforcement until reconciliation: both copies must be off
    // before no challenge happens.
    await expectLater(
      controller.admitForeground(),
      completion(isTrue),
    );
    expect(controller.events, contains(LockEvent.challengeRequired));
  });

  test('the event surface holds no key material', () async {
    await controller.admitForeground();
    final keyBytes = keys.readKey().bytes;
    for (final event in controller.events) {
      final text = event.name;
      for (final byte in keyBytes) {
        expect(
          text.contains(byte.toRadixString(16)),
          isFalse,
          reason: 'event surface must not contain key material',
        );
      }
    }
  });
}
