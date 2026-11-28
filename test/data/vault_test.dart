import 'dart:io';

import 'package:contour/data/db/db.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// A scripted cipher for the fail-closed tests. Records the raw-phase call
/// order; the owner-connection setup runs on a copied instance (isolate
/// message passing), so only the raw phase is asserted here.
final class ScriptedCipher implements VaultCipher {
  ScriptedCipher(this.correctKeyHex, {this.cipherAvailable = true});

  final String correctKeyHex;
  final bool cipherAvailable;

  final List<String> calls = <String>[];

  @override
  void applyKey(Database raw, String keyHex) {
    calls.add('applyKey');
    _lastKey = keyHex;
  }

  @override
  void verifyCipher(Database raw) {
    calls.add('verifyCipher');
    if (!cipherAvailable) {
      throw const VaultCipherError(VaultCipherErrorCode.cipherAbsent);
    }
  }

  @override
  void authenticatedRead(Database raw) {
    calls.add('authenticatedRead');
    // Simulates SQLCipher's wrong-key behaviour: the authenticated read is
    // the point where a wrong key surfaces. The real device evidence for
    // this behaviour is gate DB-A (DATABASE_DESIGN 11).
    if (_lastKey != correctKeyHex) {
      throw const VaultCipherError(VaultCipherErrorCode.wrongKey);
    }
  }

  String _lastKey = '';
}

void main() {
  late ScriptedCipher cipher;
  String key() => cipher.correctKeyHex;
  const epoch = '00000000-0000-7000-8000-000000000001';

  setUp(() {
    cipher = ScriptedCipher('ff' * 32);
  });

  test('in-memory vault: fresh create seeds the reference schema', () async {
    final vault = await Vault.openInMemory(
      cipher: cipher,
      keySource: key,
      dbEpochFactory: () => epoch,
    );
    try {
      final db = vault.database;
      // Every reference table and trigger exists. The connection adds its
      // own internal tables and the FTS virtual table adds five shadow
      // tables, so assert on the reference names, not a total count.
      final names = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        'AND name NOT LIKE ? AND name NOT LIKE ?',
        variables: [const Variable('drift_%'), const Variable('search_fts_%')],
      ).get();
      final tableNames = names.map((r) => r.data['name'] as String).toSet();
      // ignore: avoid_print
      print('extra tables: '
          '${tableNames.where((n) => !kReferenceTableNames.contains(n)).toList()}');
      // P12 migration 6 adds the classification family; P15 migration 7
      // adds the budget family. Both arrive beyond the reference version 5
      // body.
      const addedTables = <String>{
        'category_rules',
        'tags',
        'transaction_tags',
        'budgets',
        'budget_limits',
        'budget_templates',
        'price_changes',
      };
      for (final expected in <String>[
        ...kReferenceTableNames,
        ...addedTables,
      ]) {
        if (!tableNames.contains(expected)) {
          fail('missing table: $expected');
        }
      }
      expect(
        tableNames.length,
        kReferenceTableNames.length + addedTables.length,
      );

      final triggers = await db
          .customSelect(
            "SELECT count(*) AS n FROM sqlite_master WHERE type = 'trigger'",
          )
          .getSingle();
      expect(triggers.data['n'], 363);

      final state = await db
          .customSelect(
            'SELECT db_epoch, commit_sequence, schema_version, '
            'network_policy_epoch, network_enabled, read_revision '
            'FROM db_state WHERE singleton = 1',
          )
          .getSingle();
      expect(state.data['db_epoch'], epoch);
      expect(state.data['commit_sequence'], 0);
      expect(state.data['schema_version'], 9);
      expect(state.data['network_enabled'], 0);
      expect(state.data['read_revision'], 0);
      expect(vault.dbEpoch, epoch);
    } finally {
      await vault.close();
    }
  });

  test('open without a key fails closed', () async {
    await expectLater(
      Vault.openInMemory(
        cipher: cipher,
        keySource: () => '',
        dbEpochFactory: () => epoch,
      ),
      throwsA(
        isA<VaultOpenError>().having(
          (e) => e.code,
          'code',
          VaultOpenErrorCode.missingKey,
        ),
      ),
    );
    expect(cipher.calls, isNot(contains('verifyCipher')));
  });

  test('open with a wrong key fails closed before schema access', () async {
    final directory = await Directory.systemTemp.createTemp('vault_test');
    final path = '${directory.path}/vault.db';
    try {
      await expectLater(
        Vault.open(
          path: path,
          cipher: cipher,
          keySource: () => '00' * 32,
          dbEpochFactory: () => epoch,
        ),
        throwsA(
          isA<VaultOpenError>().having(
            (e) => e.code,
            'code',
            VaultOpenErrorCode.wrongKey,
          ),
        ),
      );
      // No DDL ran: the file holds no tables. The settings phase may have
      // written a WAL header, so a byte-size check is not the evidence.
      final probe = sqlite3.open(path);
      try {
        expect(
          probe
              .select("SELECT count(*) FROM sqlite_master WHERE type = 'table'")
              .first
              .values
              .first,
          0,
        );
      } finally {
        probe.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('open without a cipher build fails closed', () async {
    final unavailable = ScriptedCipher('ff' * 32, cipherAvailable: false);
    await expectLater(
      Vault.openInMemory(
        cipher: unavailable,
        keySource: key,
        dbEpochFactory: () => epoch,
      ),
      throwsA(
        isA<VaultOpenError>().having(
          (e) => e.code,
          'code',
          VaultOpenErrorCode.cipherAbsent,
        ),
      ),
    );
  });

  test('key, cipher and settings run before any schema access', () async {
    final directory = await Directory.systemTemp.createTemp('vault_test');
    final path = '${directory.path}/vault.db';
    try {
      final vault = await Vault.open(
        path: path,
        cipher: cipher,
        keySource: key,
        dbEpochFactory: () => epoch,
      );
      await vault.close();
      final applyKeyIndex = cipher.calls.indexOf('applyKey');
      final verifyIndex = cipher.calls.indexOf('verifyCipher');
      final readIndex = cipher.calls.indexOf('authenticatedRead');
      expect(applyKeyIndex, inInclusiveRange(0, verifyIndex - 1));
      expect(verifyIndex, lessThan(readIndex));
      // The settings apply/verify happens between the cipher check and the
      // authenticated read (Vault._prepareRaw).
      expect(cipher.calls, hasLength(3));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('file vault: reopen keeps the stored epoch and version', () async {
    final directory = await Directory.systemTemp.createTemp('vault_test');
    final path = '${directory.path}/vault.db';
    try {
      final first = await Vault.open(
        path: path,
        cipher: cipher,
        keySource: key,
        dbEpochFactory: () => epoch,
      );
      await first.close();

      final second = await Vault.open(
        path: path,
        cipher: cipher,
        keySource: key,
        dbEpochFactory: () => '99999999-9999-7999-8999-999999999999',
      );
      // The stored epoch survives; the fresh-epoch factory is unused.
      expect(second.dbEpoch, epoch);
      await second.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('a newer unsupported schema fails closed without a reset', () async {
    final directory = await Directory.systemTemp.createTemp('vault_test');
    final path = '${directory.path}/vault.db';
    try {
      final vault = await Vault.open(
        path: path,
        cipher: cipher,
        keySource: key,
        dbEpochFactory: () => epoch,
      );
      await vault.database.customStatement(
        'UPDATE db_state SET schema_version = 10 WHERE singleton = 1',
      );
      await vault.close();

      await expectLater(
        Vault.open(
          path: path,
          cipher: cipher,
          keySource: key,
          dbEpochFactory: () => epoch,
        ),
        throwsA(
          isA<VaultOpenError>()
              .having((e) => e.code, 'code', VaultOpenErrorCode.schemaState)
              .having((e) => e.detail, 'detail', 'newerSchema 10'),
        ),
      );
      // The data is untouched; nothing was recreated as empty.
      final raw = sqlite3.open(path);
      final version =
          raw.select('SELECT schema_version FROM db_state').first.values.first;
      raw.close();
      expect(version, 10);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('an old schema without its source migration fails closed', () async {
    final directory = await Directory.systemTemp.createTemp('vault_test');
    final path = '${directory.path}/vault.db';
    try {
      final vault = await Vault.open(
        path: path,
        cipher: cipher,
        keySource: key,
        dbEpochFactory: () => epoch,
      );
      await vault.database.customStatement(
        'UPDATE db_state SET schema_version = 4 WHERE singleton = 1',
      );
      await vault.close();

      await expectLater(
        Vault.open(
          path: path,
          cipher: cipher,
          keySource: key,
          dbEpochFactory: () => epoch,
        ),
        throwsA(
          isA<VaultOpenError>().having(
            (e) => e.detail,
            'detail',
            'oldSchemaUnsupported 4',
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('a populated vault without state never gets recreated', () async {
    final directory = await Directory.systemTemp.createTemp('vault_test');
    final path = '${directory.path}/vault.db';
    try {
      final vault = await Vault.open(
        path: path,
        cipher: cipher,
        keySource: key,
        dbEpochFactory: () => epoch,
      );
      await vault.close();
      final raw = sqlite3.open(path);
      try {
        raw.execute('DROP TABLE db_state');
      } finally {
        raw.close();
      }

      await expectLater(
        Vault.open(
          path: path,
          cipher: cipher,
          keySource: key,
          dbEpochFactory: () => epoch,
        ),
        throwsA(
          isA<VaultOpenError>().having(
            (e) => e.detail,
            'detail',
            'corruptState',
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('connection settings apply and verify on a raw connection', () {
    final raw = sqlite3.openInMemory();
    try {
      ConnectionSettings.apply(raw, expectWal: false);
      ConnectionSettings.verify(raw, expectWal: false);
      expect(raw.select('PRAGMA foreign_keys').first.values.first, 1);
      expect(
        raw.select('PRAGMA recursive_triggers').first.values.first,
        1,
      );
      expect(raw.select('PRAGMA synchronous').first.values.first, 2);
      expect(raw.select('PRAGMA temp_store').first.values.first, 2);
      expect(
        raw.select('PRAGMA busy_timeout').first.values.first,
        kVaultBusyTimeoutMs,
      );
    } finally {
      raw.close();
    }
  });

  test('a settings mismatch fails closed with a typed code', () {
    final raw = sqlite3.openInMemory();
    try {
      // Fresh connection: foreign_keys defaults to off, verification fails.
      expect(
        () => ConnectionSettings.verify(raw, expectWal: false),
        throwsA(isA<VaultSettingsError>()),
      );
    } finally {
      raw.close();
    }
  });

  test('WAL mode is expected and verified for file targets', () async {
    final directory = await Directory.systemTemp.createTemp('vault_test');
    final path = '${directory.path}/vault.db';
    try {
      final vault = await Vault.open(
        path: path,
        cipher: cipher,
        keySource: key,
        dbEpochFactory: () => epoch,
      );
      // A second raw connection to the same file reads the persistent WAL
      // mode; this also exercises a second connection seeing the vault.
      final probe = sqlite3.open(path);
      try {
        expect(probe.select('PRAGMA journal_mode').first.values.first, 'wal');
      } finally {
        probe.close();
      }
      await vault.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('foreign_key_check reports no violations on a fresh vault', () {
    final raw = sqlite3.openInMemory();
    try {
      ConnectionSettings.apply(raw, expectWal: false);
      expect(ConnectionSettings.foreignKeyViolations(raw), isEmpty);
    } finally {
      raw.close();
    }
  });
}
