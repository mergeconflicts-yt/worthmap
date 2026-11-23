// T07 (DATABASE_DESIGN 5.1, SPEC W7/W13): the layout preference store.
//
// A local display preference, not financial data: typed rows of keys, order
// and sizes, no JSON. One writer transaction replaces the complete touched
// surface patch with validated explicit DELETE then INSERT (never INSERT OR
// REPLACE; the six `layout_*_no_replace` triggers abort any replacement).
// The preference write creates no ChangeLog, receipt, dependency revision or
// recalculation; it advances the read revision once and notifies.
//
// Enforced by the writer (the tables enforce the same core rules):
//   - surface keys: the ten recognised keys only;
//   - section keys: 1-64 chars of A-Za-z0-9._-; `untitled` reserved with
//     exact case; case variants rejected (DB4-7);
//   - `tiles:quickLook`: only `untitled`, only `full` sizes;
//   - limits per surface: 16 sections, 256 items, 64 KiB canonical bytes
//     (DB4-6), each validated independently;
//   - item positions dense from zero per section (DB4-5), item keys unique
//     per surface;
//   - explicit empty: a surface row with no section (DB4-4).
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'read_revision.dart';

/// Safe store failure codes (AGENTS 2.6: no values, keys or personal data in
/// errors beyond the safe structural kind).
enum LayoutStoreErrorCode {
  unknownSurface,
  badSectionKey,
  badItemKey,
  badSize,
  duplicateItem,
  duplicateSection,
  sectionLimit,
  itemLimit,
  byteBound,
  tileSurfaceRule,
  conflict,
}

class LayoutStoreError implements Exception {
  const LayoutStoreError(this.code);

  final LayoutStoreErrorCode code;

  @override
  String toString() => 'LayoutStoreError(${code.name})';
}

/// The ten recognised surface keys (reference schema CHECK; SCREEN-SET-001).
const List<String> kLayoutSurfaceKeys = <String>[
  'screen:home',
  'screen:spending',
  'screen:moneyIn',
  'screen:wealth',
  'screen:investments',
  'screen:calendar',
  'screen:goals',
  'screen:protect',
  'screen:tax',
  'tiles:quickLook',
];

const String _untitled = 'untitled';

// DATABASE_DESIGN 5.1 limits.
const int _maxSections = 16;
const int _maxItems = 256;
const int _maxDescriptorBytes = 65536;

/// A section row as stored: raw key and dense position. Titles are l10n
/// lookups by key; rows never hold text.
final class StoredSection {
  const StoredSection({required this.key, required this.items});

  final String key;

  /// `item key, size` pairs in position order.
  final List<(String, String)> items;
}

/// The bounded raw snapshot (Q18): surface presence, versions and the
/// complete section/item list. Distinguishes absent from explicit empty.
final class StoredSurfaceLayout {
  const StoredSurfaceLayout({
    required this.surfaceKey,
    required this.catalogueVersion,
    required this.baseLayoutVersion,
    required this.sections,
  });

  final String surfaceKey;
  final int catalogueVersion;
  final int baseLayoutVersion;
  final List<StoredSection> sections;

  /// No surface row: the surface follows the installed default file.
  bool get isAbsent => false;
}

/// The Drift-backed layout preference repository.
final class DriftLayoutRepository {
  DriftLayoutRepository({required AppDatabase db, required this.clockUtc})
      : _db = db;

  final AppDatabase _db;

  /// Injected clock for `updated_at` (AGENTS 6.3).
  final DateTime Function() clockUtc;

  final StreamController<String> _changes = StreamController.broadcast();

  /// Fires with the surface key after each committed change.
  Stream<String> get changes => _changes.stream;

  int _nowMs() => clockUtc().millisecondsSinceEpoch;

  /// The bounded raw snapshot. Returns null when the surface has no row
  /// (inherit the installed default). Reads accept position gaps; the writer
  /// writes densely.
  Future<StoredSurfaceLayout?> load(String surfaceKey) async {
    final surfaceRows = await _db.customSelect(
      'SELECT catalogue_version, base_layout_version FROM layout_surfaces '
      'WHERE surface_key = ?',
      variables: [Variable(surfaceKey)],
    ).get();
    if (surfaceRows.isEmpty) {
      return null;
    }
    final surface = surfaceRows.first;
    final sectionRows = await _db.customSelect(
      'SELECT position, section_key FROM layout_sections '
      'WHERE surface_key = ? ORDER BY position',
      variables: [Variable(surfaceKey)],
    ).get();
    final itemRows = await _db.customSelect(
      'SELECT section_key, position, item_key, size FROM layout_items '
      'WHERE surface_key = ? ORDER BY section_key, position',
      variables: [Variable(surfaceKey)],
    ).get();

    final itemsBySection = <String, List<(String, String)>>{};
    for (final row in itemRows) {
      final data = row.data;
      (itemsBySection[data['section_key'] as String] ??= <(String, String)>[])
          .add((data['item_key'] as String, data['size'] as String));
    }
    final sections = sectionRows
        .map(
          (row) => StoredSection(
            key: row.data['section_key'] as String,
            items: itemsBySection[row.data['section_key'] as String] ??
                const <(String, String)>[],
          ),
        )
        .toList();
    return StoredSurfaceLayout(
      surfaceKey: surfaceKey,
      catalogueVersion: surface.data['catalogue_version'] as int,
      baseLayoutVersion: surface.data['base_layout_version'] as int,
      sections: sections,
    );
  }

  /// Writes the complete surface patch in one transaction: validated DELETE
  /// then INSERT, then one read-revision advance. An explicit-empty commit
  /// keeps the surface row with no section (DB4-4). Returns the new read
  /// revision.
  Future<int> save({
    required String surfaceKey,
    required int catalogueVersion,
    required int baseLayoutVersion,
    required List<StoredSection> sections,
  }) async {
    _validate(
      surfaceKey: surfaceKey,
      catalogueVersion: catalogueVersion,
      baseLayoutVersion: baseLayoutVersion,
      sections: sections,
    );

    final now = _nowMs();
    final committed = await _db.transaction(() async {
      // Explicit DELETE first; cascade removes the child rows. Absent row:
      // the insert below creates it.
      await _db.customStatement(
        'DELETE FROM layout_surfaces WHERE surface_key = ?',
        [surfaceKey],
      );
      await _db.customStatement(
        'INSERT INTO layout_surfaces (surface_key, catalogue_version, '
        'base_layout_version, updated_at) VALUES (?, ?, ?, ?)',
        [surfaceKey, catalogueVersion, baseLayoutVersion, now],
      );
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i];
        await _db.customStatement(
          'INSERT INTO layout_sections (surface_key, position, section_key) '
          'VALUES (?, ?, ?)',
          [surfaceKey, i, section.key],
        );
        for (var j = 0; j < section.items.length; j++) {
          final (itemKey, size) = section.items[j];
          await _db.customStatement(
            'INSERT INTO layout_items (surface_key, section_key, position, '
            'item_key, size) VALUES (?, ?, ?, ?, ?)',
            [surfaceKey, section.key, j, itemKey, size],
          );
        }
      }
      return advanceReadRevision(_db);
    });
    _changes.add(surfaceKey);
    return committed;
  }

  /// Removes the surface's stored rows (a return to the default). A clear of
  /// an absent row writes nothing and notifies no one.
  Future<void> clear(String surfaceKey) async {
    final deleted = await _db.transaction(() async {
      final count = await _db.customUpdate(
        'DELETE FROM layout_surfaces WHERE surface_key = ?',
        variables: [Variable(surfaceKey)],
      );
      if (count == 0) {
        return false;
      }
      await advanceReadRevision(_db);
      return true;
    });
    if (deleted) {
      _changes.add(surfaceKey);
    }
  }

  void _validate({
    required String surfaceKey,
    required int catalogueVersion,
    required int baseLayoutVersion,
    required List<StoredSection> sections,
  }) {
    if (!kLayoutSurfaceKeys.contains(surfaceKey)) {
      throw const LayoutStoreError(LayoutStoreErrorCode.unknownSurface);
    }
    if (catalogueVersion < 1 || baseLayoutVersion < 1) {
      throw const LayoutStoreError(LayoutStoreErrorCode.badSectionKey);
    }
    if (sections.length > _maxSections) {
      throw const LayoutStoreError(LayoutStoreErrorCode.sectionLimit);
    }
    final sectionKeys = <String>{};
    final itemKeys = <String>{};
    var itemCount = 0;
    for (final section in sections) {
      final key = section.key;
      // DB4-7: 1-64 chars of A-Za-z0-9._-; the reserved key is the exact
      // string `untitled`, and the table rule admits a key only when it is
      // that exact string or its lowercase sorts strictly before it. Case
      // variants and later-sorting keys are rejected.
      // SQLite `length()` counts characters (code points), so the writer
      // uses the same measure. Dart `String.length` counts UTF-16 units.
      int charCount(String value) => value.runes.length;

      if (charCount(key) < 1 ||
          charCount(key) > 64 ||
          !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(key) ||
          (key != _untitled && key.toLowerCase().compareTo(_untitled) >= 0)) {
        throw const LayoutStoreError(LayoutStoreErrorCode.badSectionKey);
      }
      if (surfaceKey == 'tiles:quickLook' && key != _untitled) {
        throw const LayoutStoreError(LayoutStoreErrorCode.tileSurfaceRule);
      }
      if (!sectionKeys.add(key)) {
        throw const LayoutStoreError(LayoutStoreErrorCode.duplicateSection);
      }
      for (final (itemKey, size) in section.items) {
        itemCount++;
        // Retained keys from another version may hold any 64 Unicode
        // characters (DATABASE_DESIGN 5.1); only the NUL ban and the length
        // bound apply. The byte bound below still guards the descriptor.
        if (charCount(itemKey) < 1 ||
            charCount(itemKey) > 64 ||
            itemKey.contains('\x00')) {
          throw const LayoutStoreError(LayoutStoreErrorCode.badItemKey);
        }
        if (size != 'full' && size != 'half') {
          throw const LayoutStoreError(LayoutStoreErrorCode.badSize);
        }
        if (surfaceKey == 'tiles:quickLook' && size != 'full') {
          throw const LayoutStoreError(LayoutStoreErrorCode.tileSurfaceRule);
        }
        if (!itemKeys.add(itemKey)) {
          throw const LayoutStoreError(LayoutStoreErrorCode.duplicateItem);
        }
      }
    }
    if (itemCount > _maxItems) {
      throw const LayoutStoreError(LayoutStoreErrorCode.itemLimit);
    }
    // Canonical descriptor bytes (DB4-6): sections, items, sizes and both
    // versions. Validated independently of the count limits.
    final canonical = StringBuffer()
      ..write(surfaceKey)
      ..write('|$catalogueVersion|$baseLayoutVersion');
    for (final section in sections) {
      canonical.write('|${section.key}');
      for (final (itemKey, size) in section.items) {
        canonical.write(';$itemKey;$size');
      }
    }
    if (utf8.encode(canonical.toString()).length > _maxDescriptorBytes) {
      throw const LayoutStoreError(LayoutStoreErrorCode.byteBound);
    }
  }

  /// Closes the change stream. The vault outlives this repository.
  Future<void> dispose() => _changes.close();
}
