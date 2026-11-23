// T07 (DATABASE_DESIGN 5.1, migration contract): generate the Drift-translated
// reference schema constant from the executable SCHEMA.sql structural reference.
//
// The reference script is a structural reference, not a production migration
// (DATABASE_DESIGN 11). This tool copies its body verbatim into a Dart constant
// so the migration runner executes exactly the reviewed DDL:
// - PRAGMA statements stay outside the migration transaction and are owned by
//   the connection-settings verifier (SCHEMA.sql header; DB-A/DB-B).
// - The reference BEGIN/COMMIT wrapper is not nested; the runner wraps the DDL
//   in its own single migration transaction (DATABASE_DESIGN 5.1, DB4-10).
//
// Run: dart run tool/gen_schema.dart
import 'dart:io';

void main() {
  const source = 'docs/approved-architecture/database/SCHEMA.sql';
  const target = 'lib/data/db/schema/reference_schema.dart';

  final raw = File(source).readAsStringSync();
  final body = raw
      .split('\n')
      .where((line) {
        final trimmed = line.trim();
        if (trimmed.startsWith('--')) {
          return false; // comments stay in the source
        }
        if (trimmed.startsWith('PRAGMA ')) return false;
        // Transaction-control wrapper only; trigger bodies keep their BEGIN.
        if (trimmed == 'BEGIN;' || trimmed == 'COMMIT;') return false;
        return true;
      })
      .join('\n')
      .trim();

  // The body must not carry transaction control or pragmas. Trigger bodies
  // legitimately contain `BEGIN ... END;`, so check line/statement shape:
  // a banned token must not appear as a standalone statement or a PRAGMA.
  for (final statement in body.split(';')) {
    final token = statement.trim();
    final lower = token.toLowerCase();
    if (lower == 'begin' || lower == 'commit') {
      stderr.writeln('gen_schema: standalone "$token" statement remains');
      exitCode = 1;
      return;
    }
    if (lower.startsWith('pragma ')) {
      stderr.writeln('gen_schema: PRAGMA statement remains: "$token"');
      exitCode = 1;
      return;
    }
  }

  // The SQL may not contain the raw-string delimiter.
  if (body.contains("'''")) {
    stderr.writeln('gen_schema: reference body contains triple quotes');
    exitCode = 1;
    return;
  }

  // Collect the table names the DDL creates, for the open-time verification.
  // The FTS virtual table counts as one table; its shadow tables do not.
  final tableNames = <String>[];
  for (final match in RegExp(
    r'CREATE\s+(VIRTUAL\s+)?TABLE\s+(\w+)(?:\s+USING\s+\w+)?\s*\(',
    caseSensitive: false,
  ).allMatches(body)) {
    tableNames.add(match.group(2)!);
  }
  if (tableNames.length != 90) {
    stderr.writeln(
      'gen_schema: expected 90 reference tables, found ${tableNames.length}',
    );
    exitCode = 1;
    return;
  }

  final out = <String>[
    '// GENERATED FILE — do not edit by hand. Run `dart run tool/gen_schema.dart`.',
    '//',
    '// T07 translation of `docs/approved-architecture/database/SCHEMA.sql`',
    '// (structural reference version 1.5, database schema version 5).',
    '// Verbatim DDL body: no PRAGMA statements (connection settings verify them',
    '// on every open) and no BEGIN/COMMIT wrapper (the migration runner owns',
    '// the single transaction; DATABASE_DESIGN 5.1, DB4-10).',
    '//',
    '// Plain SQLite structural evidence only. SQLCipher device verification,',
    '// FK/trigger/wal behaviour on the pinned encrypted build and production',
    '// interruption/rollback tests remain gates DB-A/DB-B (DATABASE_DESIGN 11).',
    'const String referenceSchemaSql = r\'\'\'',
    body,
    '\'\'\';',
    '',
    '/// The table names the reference DDL creates, in reference order.',
    'const List<String> kReferenceTableNames = <String>[',
    for (final name in tableNames) "  '$name',",
    '];',
    '',
  ];
  final targetFile = File(target);
  targetFile.parent.createSync(recursive: true);
  targetFile.writeAsStringSync(out.join('\n'));
  stdout.writeln('gen_schema: wrote $target (${body.length} bytes of DDL)');
}
