import 'dart:async';

import 'editor.dart';
import 'layout_model.dart';

/// SPEC W7, W13: a stored layout for one surface with its base layout version.
final class StoredLayout {
  const StoredLayout({
    required this.surfaceKey,
    required this.sections,
    required this.baseLayoutVersion,
    this.newInThisVersion = const <String>{},
  });

  final String surfaceKey;
  final List<LayoutSection> sections;
  final int baseLayoutVersion;

  /// N-03: the session-added keys are stored deliberately, so the Add sheet
  /// can use them. T07 must persist this set with the row.
  final Set<String> newInThisVersion;

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

/// N-03: maps a Done result to the store. `InheritDefault` clears the stored
/// row so a later release default still reaches the user (W-J). `SaveLayout`
/// writes the commit once, even when only the version stamp changed.
Future<void> applyDone(LayoutRepository repo, LayoutDoneResult result) async {
  switch (result) {
    case InheritDefault(:final surfaceKey):
      await repo.clear(surfaceKey);
    case SaveLayout(:final commit):
      await repo.save(commit);
  }
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
      newInThisVersion: commit.newInThisVersion,
    );
    _changes.add(commit.surfaceKey);
  }

  @override
  Future<void> clear(String surfaceKey) async {
    // Clearing an absent row writes nothing and notifies no one.
    if (_rows.remove(surfaceKey) != null) {
      _changes.add(surfaceKey);
    }
  }

  @override
  Stream<String> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();
}
