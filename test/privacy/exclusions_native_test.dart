import 'package:contour/data/backup/backup_exclusions_native.dart';
import 'package:contour/data/backup/exclusions.dart';
import 'package:flutter_test/flutter_test.dart';

// T11: the platform backup-exclusions binding over a scripted channel. The
// OS-level behaviour (iOS backup marker, Android manifest state) is device
// evidence (S01); these tests cover the apply-at-open, write-through and
// failure contracts on the host.

class _FakeChannel implements ExclusionChannel {
  final List<String> calls = <String>[];

  /// Answers `true` per kind by default; set kinds here to fail them.
  final Set<String> failingKinds = <String>{};

  @override
  Future<Object?> invoke(String method, Map<Object?, Object?> arguments) async {
    calls.add('$method:${arguments['kind']}');
    if (failingKinds.contains(arguments['kind'])) {
      return false;
    }
    return true;
  }
}

void main() {
  test('open applies every path kind and records the OS truth', () async {
    final channel = _FakeChannel();
    final exclusions = await NativeBackupExclusions.open(
      channel: channel,
      rootDirectory: '/vault',
    );

    expect(exclusions.recorded, equals(ProtectedPathKind.values.toSet()));
    expect(channel.calls, hasLength(ProtectedPathKind.values.length));
    // The database generation is the root itself; the others are
    // structural sub-directories.
    expect(
      channel.calls,
      contains('apply:databaseGeneration'),
    );
  });

  test('a native failure keeps the kind unrecorded', () async {
    final channel = _FakeChannel()
      ..failingKinds.add(ProtectedPathKind.attachments.name);
    final exclusions = await NativeBackupExclusions.open(
      channel: channel,
      rootDirectory: '/vault',
    );

    expect(
      exclusions.isExcluded(ProtectedPathKind.attachments),
      isFalse,
    );
    expect(
      exclusions.isExcluded(ProtectedPathKind.staging),
      isTrue,
    );
    expect(
      exclusions.recorded.contains(ProtectedPathKind.attachments),
      isFalse,
    );
  });

  test('exclude re-fires the kind as write-through and flush surfaces failure',
      () async {
    final channel = _FakeChannel();
    final exclusions = await NativeBackupExclusions.open(
      channel: channel,
      rootDirectory: '/vault',
    );
    channel.failingKinds.add(ProtectedPathKind.recovery.name);

    exclusions.exclude(ProtectedPathKind.recovery);
    await expectLater(
      exclusions.flush(),
      throwsA(isA<StateError>()),
    );
  });

  test('exclude succeeds through flush when the platform answers true',
      () async {
    final channel = _FakeChannel();
    final exclusions = await NativeBackupExclusions.open(
      channel: channel,
      rootDirectory: '/vault',
    );
    exclusions.exclude(ProtectedPathKind.staging);
    await exclusions.flush();
    expect(exclusions.isExcluded(ProtectedPathKind.staging), isTrue);
  });
}
