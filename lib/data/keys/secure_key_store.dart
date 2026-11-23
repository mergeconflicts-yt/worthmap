// T08 (SPEC 11; SYSTEM_DESIGN 12.1): the platform key store binding behind
// the `KeyStore` port.
//
// iOS: Keychain item with `WhenUnlockedThisDeviceOnly`, never synchronised.
// Android: hardware-backed KeyStore AES-GCM storage with RSA-OAEP key
// wrapping, no biometric enforcement, and `resetOnError = false` so a
// platform error never erases the key (key loss is never deletion consent,
// SYSTEM_DESIGN 12.1).
//
// The `KeyStore` port is synchronous and the platform store is asynchronous.
// The binding therefore loads once (`load`) and serves the sync port from
// that in-process mirror; every write goes through to the platform store and
// the caller awaits [flush] before it treats the write as durable. The
// composition contract: write → flush → continue.
//
// The stored key text is secret material: nothing here logs, prints or
// exports it (AGENTS 2.6). Device verification (S06) stays open: Keychain /
// Keystore behaviour is device evidence, not a host test.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'keys.dart';

/// The secure storage seam. The real implementation calls the plugin; tests
/// inject an in-memory engine.
abstract interface class SecureStorageApi {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// The production engine over the `flutter_secure_storage` plugin.
final class SecureStorageApiImpl implements SecureStorageApi {
  static const IOSOptions _iOptions = IOSOptions(
    // `WhenUnlockedThisDeviceOnly`: readable only while unlocked, never
    // migrated to a new device (SYSTEM_DESIGN 12.1).
    accessibility: KeychainAccessibility.unlocked_this_device,
    // Never iCloud-synchronised (SPEC 11: no off-device transfer).
    synchronizable: false,
  );

  static const AndroidOptions _aOptions = AndroidOptions(
    // A platform error never erases the stored key (SYSTEM_DESIGN 12.1).
    resetOnError: false,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: _iOptions,
    aOptions: _aOptions,
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// The platform `KeyStore` implementation. Constructed through [load]; the
/// default constructor is private to force the preload contract.
final class SecureKeyStore implements KeyStore {
  static const String _keyName = 'contour.vaultKey';
  static const String _epochName = 'contour.installEpoch';

  SecureKeyStore._(this._api);

  final SecureStorageApi _api;

  VaultKey? _key;
  int? _installEpoch;

  /// Write-through operations that are scheduled but not yet awaited.
  final List<Future<void>> _pending = <Future<void>>[];

  /// Test seam: the storage key names (tests inject corrupt values).
  @visibleForTesting
  static String get keyNameForTest => _keyName;

  /// Test seam: the storage epoch name.
  @visibleForTesting
  static String get epochNameForTest => _epochName;

  /// Loads the stored state once and returns the sync store.
  ///
  /// A missing stored key leaves the store absent ([KeyStoreError.absent] on
  /// [readKey]); stored bytes that are not exactly 32 key bytes throw
  /// [KeyStoreError.unreadable] (fail closed, never a substitute value).
  static Future<SecureKeyStore> load(SecureStorageApi api) async {
    final store = SecureKeyStore._(api);
    final keyText = await api.read(_keyName);
    if (keyText != null) {
      store._key = _decodeKey(keyText);
    }
    final epochText = await api.read(_epochName);
    if (epochText != null) {
      final epoch = int.tryParse(epochText);
      if (epoch == null || epoch < 0) {
        throw const KeyStoreError(KeyStoreErrorCode.unreadable);
      }
      store._installEpoch = epoch;
    }
    return store;
  }

  /// Decodes the stored base64 key text. No textual key form ever escapes:
  /// the input is consumed, not logged (AGENTS 2.6).
  static VaultKey _decodeKey(String keyText) {
    final Uint8List bytes;
    try {
      bytes = base64Decode(keyText);
    } on FormatException {
      throw const KeyStoreError(KeyStoreErrorCode.unreadable);
    }
    if (bytes.length != VaultKey.byteLength) {
      throw const KeyStoreError(KeyStoreErrorCode.unreadable);
    }
    return VaultKey.fromBytes(bytes);
  }

  @override
  VaultKey readKey() {
    final key = _key;
    if (key == null) {
      throw const KeyStoreError(KeyStoreErrorCode.absent);
    }
    return key;
  }

  @override
  void writeKey(VaultKey key) {
    _key = key;
    _schedule(() => _api.write(_keyName, base64Encode(key.bytes)));
  }

  @override
  void deleteKey() {
    _key = null;
    _schedule(() => _api.delete(_keyName));
  }

  @override
  int readInstallEpoch() {
    final epoch = _installEpoch;
    if (epoch == null) {
      throw const KeyStoreError(KeyStoreErrorCode.absent);
    }
    return epoch;
  }

  @override
  void writeInstallEpoch(int epoch) {
    _installEpoch = epoch;
    _schedule(() => _api.write(_epochName, epoch.toString()));
  }

  /// Awaits durability of every scheduled write. A platform failure surfaces
  /// to the caller; the composition decides whether the flow may continue.
  Future<void> flush() {
    final pending = List<Future<void>>.of(_pending);
    _pending.clear();
    return Future.wait(pending);
  }

  void _schedule(Future<void> Function() operation) {
    _pending.add(operation());
  }
}
