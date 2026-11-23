// T11 (SPEC 11; SYSTEM_DESIGN 12.2): the platform backup and transfer
// exclusion binding behind the `BackupExclusions` port.
//
// iOS: the native handler sets `URLResourceKey.isExcludedFromBackupKey` on
// the directory URL of the requested path kind (ios/Runner, backup exclusion
// on every protected path).
// Android: the native handler reports the OS-level truth — the release
// manifest sets `allowBackup="false"` and the data-extraction rules exclude
// every domain for cloud backup and device transfer, so every protected
// path kind is excluded (test/privacy/android_manifest_test.dart guards the
// manifest).
//
// The `BackupExclusions` port is synchronous and the platform call is
// asynchronous. The binding applies every kind's exclusion once at [open]
// (all path kinds are structural and known), serves the sync port from that
// state, and re-fires single kinds as write-through on [exclude]. [flush]
// surfaces a native failure to the caller. Path arguments are structural
// directory paths only — never user text or original filenames (AGENTS 2.6).
//
// PF-01 stays open: exclusion flags and device tests cannot prove universal
// phone confinement. Device verification (S01 backup/transfer evidence)
// stays open.
library;

import 'package:flutter/services.dart';

import 'exclusions.dart';

/// The platform-channel seam. The real implementation calls the method
/// channel; tests inject a scripted channel.
abstract interface class ExclusionChannel {
  Future<Object?> invoke(String method, Map<Object?, Object?> arguments);
}

/// The production channel over `contour/backup_exclusions` (the native
/// handlers live in ios/Runner and android/.../MainActivity.kt).
final class MethodExclusionChannel implements ExclusionChannel {
  const MethodExclusionChannel();

  static const MethodChannel _channel =
      MethodChannel('contour/backup_exclusions');

  @override
  Future<Object?> invoke(String method, Map<Object?, Object?> arguments) =>
      _channel.invokeMethod(method, arguments);
}

/// The platform `BackupExclusions` implementation. Constructed through
/// [open]; the default constructor is private to force the apply-at-open
/// contract.
final class NativeBackupExclusions implements BackupExclusions {
  NativeBackupExclusions._({
    required ExclusionChannel channel,
    required String rootDirectory,
  })  : _channel = channel,
        _rootDirectory = rootDirectory;

  final ExclusionChannel _channel;
  final String _rootDirectory;

  /// The kinds the OS currently reports as excluded (open + later writes).
  final Set<ProtectedPathKind> _applied = <ProtectedPathKind>{};

  /// Write-through operations not yet awaited.
  final List<Future<Object?>> _pending = <Future<Object?>>[];

  /// The path kind → structural sub-directory under the root. The database
  /// generation lives at the root itself; every other kind has its own
  /// bounded directory. Names are structural tokens, not user data.
  static const Map<ProtectedPathKind, String> _paths =
      <ProtectedPathKind, String>{
    ProtectedPathKind.databaseGeneration: '',
    ProtectedPathKind.staging: 'staging',
    ProtectedPathKind.attachments: 'attachments',
    ProtectedPathKind.recovery: 'recovery',
    ProtectedPathKind.appGroup: 'appgroup',
  };

  /// Applies the exclusion for every path kind and records the OS-level
  /// truth. A native failure for one kind keeps that kind unrecorded (the
  /// port reports verified exclusions only).
  static Future<NativeBackupExclusions> open({
    ExclusionChannel channel = const MethodExclusionChannel(),
    required String rootDirectory,
  }) async {
    final store = NativeBackupExclusions._(
      channel: channel,
      rootDirectory: rootDirectory,
    );
    for (final kind in ProtectedPathKind.values) {
      await store._apply(kind);
    }
    return store;
  }

  Future<void> _apply(ProtectedPathKind kind) async {
    final relative = _paths[kind]!;
    final path =
        relative.isEmpty ? _rootDirectory : '$_rootDirectory/$relative';
    final pending = _channel.invoke('apply', <Object?, Object?>{
      'kind': kind.name,
      'path': path,
    });
    _pending.add(pending);
    final answer = await pending;
    if (answer == true) {
      _applied.add(kind);
    }
  }

  @override
  void exclude(ProtectedPathKind kind) {
    // Write-through: the claim is recorded when the platform answers. The
    // sync port cannot await; [flush] surfaces a failure.
    _apply(kind).catchError((Object error) {
      // A failed native call leaves the kind unrecorded; [flush] reports it.
      return null;
    });
  }

  @override
  bool isExcluded(ProtectedPathKind kind) => _applied.contains(kind);

  @override
  Set<ProtectedPathKind> get recorded => Set.unmodifiable(_applied);

  /// Awaits every scheduled exclusion and throws on the first native
  /// failure. The composition runs this before it trusts the exclusion
  /// state.
  Future<void> flush() async {
    final pending = List<Future<Object?>>.of(_pending);
    _pending.clear();
    for (final pendingCall in pending) {
      final answer = await pendingCall;
      if (answer != true) {
        throw StateError('backup exclusion not applied');
      }
    }
  }
}
