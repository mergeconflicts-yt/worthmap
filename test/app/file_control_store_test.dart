import 'dart:io';

import 'package:contour/app/auth/file_control_store.dart';
import 'package:contour/app/auth/lifecycle_control.dart';
import 'package:flutter_test/flutter_test.dart';

// T08: the file-backed lifecycle control store. The host tests run in a
// temp directory; the device placement (app-support directory, iOS file
// protection) is S06 device evidence.

ControlPolicy policy({
  LockMode mode = LockMode.after1min,
  int revision = 1,
  String installId = 'install-1',
  LockMode? pendingTransition,
}) =>
    ControlPolicy(
      mode: mode,
      revision: revision,
      installId: installId,
      pendingTransition: pendingTransition,
    );

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('contour-control');
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  FileControlStore store() => FileControlStore(directory: directory.path);

  test('a missing control file reports missing', () {
    expect(
      () => store().read(),
      throwsA(const ControlStoreError(ControlStoreErrorCode.missing)),
    );
  });

  test('write then read returns the same policy', () {
    final written = policy(
      mode: LockMode.after5min,
      revision: 7,
      installId: 'install-2',
      pendingTransition: LockMode.off,
    );
    store().write(written);

    final read = store().read();
    expect(read.mode, LockMode.after5min);
    expect(read.revision, 7);
    expect(read.installId, 'install-2');
    expect(read.pendingTransition, LockMode.off);
  });

  test('a null pending transition round-trips', () {
    store().write(policy());
    expect(store().read().pendingTransition, isNull);
  });

  test('the write leaves no temp file behind', () {
    store().write(policy());
    expect(
      File('${directory.path}/contour-control.policy.tmp').existsSync(),
      isFalse,
    );
  });

  test('a garbage file reports unreadable', () {
    File('${directory.path}/contour-control.policy')
        .writeAsStringSync('garbage with no structure');
    expect(
      () => store().read(),
      throwsA(const ControlStoreError(ControlStoreErrorCode.unreadable)),
    );
  });

  test('an unknown mode name reports unreadable', () {
    File('${directory.path}/contour-control.policy').writeAsStringSync(
      'schemaVersion=1\nmode=sometimes\nrevision=1\ninstallId=i',
    );
    expect(
      () => store().read(),
      throwsA(const ControlStoreError(ControlStoreErrorCode.unreadable)),
    );
  });

  test('a newer schema version reports unsupported and never downgrades', () {
    File('${directory.path}/contour-control.policy').writeAsStringSync(
      'schemaVersion=2\nmode=off\nrevision=1\ninstallId=i',
    );
    expect(
      () => store().read(),
      throwsA(const ControlStoreError(ControlStoreErrorCode.unsupported)),
    );
  });

  test('a policy without required fields reports unreadable', () {
    File('${directory.path}/contour-control.policy')
        .writeAsStringSync('schemaVersion=1\nmode=off');
    expect(
      () => store().read(),
      throwsA(const ControlStoreError(ControlStoreErrorCode.unreadable)),
    );
  });
}
