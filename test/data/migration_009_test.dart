// P4-HOME-SPLIT: schema version 9 adds `categories.is_essential`.
//
// A fresh vault creates the reference body and migrations 6-9 in one
// transaction. A version 8 vault upgrades in one transaction; a failure stays
// at 8 and closed. The tag is nullable: an untagged category has no label.

import 'package:contour/data/db/db.dart';
import 'package:contour/data/db/migrations/v006_classification.dart';
import 'package:contour/data/db/migrations/v007_budgets.dart';
import 'package:contour/data/db/migrations/v008_repeating.dart';
import 'package:contour/data/db/schema/reference_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const String _epoch = '00000000-0000-7000-8000-000000000001';
const String _category = '00000000-0000-7000-8000-0000000000c1';

Database _versionEightDatabase() {
  final raw = sqlite3.openInMemory();
  for (final statement in splitSqlStatements(referenceSchemaSql)) {
    raw.execute(statement);
  }
  for (final statement in splitSqlStatements(migrationV6Sql)) {
    raw.execute(statement);
  }
  for (final statement in splitSqlStatements(migrationV7Sql)) {
    raw.execute(statement);
  }
  for (final statement in splitSqlStatements(migrationV8Sql)) {
    raw.execute(statement);
  }
  raw.execute(
    'INSERT INTO db_state (singleton, db_epoch, commit_sequence, '
    'schema_version, network_policy_epoch, network_enabled, read_revision) '
    'VALUES (1, ?, 0, 8, 0, 0, 0)',
    [_epoch],
  );
  return raw;
}

Set<String> _columns(Database raw, String table) => <String>{
      for (final row in raw.select('PRAGMA table_info($table)'))
        row['name'] as String,
    };

void main() {
  test('a fresh vault creates the current version with is_essential', () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      final state = raw.select('SELECT schema_version FROM db_state').first;
      expect(state['schema_version'], 9);
      expect(_columns(raw, 'categories'), contains('is_essential'));
    } finally {
      raw.close();
    }
  });

  test('a version 8 vault upgrades in place and keeps its categories', () {
    final raw = _versionEightDatabase();
    try {
      raw.execute(
        'INSERT INTO currencies (code, minor_digits) VALUES (?, 2)',
        ['USD'],
      );
      raw.execute(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        "VALUES (?, 1, 1, NULL, 1, 'Groceries', NULL, 'expense', 0, 0)",
        [_category],
      );
      expect(_columns(raw, 'categories'), isNot(contains('is_essential')));

      final version = verifyExistingVault(raw);

      expect(version, 9);
      expect(_columns(raw, 'categories'), contains('is_essential'));
      final kept = raw.select(
        'SELECT name, is_essential FROM categories WHERE id = ?',
        [_category],
      );
      expect(kept.single['name'], 'Groceries');
      expect(kept.single['is_essential'], isNull);
    } finally {
      raw.close();
    }
  });

  test('a failed version 8 upgrade stays at 8 and closes', () {
    final raw = _versionEightDatabase();
    try {
      raw.execute(
        'ALTER TABLE categories ADD COLUMN is_essential INTEGER',
      );
      expect(
        () => verifyExistingVault(raw),
        throwsA(
          isA<SchemaError>().having(
            (error) => error.code,
            'code',
            SchemaErrorCode.migrationFailed,
          ),
        ),
      );
      final state = raw.select('SELECT schema_version FROM db_state').first;
      expect(state['schema_version'], 8);
    } finally {
      raw.close();
    }
  });
}
