// T08 (SPEC 11; SYSTEM_DESIGN 12.1): vault key material and the key store
// port.
//
// Independent random 256-bit keys for the active database. Platform key
// protection: never derive the vault key from a short PIN and never export
// it. The key object carries no `toString` and no serialisation that could
// leak it into logs (AGENTS 2.6: no secret in logs).
//
// The platform-backed implementation is `SecureKeyStore` in
// `secure_key_store.dart` (Keychain `WhenUnlockedThisDeviceOnly` on iOS,
// hardware-backed Keystore AES-GCM on Android) with the preload/write-
// through contract its header documents. Device evidence (S06,
// SYSTEM_DESIGN 12.1) stays open. Until the app composition wires it (which
// waits for PF-01 and DB-A), the in-memory store runs tests only and is
// never reachable from release paths.
library;

import 'dart:math';
import 'dart:typed_data';

/// Opaque 256-bit key bytes. Constructed from exact byte input only.
final class VaultKey {
  VaultKey._(this._bytes) : assert(_bytes.length == byteLength);

  /// 256 bits.
  static const int byteLength = 32;

  final Uint8List _bytes;

  /// The key bytes. Only the cipher port may consume them.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Rebuilds a key from exactly [byteLength] stored bytes. The platform
  /// key store uses it at preload time; it never widens or trims the input
  /// (T08-NATIVE-KEYSTORE binding).
  factory VaultKey.fromBytes(Uint8List bytes) {
    if (bytes.length != byteLength) {
      throw const KeyStoreError(KeyStoreErrorCode.unreadable);
    }
    return VaultKey._(bytes);
  }

  /// No textual form ever leaves the object (AGENTS 2.6).
  @override
  String toString() => 'VaultKey(#bytes: ${_bytes.length})';
}

/// Generates a fresh random 256-bit key from the injected random source
/// (AGENTS 6.3: no unseeded randomness in domain code).
VaultKey generateVaultKey(Random random) {
  final bytes = Uint8List(VaultKey.byteLength);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return VaultKey._(bytes);
}

/// Typed, safe key-store failure codes.
enum KeyStoreErrorCode {
  absent,
  unreadable,
  unsupported,
}

class KeyStoreError implements Exception {
  const KeyStoreError(this.code);

  final KeyStoreErrorCode code;

  @override
  String toString() => 'KeyStoreError(${code.name})';
}

/// The device-bound key store port. Stores the vault key, the install epoch
/// and the database epoch counters. Implementations never log secrets and
/// never synchronise keys off the device (SPEC 11).
abstract interface class KeyStore {
  /// The stored key, or [KeyStoreError.absent] when none exists (a fresh
  /// installation creates one; a revoked one stays absent).
  VaultKey readKey();

  /// Stores a new key. Replaces the previous value only through the explicit
  /// rekey/delete-all flows.
  void writeKey(VaultKey key);

  /// Removes the key. Key loss is never deletion consent (SYSTEM_DESIGN 12.1).
  void deleteKey();

  /// The opaque install epoch (rotated on Delete all and recovery).
  int readInstallEpoch();

  void writeInstallEpoch(int epoch);
}

/// In-memory store for tests only (PF-01: synthetic data). Never wire this
/// into the app composition.
final class InMemoryKeyStore implements KeyStore {
  VaultKey? _key;
  int _installEpoch = 0;

  @override
  VaultKey readKey() {
    final key = _key;
    if (key == null) {
      throw const KeyStoreError(KeyStoreErrorCode.absent);
    }
    return key;
  }

  @override
  void writeKey(VaultKey key) => _key = key;

  @override
  void deleteKey() => _key = null;

  @override
  int readInstallEpoch() => _installEpoch;

  @override
  void writeInstallEpoch(int epoch) => _installEpoch = epoch;
}
