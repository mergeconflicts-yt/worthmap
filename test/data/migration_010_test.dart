// P4-02b: schema version 10 adds the value rule, card details and loan
// details.
//
// A fresh vault creates the reference body and migrations 6-10 in one
// transaction. A version 9 vault upgrades in one transaction and keeps its
// accounts. The rule is authored one-to-one metadata; a hard delete is
// refused and a write must bump the revision.

import 'package:contour/data/db/db.dart';
import 'package:contour/data/db/migrations/v006_classification.dart';
import 'package:contour/data/db/migrations/v007_budgets.dart';
import 'package:contour/data/db/migrations/v008_repeating.dart';
import 'package:contour/data/db/migrations/v009_categories.dart';
import 'package:contour/data/db/schema/reference_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const String _epoch = '00000000-0000-7000-8000-000000000001';
const String _account = '00000000-0000-7000-8000-0000000000a1';
const String _rule = '00000000-0000-7000-8000-0000000000b1';

Database _versionNineDatabase() {
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
  for (final statement in splitSqlStatements(migrationV9Sql)) {
    raw.execute(statement);
  }
  raw.execute(
    'INSERT INTO db_state (singleton, db_epoch, commit_sequence, '
    'schema_version, network_policy_epoch, network_enabled, read_revision) '
    'VALUES (1, ?, 0, 9, 0, 0, 0)',
    [_epoch],
  );
  return raw;
}

Set<String> _tables(Database raw) => <String>{
      for (final row in raw.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        row['name'] as String,
    };

void main() {
  test('a fresh vault creates version 10 with the three tables', () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      final state = raw.select('SELECT schema_version FROM db_state').first;
      expect(state['schema_version'], 10);
      expect(
        _tables(raw),
        containsAll(<String>[
          'valuation_rules',
          'card_details',
          'loan_details',
        ]),
      );
    } finally {
      raw.close();
    }
  });

  test('a version 9 vault upgrades in place and keeps its accounts', () {
    final raw = _versionNineDatabase();
    try {
      raw.execute(
        'INSERT INTO currencies (code, minor_digits) VALUES (?, 2)',
        ['USD'],
      );
      raw.execute(
        'INSERT INTO accounts (id, created_at, updated_at, deleted_at, '
        'revision, name, type, currency, institution, is_liability, '
        'is_liquid, include_in_net_worth, archived) '
        "VALUES (?, 1, 1, NULL, 1, 'Checking', 'bank', 'USD', NULL, "
        '0, 1, 1, 0)',
        [_account],
      );
      expect(_tables(raw), isNot(contains('valuation_rules')));

      final version = verifyExistingVault(raw);

      expect(version, 10);
      expect(_tables(raw), contains('valuation_rules'));
      final kept = raw.select(
        'SELECT name, currency FROM accounts WHERE id = ?',
        [_account],
      ).first;
      expect(kept['name'], 'Checking');
      expect(kept['currency'], 'USD');
      expect(
        raw
            .select('SELECT schema_version FROM db_state')
            .first['schema_version'],
        10,
      );
    } finally {
      raw.close();
    }
  });

  test('a rule is one per account and needs a JSON object', () {
    final raw = sqlite3.openInMemory();
    try {
      createFreshVault(raw, dbEpoch: _epoch);
      raw.execute(
        'INSERT INTO currencies (code, minor_digits) VALUES (?, 2)',
        ['USD'],
      );
      raw.execute(
        'INSERT INTO accounts (id, created_at, updated_at, deleted_at, '
        'revision, name, type, currency, institution, is_liability, '
        'is_liquid, include_in_net_worth, archived) '
        "VALUES (?, 1, 1, NULL, 1, 'Deposit', 'deposit', 'USD', NULL, "
        '0, 1, 1, 0)',
        [_account],
      );
      void insertRule(String id, String parameters) => raw.execute(
            'INSERT INTO valuation_rules (id, created_at, updated_at, '
            'deleted_at, revision, account_id, method, parameters_json) '
            'VALUES (?, 1, 1, NULL, 1, ?, ?, ?)',
            [id, _account, 'interest', parameters],
          );

      insertRule(_rule, '{"annualRate":"0.041"}');
      expect(
        () => insertRule(
          '00000000-0000-7000-8000-0000000000b2',
          '{"annualRate":"0.05"}',
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => raw.execute(
          'UPDATE valuation_rules SET parameters_json = ?, revision = 1 '
          'WHERE id = ?',
          ['not json', _rule],
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => raw.execute('DELETE FROM valuation_rules WHERE id = ?', [_rule]),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      raw.close();
    }
  });
}
