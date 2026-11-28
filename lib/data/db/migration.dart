// T07 (DATABASE_DESIGN 5.1 migration contract, 10): the schema migration.
//
// The generated constant is the verbatim body of the executable structural
// reference SCHEMA.sql (schema version 5). A fresh vault runs the whole body
// in ONE transaction and seeds the `db_state` singleton. The reference
// BEGIN/COMMIT wrapper is not nested (DB4-10); pragmas are connection settings.
//
// DECISION-PENDING: T07-MIGRATION-SOURCES. The reference upgrade scripts
// (`002_shared_state.sql` … `005_layout_sections.sql`) and their frozen
// version 1.1–1.4 fixtures are absent from this checkout. Old-version
// upgrades therefore fail closed with a typed, safe code and stay gate DB-B
// (DATABASE_DESIGN 11). Fresh installs start at the current reference version.
// Upgrading a real released database is blocked until the source scripts and
// fixtures return; no invented migration runs in the meantime.
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'migrations/v006_classification.dart';
import 'migrations/v007_budgets.dart';
import 'migrations/v008_repeating.dart';
import 'migrations/v009_categories.dart';
import 'schema/reference_schema.dart';
import 'statement_splitter.dart';

export 'schema/reference_schema.dart' show kReferenceTableNames;

/// The current schema version: the reference body plus migrations 6-9.
const int kCurrentSchemaVersion = 9;

/// Typed, safe migration failure codes.
enum SchemaErrorCode {
  /// The file holds data but no `db_state` row. Never reset or recreate.
  corruptState,

  /// A newer, unsupported schema. Fail closed; never downgrade (DATABASE_DESIGN 10).
  newerSchema,

  /// An older schema without its source migration script. Fail closed.
  oldSchemaUnsupported,

  /// A known upgrade failed; the vault is unchanged and stays closed.
  migrationFailed,
}

class SchemaError implements Exception {
  const SchemaError(this.code, {this.version});

  final SchemaErrorCode code;
  final int? version;

  @override
  String toString() => 'SchemaError(${code.name}'
      '${version == null ? '' : ', version $version'})';
}

/// Creates a fresh vault: the whole reference DDL plus the `db_state`
/// singleton row, inside one transaction that rolls back completely on error.
void createFreshVault(
  Database raw, {
  required String dbEpoch,
}) {
  raw.execute('BEGIN IMMEDIATE');
  try {
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
      'VALUES (1, ?, 0, ?, 0, 0, 0)',
      [dbEpoch, kCurrentSchemaVersion],
    );
    raw.execute('COMMIT');
  } on Object {
    // A failed create rolls back to an empty file; the caller decides whether
    // a fresh retry is legitimate (it is only for a non-existing vault).
    try {
      raw.execute('ROLLBACK');
    } on Object {
      // A ROLLBACK without an open transaction is fine at this point.
    }
    rethrow;
  }
}

/// Reads the `db_state` singleton after the cipher and settings pass.
/// Throws [SchemaError] for a corrupt, newer or too-old vault. Returns the
/// stored schema version when the vault is usable.
int verifyExistingVault(Database raw) {
  final List<Row> state;
  try {
    state = raw.select(
      'SELECT db_epoch, schema_version FROM db_state WHERE singleton = 1',
    );
  } on SqliteException {
    // The state table is gone or unreadable: a corrupt vault, never a fresh
    // install. Fail closed.
    throw const SchemaError(SchemaErrorCode.corruptState);
  }
  if (state.isEmpty) {
    throw const SchemaError(SchemaErrorCode.corruptState);
  }
  final version = state.first.values[1];
  if (version is! int) {
    throw const SchemaError(SchemaErrorCode.corruptState);
  }
  if (version > kCurrentSchemaVersion) {
    throw SchemaError(SchemaErrorCode.newerSchema, version: version);
  }
  if (version < kCurrentSchemaVersion) {
    // Version 5 is the reference release; it applies migrations 6 and 7 in
    // one transaction. Version 6 applies migration 7. Older versions still
    // need their absent reference scripts and fail closed (DB-B).
    if (version == 5) {
      _upgradeFromV5(raw);
      return kCurrentSchemaVersion;
    }
    if (version == 6) {
      _upgradeFromV6(raw);
      return kCurrentSchemaVersion;
    }
    if (version == 7) {
      _upgradeFromV7(raw);
      return kCurrentSchemaVersion;
    }
    if (version == 8) {
      _upgradeFromV8(raw);
      return kCurrentSchemaVersion;
    }
    throw SchemaError(
      SchemaErrorCode.oldSchemaUnsupported,
      version: version,
    );
  }
  return version;
}

/// True when the vault file exists with content. An absent or zero-byte file
/// is a legitimate fresh install target; a populated file without usable
/// state never gets recreated as empty (SYSTEM_DESIGN 5.1).
bool vaultFileHasContent(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return false;
  }
  return file.lengthSync() > 0;
}

/// Applies schema versions 6 and 7 to a version 5 vault, in one transaction.
///
/// A failure rolls back every new object and the version stays 5, so the vault
/// is unchanged and the next open retries or fails closed.
void _upgradeFromV5(Database raw) {
  raw.execute('BEGIN IMMEDIATE');
  try {
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
      'UPDATE db_state SET schema_version = ? WHERE singleton = 1',
      [kCurrentSchemaVersion],
    );
    raw.execute('COMMIT');
  } on Object {
    try {
      raw.execute('ROLLBACK');
    } on Object {
      // A ROLLBACK without an open transaction is fine at this point.
    }
    throw const SchemaError(SchemaErrorCode.migrationFailed, version: 5);
  }
}

/// Applies schema versions 7 and 8 to a version 6 vault, in one transaction.
///
/// A failure rolls back every new object and the version stays 6, so the vault
/// is unchanged and the next open retries or fails closed.
void _upgradeFromV6(Database raw) {
  raw.execute('BEGIN IMMEDIATE');
  try {
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
      'UPDATE db_state SET schema_version = ? WHERE singleton = 1',
      [kCurrentSchemaVersion],
    );
    raw.execute('COMMIT');
  } on Object {
    try {
      raw.execute('ROLLBACK');
    } on Object {
      // A ROLLBACK without an open transaction is fine at this point.
    }
    throw const SchemaError(SchemaErrorCode.migrationFailed, version: 6);
  }
}

/// Applies schema version 8 to a version 7 vault, in one transaction.
///
/// A failure rolls back every new object and the version stays 7, so the vault
/// is unchanged and the next open retries or fails closed.
void _upgradeFromV7(Database raw) {
  raw.execute('BEGIN IMMEDIATE');
  try {
    for (final statement in splitSqlStatements(migrationV8Sql)) {
      raw.execute(statement);
    }
    for (final statement in splitSqlStatements(migrationV9Sql)) {
      raw.execute(statement);
    }
    raw.execute(
      'UPDATE db_state SET schema_version = ? WHERE singleton = 1',
      [kCurrentSchemaVersion],
    );
    raw.execute('COMMIT');
  } on Object {
    try {
      raw.execute('ROLLBACK');
    } on Object {
      // A ROLLBACK without an open transaction is fine at this point.
    }
    throw const SchemaError(SchemaErrorCode.migrationFailed, version: 7);
  }
}

/// Applies schema version 9 to a version 8 vault, in one transaction.
///
/// A failure rolls back the new column and the version stays 8, so the vault
/// is unchanged and the next open retries or fails closed.
void _upgradeFromV8(Database raw) {
  raw.execute('BEGIN IMMEDIATE');
  try {
    for (final statement in splitSqlStatements(migrationV9Sql)) {
      raw.execute(statement);
    }
    raw.execute(
      'UPDATE db_state SET schema_version = ? WHERE singleton = 1',
      [kCurrentSchemaVersion],
    );
    raw.execute('COMMIT');
  } on Object {
    try {
      raw.execute('ROLLBACK');
    } on Object {
      // A ROLLBACK without an open transaction is fine at this point.
    }
    throw const SchemaError(SchemaErrorCode.migrationFailed, version: 8);
  }
}
