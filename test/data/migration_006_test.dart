// P12: schema version 6 (the classification family) and its upgrade.
//
// A fresh vault creates the reference version 5 body and then migration 6 in
// the same transaction. An existing version 5 vault upgrades in one
// transaction; a failure leaves it at 5 and closed.

import 'package:contour/data/db/db.dart';
import 'package:contour/data/db/schema/reference_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const String _epoch = '00000000-0000-7000-8000-000000000001';

Database _versionFiveDatabase() {
  final raw = sqlite3.openInMemory();
  for (final statement in splitSqlStatements(referenceSchemaSql)) {
    raw.execute(statement);
  }
  raw.execute(
    'INSERT INTO db_state (singleton, db_epoch, commit_sequence, '
    'schema_version, network_policy_epoch, network_enabled, read_revision) '
    'VALUES (1, ?, 0, 5, 0, 0, 0)',
    [_epoch],
  );
  return raw;
}

Set<String> _tables(Database raw) => <String>{
      for (final row in raw.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'search_fts_%'",
      ))
        row['name'] as String,
    };

void main() {
  test('a fresh vault keeps the classification family at the current version',
      () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      final tables = _tables(raw);
      expect(tables, contains('category_rules'));
      expect(tables, contains('tags'));
      expect(tables, contains('transaction_tags'));
      final state = raw.select('SELECT schema_version FROM db_state').first;
      expect(state['schema_version'], 9);
      final triggers = raw
          .select(
            "SELECT count(*) AS n FROM sqlite_master WHERE type = 'trigger' "
            "AND name IN ('tags_identity', 'category_rules_identity', "
            "'transaction_tags_guard') ",
          )
          .first;
      expect(triggers['n'], 2);
    } finally {
      raw.close();
    }
  });

  test('a version 5 vault upgrades in place and keeps its data', () {
    final raw = _versionFiveDatabase();
    try {
      raw.execute(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        'VALUES (?, 1, 1, NULL, 1, ?, NULL, ?, 0, 0)',
        ['00000000-0000-7000-8000-0000000000c1', 'Kept', 'expense'],
      );
      expect(_tables(raw), isNot(contains('tags')));

      final version = verifyExistingVault(raw);

      expect(version, 9);
      expect(_tables(raw), contains('tags'));
      final stored = raw
          .select('SELECT schema_version FROM db_state WHERE singleton = 1')
          .first;
      expect(stored['schema_version'], 9);
      final kept = raw.select(
        'SELECT name FROM categories WHERE id = ?',
        ['00000000-0000-7000-8000-0000000000c1'],
      );
      expect(kept.single['name'], 'Kept');
    } finally {
      raw.close();
    }
  });

  test('a failed upgrade stays at version 5 and closes', () {
    final raw = _versionFiveDatabase();
    try {
      // A conflicting table makes the migration fail after its first
      // statement; the whole transaction must roll back.
      raw.execute('CREATE TABLE tags (id TEXT)');
      expect(
        () => verifyExistingVault(raw),
        throwsA(
          isA<SchemaError>().having(
            (e) => e.code,
            'code',
            SchemaErrorCode.migrationFailed,
          ),
        ),
      );
      final version = raw
          .select('SELECT schema_version FROM db_state')
          .first['schema_version'];
      expect(version, 5);
      expect(_tables(raw), isNot(contains('category_rules')));
    } finally {
      raw.close();
    }
  });

  test('a version 4 vault still fails closed', () {
    final raw = _versionFiveDatabase();
    try {
      raw.execute('UPDATE db_state SET schema_version = 4');
      expect(
        () => verifyExistingVault(raw),
        throwsA(
          isA<SchemaError>().having(
            (e) => e.code,
            'code',
            SchemaErrorCode.oldSchemaUnsupported,
          ),
        ),
      );
    } finally {
      raw.close();
    }
  });

  test('an authored rule and tag write history identity', () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      raw.execute(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        'VALUES (?, 1, 1, NULL, 1, ?, NULL, ?, 0, 0)',
        ['00000000-0000-7000-8000-0000000000c1', 'Groceries', 'expense'],
      );
      raw.execute(
        'INSERT INTO tags (id, created_at, updated_at, deleted_at, revision, '
        'name) VALUES (?, 1, 1, NULL, 1, ?)',
        ['00000000-0000-7000-8000-0000000000d1', 'Household'],
      );
      raw.execute(
        'INSERT INTO category_rules (id, created_at, updated_at, deleted_at, '
        'revision, match_type, pattern, category_id, priority, created_from, '
        'hit_count) VALUES (?, 1, 1, NULL, 1, ?, ?, ?, 0, ?, 0)',
        [
          '00000000-0000-7000-8000-0000000000e1',
          'merchantContains',
          'market',
          '00000000-0000-7000-8000-0000000000c1',
          'user',
        ],
      );
      final kinds = raw.select(
        'SELECT entity_kind FROM entity_registry WHERE id IN (?, ?) '
        'ORDER BY entity_kind',
        [
          '00000000-0000-7000-8000-0000000000d1',
          '00000000-0000-7000-8000-0000000000e1',
        ],
      );
      expect(
        kinds.map((row) => row['entity_kind']).toList(),
        <String>['category_rules', 'tags'],
      );
      // Authored rows only soft-delete.
      expect(
        () => raw.execute(
          'DELETE FROM tags WHERE id = ?',
          ['00000000-0000-7000-8000-0000000000d1'],
        ),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      raw.close();
    }
  });
}
