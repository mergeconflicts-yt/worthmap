// T07: the vault boundary. Features import nothing from here directly;
// app-level composition (T09) opens the vault and hands repositories to
// controllers. SYSTEM_DESIGN 3: no Drift rows, handles or generic SQL leave
// this folder.
library;

export 'app_database.dart';
export 'cipher.dart';
export 'command_repository.dart';
export 'connection_settings.dart';
export 'layout_repository.dart';
export 'migration.dart';
export 'read_revision.dart';
export 'statement_splitter.dart';
export 'vault.dart';
