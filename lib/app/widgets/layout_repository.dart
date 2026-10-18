import 'dart:async';

import 'editor.dart';
import 'layout_model.dart';

/// SPEC W7, W13: a stored layout for one surface with its base layout version.
final class StoredLayout {
  const StoredLayout({
    required this.surfaceKey,
    required this.sections,
    required this.baseLayoutVersion,
  });

  final String surfaceKey;
  final List<LayoutSection> sections;
  final int baseLayoutVersion;

  SurfaceLayout toSurfaceLayout() =>
      SurfaceLayout(surfaceKey: surfaceKey, sections: sections);
}

/// SPEC W7, DATABASE_DESIGN 5.1: the layout store boundary. The Drift
/// implementation lands in T07; this interface lets the framework run now.
abstract interface class LayoutRepository {
  Future<StoredLayout?> load(String surfaceKey);

  /// Writes a commit and, atomically, its ChangeLog rows and dependency
  /// revisions (SYSTEM_DESIGN 5.2). T07 wires the transaction.
  Future<void> save(LayoutCommit commit);

  /// Removes a surface's saved rows (a return to the default).
  Future<void> clear(String surfaceKey);

  /// Fires when any surface changes, so open surfaces rebuild.
  Stream<String> get changes;
}

/// A Phase 1 in-memory repository. Keys and sizes only; no personal data.
final class InMemoryLayoutRepository implements LayoutRepository {
  InMemoryLayoutRepository();

  final Map<String, StoredLayout> _rows = <String, StoredLayout>{};
  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  @override
  Future<StoredLayout?> load(String surfaceKey) async => _rows[surfaceKey];

  @override
  Future<void> save(LayoutCommit commit) async {
    _rows[commit.surfaceKey] = StoredLayout(
      surfaceKey: commit.surfaceKey,
      sections: commit.sections,
      baseLayoutVersion: commit.baseLayoutVersion,
    );
    _changes.add(commit.surfaceKey);
  }

  @override
  Future<void> clear(String surfaceKey) async {
    _rows.remove(surfaceKey);
    _changes.add(surfaceKey);
  }

  @override
  Stream<String> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();
}
