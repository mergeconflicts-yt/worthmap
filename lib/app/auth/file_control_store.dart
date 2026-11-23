// T08 (SPEC 11; SYSTEM_DESIGN 12.1): the lifecycle control store binding
// behind the `LifecycleControlStore` port.
//
// The control policy lives in one small file outside the financial
// generations (SYSTEM_DESIGN 12.1). Writes are durable before they return:
// temp file → fsync → atomic rename in the same directory. A missing or
// unreadable file is reported as a typed error and never substitutes a
// default mode (the port contract; the controller decides the strict mode).
//
// The file holds identifiers and mode names only — no amounts, no names, no
// timestamps of user activity (AGENTS 2.6). A file-protection hardening pass
// (iOS `NSFileProtectionComplete`) is device work that stays with the S06
// evidence gate.
library;

import 'dart:io';

import 'lifecycle_control.dart';

/// The platform `LifecycleControlStore` implementation over a local file.
final class FileControlStore implements LifecycleControlStore {
  FileControlStore({required String directory})
      : _file = File('$directory/contour-control.policy'),
        _tempFile = File('$directory/contour-control.policy.tmp');

  static const int _schemaVersion = 1;

  final File _file;
  final File _tempFile;

  @override
  ControlPolicy read() {
    if (!_file.existsSync()) {
      throw const ControlStoreError(ControlStoreErrorCode.missing);
    }
    final String text;
    try {
      text = _file.readAsStringSync();
    } on FileSystemException {
      throw const ControlStoreError(ControlStoreErrorCode.unreadable);
    }
    return _parse(text);
  }

  @override
  void write(ControlPolicy policy) {
    final text = _serialize(policy);
    final RandomAccessFile temp;
    try {
      temp = _tempFile.openSync(mode: FileMode.write);
      try {
        temp.writeStringSync(text);
        temp.flushSync();
        // dart:io exposes no fsync; the flush plus the atomic same-directory
        // rename is the best ordering the host gives. Device durability
        // (power loss between flush and rename) stays with the S06 evidence
        // gate.
      } finally {
        temp.closeSync();
      }
      // An atomic same-directory rename; readers see either the old or the
      // new full file, never a partial one.
      _tempFile.renameSync(_file.path);
    } on FileSystemException {
      _removeTemp();
      throw const ControlStoreError(ControlStoreErrorCode.unreadable);
    }
  }

  void _removeTemp() {
    try {
      if (_tempFile.existsSync()) {
        _tempFile.deleteSync();
      }
    } on FileSystemException {
      // A leftover temp file never blocks the next write attempt.
    }
  }

  String _serialize(ControlPolicy policy) {
    final pending = policy.pendingTransition?.name;
    return <String>[
      'schemaVersion=$_schemaVersion',
      'mode=${policy.mode.name}',
      'revision=${policy.revision}',
      'installId=${policy.installId}',
      if (pending != null) 'pendingTransition=$pending',
    ].join('\n');
  }

  ControlPolicy _parse(String text) {
    final fields = <String, String>{};
    for (final line in text.split('\n')) {
      if (line.isEmpty) {
        continue;
      }
      final separator = line.indexOf('=');
      if (separator <= 0) {
        throw const ControlStoreError(ControlStoreErrorCode.unreadable);
      }
      final key = line.substring(0, separator);
      final value = line.substring(separator + 1);
      if (fields.containsKey(key)) {
        throw const ControlStoreError(ControlStoreErrorCode.unreadable);
      }
      fields[key] = value;
    }
    final version = int.tryParse(fields['schemaVersion'] ?? '');
    if (version == null) {
      throw const ControlStoreError(ControlStoreErrorCode.unreadable);
    }
    if (version > _schemaVersion) {
      // A newer writer is unsupported; fail closed (DATABASE_DESIGN 10 rule
      // applied to the control file).
      throw const ControlStoreError(ControlStoreErrorCode.unsupported);
    }
    if (version < _schemaVersion) {
      throw const ControlStoreError(ControlStoreErrorCode.unsupported);
    }
    final mode = _lockMode(fields['mode']);
    final installId = fields['installId'];
    final revision = int.tryParse(fields['revision'] ?? '');
    if (mode == null ||
        installId == null ||
        installId.isEmpty ||
        revision == null) {
      throw const ControlStoreError(ControlStoreErrorCode.unreadable);
    }
    final pendingText = fields['pendingTransition'];
    return ControlPolicy(
      mode: mode,
      revision: revision,
      installId: installId,
      pendingTransition: pendingText == null ? null : _lockMode(pendingText),
    );
  }

  LockMode? _lockMode(String? name) {
    if (name == null) {
      return null;
    }
    for (final mode in LockMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    throw const ControlStoreError(ControlStoreErrorCode.unreadable);
  }
}
