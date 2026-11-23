// P3-20 (SPEC 8.6; flow F06 step 2): the PDF password kept in secure storage.
//
// The password is stored under a hash of the file name, so the key itself
// carries no personal text. A statement password is never logged, printed or
// returned in an error (AGENTS 2.6).
//
// Production mounts the `flutter_secure_storage` engine through
// [SecureStorageApi]. Tests inject an in-memory engine.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../keys/secure_key_store.dart';

/// The import password vault over the platform secure store.
final class SecureImportPasswordStore {
  SecureImportPasswordStore(this._api);

  static const String _prefix = 'contour.importPassword.';

  final SecureStorageApi _api;

  /// The key for one file scope. SHA-256 of the name, so no name is stored in
  /// the key ring.
  @visibleForTesting
  static String keyFor(String scope) =>
      '$_prefix${sha256.convert(utf8.encode(scope)).toString()}';

  /// The saved password for [scope], or null when none is stored.
  Future<String?> read(String scope) async {
    if (scope.isEmpty) return null;
    final value = await _api.read(keyFor(scope));
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// Stores [password]. An empty password is not a password and is refused.
  Future<void> save(String scope, String password) async {
    if (scope.isEmpty) {
      throw ArgumentError.value(scope, 'scope', 'Must not be empty');
    }
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'Must not be empty');
    }
    await _api.write(keyFor(scope), password);
  }

  /// Removes a saved password. A missing entry is not an error.
  Future<void> clear(String scope) async {
    if (scope.isEmpty) return;
    await _api.delete(keyFor(scope));
  }
}
