// T07 (SYSTEM_DESIGN 5.1, DATABASE_DESIGN 2, gate DB-A): the vault cipher port.
//
// The database opens only through a verified cipher build. The port applies
// the key BEFORE any schema access and verifies, on every open:
//   1. the cipher build is present (`cipher_version`),
//   2. an authenticated read succeeds (a wrong key or integrity failure
//      fails closed; DATABASE_DESIGN 10: `cipher_integrity_check` returns
//      no error rows).
//
// DECISION-PENDING: T07-CIPHER-BUILD. The pinned SQLCipher native build, its
// FFI binding verification and the encrypted-WAL/temp/FTS device evidence are
// gate DB-A (DATABASE_DESIGN 11). Until that build lands, only the test
// adapters in this file run, and only on synthetic data (PF-01). Drift's
// built-in "simple encryption" is SQLite3MultipleCiphers, not SQLCipher, and
// `sqlcipher_flutter_libs` must not be used (SYSTEM_DESIGN 5.1).
library;

import 'package:sqlite3/sqlite3.dart';

/// Typed, safe failure codes. No amounts, names or file content in errors
/// (AGENTS 2.6).
enum VaultCipherErrorCode {
  /// No cipher build in the driver (fail closed).
  cipherAbsent,

  /// The key does not open the vault (fail closed).
  wrongKey,

  /// An authenticated read failed (fail closed).
  integrity,
}

class VaultCipherError implements Exception {
  const VaultCipherError(this.code);

  final VaultCipherErrorCode code;

  @override
  String toString() => 'VaultCipherError(${code.name})';
}

/// The cipher port consumed by `Vault.open` before any schema access.
abstract interface class VaultCipher {
  /// Applies the key to a raw connection. Runs first, before any other
  /// statement on that connection.
  void applyKey(Database raw, String keyHex);

  /// Verifies the cipher build is present. Throws [VaultCipherError] with
  /// [VaultCipherErrorCode.cipherAbsent] when it is not.
  void verifyCipher(Database raw);

  /// Proves the key decrypts: an authenticated read plus the cipher
  /// integrity check. Throws [VaultCipherError] on failure.
  void authenticatedRead(Database raw);
}

/// The production adapter. Fails closed everywhere until the pinned
/// SQLCipher device build passes DB-A (DECISION-PENDING: T07-CIPHER-BUILD).
final class SqlCipherVaultCipher implements VaultCipher {
  const SqlCipherVaultCipher();

  @override
  void applyKey(Database raw, String keyHex) {
    // SQLCipher raw key form: `PRAGMA key = "x'<hex>'"`. The hex string holds
    // key bytes only (base16), never user text.
    final hex = keyHex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    raw.execute("PRAGMA key = \"x'$hex'\"");
  }

  @override
  void verifyCipher(Database raw) {
    final rows = raw.select('PRAGMA cipher_version');
    if (rows.isEmpty) {
      throw const VaultCipherError(VaultCipherErrorCode.cipherAbsent);
    }
    final version = rows.first.values.first;
    if (version == null || version.toString().isEmpty) {
      throw const VaultCipherError(VaultCipherErrorCode.cipherAbsent);
    }
  }

  @override
  void authenticatedRead(Database raw) {
    try {
      final check = raw.select('PRAGMA cipher_integrity_check');
      if (check.isNotEmpty) {
        // Any reported row is an integrity failure (DATABASE_DESIGN 10).
        throw const VaultCipherError(VaultCipherErrorCode.integrity);
      }
      // An authenticated read over the schema; a wrong key surfaces here.
      raw.select('SELECT count(*) FROM sqlite_master');
    } on VaultCipherError {
      rethrow;
    } on SqliteException {
      throw const VaultCipherError(VaultCipherErrorCode.wrongKey);
    }
  }
}

/// Synthetic-data adapter for Phase 1 tests and development only (PF-01).
/// It applies no key and provides no confidentiality. Never reachable from
/// release code paths that hold user data.
///
/// DECISION-PENDING: T07-CIPHER-BUILD.
final class UnverifiedOpenCipher implements VaultCipher {
  const UnverifiedOpenCipher();

  @override
  void applyKey(Database raw, String keyHex) {}

  @override
  void verifyCipher(Database raw) {}

  @override
  void authenticatedRead(Database raw) {}
}
