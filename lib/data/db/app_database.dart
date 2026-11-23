// T07 (SYSTEM_DESIGN 3): the typed access gateway over the translated
// reference schema.
//
// No table is declared to drift's generator in T07. Repositories inside
// `lib/data/db/` use owner-validated statements; drift rows never leave this
// folder (SYSTEM_DESIGN 3: no Drift rows or handles exposed to features).
// Table classes land with the repositories that own typed reads.
library;

import 'package:drift/drift.dart';

import 'migration.dart';

/// The drift database class over the vault connection. The authority for the
/// schema version is the `db_state` singleton, checked by the migration; this
/// getter only mirrors it for drift's internal open machinery.
final class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  @override
  // No declared drift tables: repositories use owner-validated statements.
  Iterable<TableInfo> get allTables => const Iterable.empty();

  @override
  int get schemaVersion => kCurrentSchemaVersion;
}
