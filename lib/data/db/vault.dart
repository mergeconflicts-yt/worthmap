// T07 (SYSTEM_DESIGN 2, 5.1; DATABASE_DESIGN 2): the one encrypted vault.
//
// Open sequence, fail closed at every step:
//   1. the key source must return a key, else `missingKey`;
//   2. the cipher port applies the key BEFORE any schema access;
//   3. the cipher build is verified (`cipher_version`);
//   4. connection settings are applied and verified on every open;
//   5. an authenticated read proves the key decrypts (wrong key fails closed);
//   6. the schema is created fresh (one transaction) or its version verified;
//   7. the long-lived owner connection opens with the same key and settings
//      (SYSTEM_DESIGN 4: SQL runs in a persistent database-owner isolate).
//
// A populated vault never gets recreated as empty. Failures surface as
// [VaultOpenError] with safe codes only (AGENTS 2.6).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app_database.dart';
import 'cipher.dart';
import 'connection_settings.dart';
import 'migration.dart';

/// Typed, safe vault failure codes.
enum VaultOpenErrorCode {
  /// No key was available. Never defaults to an open vault.
  missingKey,

  /// The cipher build is absent. Fail closed.
  cipherAbsent,

  /// The key does not open this vault. Fail closed; never a fresh empty app.
  wrongKey,

  /// A required connection setting could not be applied or verified.
  settingsViolation,

  /// The vault state is corrupt or unsupported (see [SchemaErrorCode]).
  schemaState,

  /// The file could not be opened.
  ioFailure,
}

class VaultOpenError implements Exception {
  const VaultOpenError(this.code, {this.detail});

  final VaultOpenErrorCode code;

  /// A safe detail string (setting names, versions). Never personal data.
  final String? detail;

  @override
  String toString() =>
      'VaultOpenError(${code.name}${detail == null ? '' : ': $detail'})';
}

/// Builds the new vault epoch id (UUID v7). The app layer injects its clock
/// and randomness; the vault itself reads no wall clock (AGENTS 6.3).
typedef VaultEpochFactory = String Function();

/// The open vault: one owner database plus the epoch identity.
final class Vault {
  Vault._(this.database, this.dbEpoch);

  /// The owner database connection.
  final AppDatabase database;

  /// The epoch of this generation (`db_state.db_epoch`).
  final String dbEpoch;

  /// Opens (or creates) the vault at [path]. [dbEpochFactory] supplies the
  /// epoch id only for a fresh create; an existing vault keeps its stored
  /// epoch.
  static Future<Vault> open({
    required String path,
    required VaultCipher cipher,
    required String Function() keySource,
    required VaultEpochFactory dbEpochFactory,
  }) async {
    final hasContent = vaultFileHasContent(path);
    final Database raw;
    try {
      raw = sqlite3.open(path);
    } on Object {
      throw const VaultOpenError(VaultOpenErrorCode.ioFailure);
    }
    try {
      final epoch = hasContent ? null : dbEpochFactory();
      _prepareRaw(raw, cipher: cipher, keySource: keySource, expectWal: true);
      if (hasContent) {
        verifyExistingVault(raw);
      } else {
        createFreshVault(raw, dbEpoch: epoch!);
      }
      final storedEpoch = raw
          .select('SELECT db_epoch FROM db_state WHERE singleton = 1')
          .first
          .values
          .first as String;

      final executor = NativeDatabase.createInBackground(
        File(path),
        enableMigrations: false,
        setup: (connection) {
          // The owner connection re-applies the key and settings on every
          // open (SYSTEM_DESIGN 5.1: verify settings on every connection).
          cipher.applyKey(connection, keySource());
          ConnectionSettings.apply(connection, expectWal: true);
          ConnectionSettings.verify(connection, expectWal: true);
        },
      );
      final db = AppDatabase(executor);
      // Force the owner connection open; a failure here fails the whole open.
      try {
        final rows = await db
            .customSelect(
              'SELECT schema_version FROM db_state WHERE singleton = 1',
            )
            .get();
        if (rows.isEmpty || rows.first.data['schema_version'] == null) {
          throw const VaultOpenError(VaultOpenErrorCode.schemaState);
        }
      } on Object {
        await executor.close();
        rethrow;
      }
      return Vault._(db, storedEpoch);
    } on VaultCipherError catch (e) {
      throw VaultOpenError(_cipherToOpen(e.code));
    } on VaultSettingsError catch (e) {
      throw VaultOpenError(
        VaultOpenErrorCode.settingsViolation,
        detail: e.setting,
      );
    } on SchemaError catch (e) {
      throw VaultOpenError(
        VaultOpenErrorCode.schemaState,
        detail: '${e.code.name}${e.version == null ? '' : ' ${e.version}'}',
      );
    } finally {
      raw.close();
    }
  }

  /// Opens a synthetic in-memory vault for tests (PF-01: no persisted data).
  static Future<Vault> openInMemory({
    required VaultCipher cipher,
    required String Function() keySource,
    required VaultEpochFactory dbEpochFactory,
  }) async {
    final raw = sqlite3.openInMemory();
    try {
      _prepareRaw(raw, cipher: cipher, keySource: keySource, expectWal: false);
      createFreshVault(raw, dbEpoch: dbEpochFactory());
      final storedEpoch = raw
          .select('SELECT db_epoch FROM db_state WHERE singleton = 1')
          .first
          .values
          .first as String;

      final db = AppDatabase(
        NativeDatabase.opened(raw, enableMigrations: false),
      );
      return Vault._(db, storedEpoch);
    } on VaultCipherError catch (e) {
      raw.close();
      throw VaultOpenError(_cipherToOpen(e.code));
    } on VaultSettingsError catch (e) {
      raw.close();
      throw VaultOpenError(
        VaultOpenErrorCode.settingsViolation,
        detail: e.setting,
      );
    } on Object {
      raw.close();
      rethrow;
    }
  }

  /// The shared raw-connection preparation: key, cipher, settings,
  /// authenticated read. Throws typed failures in that order.
  static void _prepareRaw(
    Database raw, {
    required VaultCipher cipher,
    required String Function() keySource,
    required bool expectWal,
  }) {
    final key = keySource();
    if (key.isEmpty) {
      throw const VaultOpenError(VaultOpenErrorCode.missingKey);
    }
    cipher.applyKey(raw, key);
    cipher.verifyCipher(raw);
    ConnectionSettings.apply(raw, expectWal: expectWal);
    ConnectionSettings.verify(raw, expectWal: expectWal);
    cipher.authenticatedRead(raw);
  }

  static VaultOpenErrorCode _cipherToOpen(VaultCipherErrorCode code) {
    return switch (code) {
      VaultCipherErrorCode.cipherAbsent => VaultOpenErrorCode.cipherAbsent,
      VaultCipherErrorCode.wrongKey => VaultOpenErrorCode.wrongKey,
      VaultCipherErrorCode.integrity => VaultOpenErrorCode.wrongKey,
    };
  }

  /// Closes the owner connection.
  Future<void> close() => database.executor.close();
}
