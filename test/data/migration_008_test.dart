// P16: schema version 8 adds `schedules.auto_create` and `price_changes`.
//
// A fresh vault creates the reference body and migrations 6-8 in one
// transaction. A version 7 vault upgrades in one transaction; a failure stays
// at 7 and closed. A price change is an authored observation with identity,
// revision and soft-delete guards.

import 'package:contour/data/db/db.dart';
import 'package:contour/data/db/migrations/v006_classification.dart';
import 'package:contour/data/db/migrations/v007_budgets.dart';
import 'package:contour/data/db/schema/reference_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const String _epoch = '00000000-0000-7000-8000-000000000001';
const String _schedule = '00000000-0000-7000-8000-0000000000a1';
const String _price = '00000000-0000-7000-8000-0000000000b1';

Database _versionSevenDatabase() {
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
  raw.execute(
    'INSERT INTO db_state (singleton, db_epoch, commit_sequence, '
    'schema_version, network_policy_epoch, network_enabled, read_revision) '
    'VALUES (1, ?, 0, 7, 0, 0, 0)',
    [_epoch],
  );
  return raw;
}

Set<String> _columns(Database raw, String table) => <String>{
      for (final row in raw.select('PRAGMA table_info($table)'))
        row['name'] as String,
    };

void main() {
  test('a fresh vault creates version 8 with auto_create and price_changes',
      () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      final state = raw.select('SELECT schema_version FROM db_state').first;
      expect(state['schema_version'], 10);
      expect(_columns(raw, 'schedules'), contains('auto_create'));
      final tables = raw.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'price_changes'",
      );
      expect(tables, hasLength(1));
    } finally {
      raw.close();
    }
  });

  test('a version 7 vault upgrades in place and keeps its data', () {
    final raw = _versionSevenDatabase();
    try {
      raw.execute(
        'INSERT INTO currencies (code, minor_digits) VALUES (?, 2)',
        ['USD'],
      );
      raw.execute(
        'INSERT INTO schedules (id, created_at, updated_at, deleted_at, '
        'revision, name, kind, account_id, amount_minor, currency, '
        'amount_state, start_date, end_date, rrule, is_one_off) '
        "VALUES (?, 1, 1, NULL, 1, 'Rent', 'bill', NULL, 1000, 'USD', "
        "'known', '2026-01-01', NULL, 'FREQ=MONTHLY;BYMONTHDAY=1', 0)",
        [_schedule],
      );
      expect(_columns(raw, 'schedules'), isNot(contains('auto_create')));

      final version = verifyExistingVault(raw);

      expect(version, 10);
      expect(_columns(raw, 'schedules'), contains('auto_create'));
      final kept = raw.select(
        'SELECT name, auto_create FROM schedules WHERE id = ?',
        [_schedule],
      );
      expect(kept.single['name'], 'Rent');
      expect(kept.single['auto_create'], 0);
    } finally {
      raw.close();
    }
  });

  test('a failed version 7 upgrade stays at 7 and closes', () {
    final raw = _versionSevenDatabase();
    try {
      raw.execute('CREATE TABLE price_changes (id TEXT)');
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
      expect(version, 7);
      expect(_columns(raw, 'schedules'), isNot(contains('auto_create')));
    } finally {
      raw.close();
    }
  });

  test('an authored price change writes history identity', () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      raw.execute(
        'INSERT INTO currencies (code, minor_digits) VALUES (?, 2)',
        ['USD'],
      );
      raw.execute(
        'INSERT INTO schedules (id, created_at, updated_at, deleted_at, '
        'revision, name, kind, account_id, amount_minor, currency, '
        'amount_state, start_date, end_date, rrule, is_one_off, auto_create) '
        "VALUES (?, 1, 1, NULL, 1, 'Netflix', 'subscription', NULL, 1549, "
        "'USD', 'known', '2026-01-01', NULL, "
        "'FREQ=MONTHLY;BYMONTHDAY=1', 0, 0)",
        [_schedule],
      );
      raw.execute(
        'INSERT INTO price_changes (id, created_at, updated_at, deleted_at, '
        'revision, schedule_id, date, old_minor, new_minor, currency) '
        "VALUES (?, 1, 1, NULL, 1, ?, '2026-03-01', 1549, 1799, 'USD')",
        [_price, _schedule],
      );
      final kind = raw.select(
        'SELECT entity_kind FROM entity_registry WHERE id = ?',
        [_price],
      ).single['entity_kind'];
      expect(kind, 'price_changes');
      expect(
        () => raw.execute('DELETE FROM price_changes WHERE id = ?', [_price]),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      raw.close();
    }
  });

  test('an unchanged price is not a price change', () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      raw.execute(
        'INSERT INTO currencies (code, minor_digits) VALUES (?, 2)',
        ['USD'],
      );
      raw.execute(
        'INSERT INTO schedules (id, created_at, updated_at, deleted_at, '
        'revision, name, kind, account_id, amount_minor, currency, '
        'amount_state, start_date, end_date, rrule, is_one_off, auto_create) '
        "VALUES (?, 1, 1, NULL, 1, 'Netflix', 'subscription', NULL, 1549, "
        "'USD', 'known', '2026-01-01', NULL, "
        "'FREQ=MONTHLY;BYMONTHDAY=1', 0, 0)",
        [_schedule],
      );
      expect(
        () => raw.execute(
          'INSERT INTO price_changes (id, created_at, updated_at, deleted_at, '
          'revision, schedule_id, date, old_minor, new_minor, currency) '
          "VALUES (?, 1, 1, NULL, 1, ?, '2026-03-01', 1549, 1549, 'USD')",
          [_price, _schedule],
        ),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      raw.close();
    }
  });
}
