// T07 (DATABASE_DESIGN 2, SYSTEM_DESIGN 5.1): connection settings.
//
// Every connection, on every open — not only schema creation:
//   foreign_keys = ON, recursive_triggers = ON, WAL (file targets),
//   synchronous = FULL, temp_store = MEMORY, bounded busy timeout.
// A mismatch fails closed with a typed code (AGENTS 2.6: no personal data).
library;

import 'package:sqlite3/sqlite3.dart';

/// Bounded busy timeout (SYSTEM_DESIGN 5.1).
const int kVaultBusyTimeoutMs = 5000;

class VaultSettingsError implements Exception {
  const VaultSettingsError(this.setting, this.value);

  final String setting;
  final Object? value;

  @override
  String toString() => 'VaultSettingsError($setting=${value ?? 'null'})';
}

/// Applies and verifies the required connection settings.
final class ConnectionSettings {
  const ConnectionSettings._();

  /// Applies the settings to a raw connection. [expectWal] is false only for
  /// in-memory test targets, where SQLite always reports `memory`.
  static void apply(Database raw, {required bool expectWal}) {
    raw.execute('PRAGMA foreign_keys = ON');
    raw.execute('PRAGMA recursive_triggers = ON');
    raw.execute('PRAGMA temp_store = MEMORY');
    if (expectWal) {
      raw.execute('PRAGMA journal_mode = WAL');
    }
    raw.execute('PRAGMA synchronous = FULL');
    raw.execute('PRAGMA busy_timeout = $kVaultBusyTimeoutMs');
  }

  /// Reads every setting back and fails closed on a mismatch.
  static void verify(Database raw, {required bool expectWal}) {
    Never fail(String setting, Object? value) {
      throw VaultSettingsError(setting, value);
    }

    int readInt(String pragma) {
      final rows = raw.select('PRAGMA $pragma');
      if (rows.isEmpty) {
        fail(pragma, null);
      }
      final value = rows.first.values.first;
      if (value is! int) {
        fail(pragma, value);
      }
      return value;
    }

    if (readInt('foreign_keys') != 1) {
      fail('foreign_keys', readInt('foreign_keys'));
    }
    if (readInt('recursive_triggers') != 1) {
      fail('recursive_triggers', readInt('recursive_triggers'));
    }
    if (readInt('temp_store') != 2) {
      // 2 is the MEMORY store.
      fail('temp_store', readInt('temp_store'));
    }
    if (readInt('synchronous') != 2) {
      // 2 is FULL.
      fail('synchronous', readInt('synchronous'));
    }
    if (readInt('busy_timeout') != kVaultBusyTimeoutMs) {
      fail('busy_timeout', readInt('busy_timeout'));
    }
    final mode = raw.select('PRAGMA journal_mode').first.values.first;
    final text = mode?.toString() ?? '';
    if (expectWal && text != 'wal') {
      fail('journal_mode', text);
    }
    if (!expectWal && text != 'memory') {
      fail('journal_mode', text);
    }
  }

  /// Runs `PRAGMA foreign_key_check`; an empty result passes. Used by the
  /// integrity command, not on every open (the pragma read proves the
  /// enforcement flag; the check proves the data).
  static List<Map<String, Object?>> foreignKeyViolations(Database raw) {
    return raw
        .select('PRAGMA foreign_key_check')
        .map((row) => {'table': row.values[0], 'rowid': row.values[1]})
        .toList();
  }
}
