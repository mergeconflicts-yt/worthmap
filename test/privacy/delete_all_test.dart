import 'dart:io';
import 'dart:math' as math;

import 'package:contour/data/keys/keys.dart';
import 'package:contour/features/settings/delete_all_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory snapshotDir;
  late InMemoryKeyStore keys;
  late SyntheticDeleteAllExecutor executor;
  late DeleteAllController controller;

  setUp(() async {
    snapshotDir = await Directory.systemTemp.createTemp('delete_all_test');
    // A synthetic snapshot file; never real user data (PF-01).
    File('${snapshotDir.path}/snapshot.bin')
        .writeAsBytesSync(<int>[1, 2, 3, 4]);
    keys = InMemoryKeyStore()..writeKey(generateVaultKey(math.Random(7)));
    keys.writeInstallEpoch(3);
    executor = SyntheticDeleteAllExecutor(
      keyStore: keys,
      snapshotDirectory: snapshotDir.path,
    );
    controller = DeleteAllController(
      executor: executor,
      isUnlocked: () => true,
    );
  });

  tearDown(() async {
    if (snapshotDir.existsSync()) {
      await snapshotDir.delete(recursive: true);
    }
  });

  test('a locked app never deletes', () async {
    final locked = DeleteAllController(
      executor: executor,
      isUnlocked: () => false,
    );
    expect(
      () => locked.confirmFirst(),
      throwsA(
        isA<DeleteAllError>().having(
          (e) => e.code,
          'code',
          DeleteAllErrorCode.notUnlocked,
        ),
      ),
    );
    expect(executor.steps, isEmpty);
    expect(keys.readInstallEpoch(), 3);
  });

  test('the executor runs only after two explicit confirmations', () async {
    controller.confirmFirst();
    expect(controller.awaitingSecondConfirmation, isTrue);
    expect(executor.steps, isEmpty);
    await controller.confirmSecond();
    expect(executor.steps, ['removeSnapshot', 'removeKeys']);
    expect(executor.removedKeys, isTrue);
    expect(controller.awaitingSecondConfirmation, isFalse);
  });

  test('the second confirmation without the first fails cleanly', () async {
    final fresh =
        DeleteAllController(executor: executor, isUnlocked: () => true);
    expect(
      () => fresh.confirmSecond(),
      throwsA(
        isA<DeleteAllError>().having(
          (e) => e.code,
          'code',
          DeleteAllErrorCode.missingConfirmation,
        ),
      ),
    );
    expect(executor.steps, isEmpty);
  });

  test('cancel clears the confirmation chain and nothing runs', () async {
    controller.confirmFirst();
    controller.cancel();
    expect(controller.awaitingSecondConfirmation, isFalse);
    await expectLater(
      controller.confirmSecond(),
      throwsA(isA<DeleteAllError>()),
    );
    expect(executor.steps, isEmpty);
  });

  test('the synthetic step removes the snapshot and the key', () async {
    controller.confirmFirst();
    await controller.confirmSecond();
    // The synthetic executor records both removals; the directory itself is
    // removed by the test tear-down (the real sequence removes files under
    // the native lifecycle lock on a device).
    expect(executor.removedSnapshot, isTrue);
    expect(executor.removedKeys, isTrue);
    // The key is gone: a later read fails with the absent code.
    expect(
      () => keys.readKey(),
      throwsA(
        isA<KeyStoreError>().having(
          (e) => e.code,
          'code',
          KeyStoreErrorCode.absent,
        ),
      ),
    );
  });

  test('no email, SMS or bank-credential permission is requested', () {
    // The Phase 1 delete-all path requests no platform permission at all:
    // the source folders it touches declare none.
    final sources = <String>[
      'lib/features/settings/delete_all_controller.dart',
      'lib/features/settings/delete_all_confirm_sheet.dart',
      'lib/data/backup/exclusions.dart',
    ];
    for (final path in sources) {
      final source = File(path).readAsStringSync();
      for (final banned in <String>[
        'Gmail',
        'gmail',
        'sms',
        'SMS',
        'credential',
        'permission',
      ]) {
        expect(
          source.contains(banned),
          isFalse,
          reason: '$path must not reference "$banned"',
        );
      }
    }
  });
}
