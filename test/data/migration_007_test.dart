// P15: schema version 7 (the budget family) and its upgrade.
//
// A fresh vault creates the reference version 5 body, migration 6 and then
// migration 7 in one transaction. An existing version 6 vault upgrades in one
// transaction; a failure leaves it at 6 and closed. Authored budget rows keep
// the reference identity, revision and soft-delete guards.

import 'package:contour/data/db/db.dart';
import 'package:contour/data/db/migrations/v006_classification.dart';
import 'package:contour/data/db/schema/reference_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const String _epoch = '00000000-0000-7000-8000-000000000001';
const String _category = '00000000-0000-7000-8000-0000000000c1';
const String _budget = '00000000-0000-7000-8000-0000000000b1';
const String _limit = '00000000-0000-7000-8000-0000000000b2';

Database _versionSixDatabase() {
  final raw = sqlite3.openInMemory();
  for (final statement in splitSqlStatements(referenceSchemaSql)) {
    raw.execute(statement);
  }
  for (final statement in splitSqlStatements(migrationV6Sql)) {
    raw.execute(statement);
  }
  raw.execute(
    'INSERT INTO db_state (singleton, db_epoch, commit_sequence, '
    'schema_version, network_policy_epoch, network_enabled, read_revision) '
    'VALUES (1, ?, 0, 6, 0, 0, 0)',
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
  test('a fresh vault keeps the budget family at the current version', () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      final tables = _tables(raw);
      expect(tables, contains('budgets'));
      expect(tables, contains('budget_limits'));
      expect(tables, contains('budget_templates'));
      final state = raw.select('SELECT schema_version FROM db_state').first;
      expect(state['schema_version'], 8);
      final triggers = raw
          .select(
            "SELECT count(*) AS n FROM sqlite_master WHERE type = 'trigger' "
            "AND name IN ('budgets_identity', 'budget_limits_identity', "
            "'budget_templates_identity', 'budgets_retain', "
            "'budget_limits_retain', 'budget_templates_retain')",
          )
          .first;
      expect(triggers['n'], 6);
    } finally {
      raw.close();
    }
  });

  test('a version 6 vault upgrades in place and keeps its data', () {
    final raw = _versionSixDatabase();
    try {
      raw.execute(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        'VALUES (?, 1, 1, NULL, 1, ?, NULL, ?, 0, 0)',
        [_category, 'Kept', 'expense'],
      );
      expect(_tables(raw), isNot(contains('budgets')));

      final version = verifyExistingVault(raw);

      expect(version, 8);
      expect(_tables(raw), contains('budgets'));
      final stored = raw
          .select('SELECT schema_version FROM db_state WHERE singleton = 1')
          .first;
      expect(stored['schema_version'], 8);
      final kept = raw.select(
        'SELECT name FROM categories WHERE id = ?',
        [_category],
      );
      expect(kept.single['name'], 'Kept');
    } finally {
      raw.close();
    }
  });

  test('a failed version 6 upgrade stays at 6 and closes', () {
    final raw = _versionSixDatabase();
    try {
      // A conflicting table makes the migration fail after its first
      // statement; the whole transaction must roll back.
      raw.execute('CREATE TABLE budgets (id TEXT)');
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
      expect(version, 6);
      expect(_tables(raw), isNot(contains('budget_limits')));
    } finally {
      raw.close();
    }
  });

  test('an authored budget, limit and template write history identity', () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      raw.execute(
        "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
      );
      raw.execute(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        'VALUES (?, 1, 1, NULL, 1, ?, NULL, ?, 0, 0)',
        [_category, 'Groceries', 'expense'],
      );
      raw.execute(
        'INSERT INTO budgets (id, created_at, updated_at, deleted_at, '
        'revision, month, period_type, name, currency, start_date, end_date) '
        "VALUES (?, 1, 1, NULL, 1, '2026-10', 'monthly', NULL, 'USD', "
        "'2026-10-01', '2026-10-31')",
        [_budget],
      );
      raw.execute(
        'INSERT INTO budget_limits (id, created_at, updated_at, deleted_at, '
        'revision, budget_id, category_id, limit_minor, currency) '
        'VALUES (?, 1, 1, NULL, 1, ?, ?, 120000, ?)',
        [_limit, _budget, _category, 'USD'],
      );
      final kinds = raw.select(
        'SELECT entity_kind FROM entity_registry WHERE id IN (?, ?) '
        'ORDER BY entity_kind',
        [_budget, _limit],
      );
      expect(
        kinds.map((row) => row['entity_kind']).toList(),
        <String>['budget_limits', 'budgets'],
      );
      // An authored row only soft-deletes.
      expect(
        () => raw.execute('DELETE FROM budget_limits WHERE id = ?', [_limit]),
        throwsA(isA<SqliteException>()),
      );
      // A revision must advance by at least one.
      expect(
        () => raw.execute(
          'UPDATE budget_limits SET limit_minor = 1 WHERE id = ?',
          [_limit],
        ),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      raw.close();
    }
  });

  test('a budget month has one live row and a limit pair is unique', () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      raw.execute(
        "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
      );
      raw.execute(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        'VALUES (?, 1, 1, NULL, 1, ?, NULL, ?, 0, 0)',
        [_category, 'Groceries', 'expense'],
      );
      raw.execute(
        'INSERT INTO budgets (id, created_at, updated_at, deleted_at, '
        'revision, month, period_type, name, currency, start_date, end_date) '
        "VALUES (?, 1, 1, NULL, 1, '2026-10', 'monthly', NULL, 'USD', "
        "'2026-10-01', '2026-10-31')",
        [_budget],
      );
      expect(
        () => raw.execute(
          'INSERT INTO budgets (id, created_at, updated_at, deleted_at, '
          'revision, month, period_type, name, currency, start_date, end_date) '
          "VALUES (?, 1, 1, NULL, 1, '2026-10', 'monthly', NULL, 'USD', "
          "'2026-10-01', '2026-10-31')",
          ['00000000-0000-7000-8000-0000000000b9'],
        ),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      raw.close();
    }
  });
}
