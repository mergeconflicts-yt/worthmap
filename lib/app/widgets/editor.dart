import 'layout_model.dart';
import 'registry.dart';

/// SPEC W4, W7: the result of Done in edit mode. It carries keys and sizes
/// only, the base layout version, and the keys that are new in this version.
final class LayoutCommit {
  const LayoutCommit({
    required this.surfaceKey,
    required this.sections,
    required this.baseLayoutVersion,
    required this.newInThisVersion,
  });

  final String surfaceKey;
  final List<LayoutSection> sections;
  final int baseLayoutVersion;
  final Set<String> newInThisVersion;

  bool get isEmpty => sections.isEmpty;
}

final class _Snapshot {
  _Snapshot(this.sections);

  final List<LayoutSection> sections;
}

/// SPEC W4, W7: one edit session for one surface. Changes stay in a private
/// candidate. Cancel discards it; Done returns a [LayoutCommit]. Undo returns
/// the candidate to the state before the last change.
final class LayoutEditor {
  LayoutEditor({
    required this.registry,
    required this.bundle,
    required this.surfaceKey,
    SurfaceLayout? saved,
  }) {
    _defaultSections =
        _copy(bundle.defaultFor(surfaceKey)?.sections ?? const []);
    _candidate = _copy(saved?.sections ?? _defaultSections);
  }

  final WidgetRegistry registry;
  final LayoutBundle bundle;
  final String surfaceKey;

  late List<LayoutSection> _candidate;
  late List<LayoutSection> _defaultSections;
  final List<_Snapshot> _undoStack = <_Snapshot>[];
  final Set<String> _newKeys = <String>{};

  List<LayoutSection> get sections => _copy(_candidate);

  bool get canUndo => _undoStack.isNotEmpty;

  bool get isDefaultScope =>
      _eqSections(_candidate, _defaultSections) && _newKeys.isEmpty;

  /// True when the candidate differs from the layout the session opened with.
  bool get hasChanges => _undoStack.isNotEmpty;

  bool _isKnown(String itemKey) => registry.byKey(itemKey) != null;

  void _push() {
    _undoStack.add(_Snapshot(_copy(_candidate)));
  }

  void _mutate(void Function() change) {
    _push();
    change();
  }

  /// SPEC W3: hide always removes the placement from the shown order.
  void hide(String itemKey) {
    _mutate(() {
      for (final section in _candidate) {
        section.placements.removeWhere((p) => p.itemKey == itemKey);
      }
    });
  }

  void moveUp(String itemKey) => _swap(itemKey, -1);

  void moveDown(String itemKey) => _swap(itemKey, 1);

  void _swap(String itemKey, int delta) {
    for (final section in _candidate) {
      final index = section.placements.indexWhere((p) => p.itemKey == itemKey);
      if (index < 0) {
        continue;
      }
      final target = index + delta;
      if (target < 0 || target >= section.placements.length) {
        return;
      }
      _mutate(() {
        final list = section.placements;
        final tmp = list[index];
        list[index] = list[target];
        list[target] = tmp;
      });
      return;
    }
  }

  void moveSectionUp(String sectionKey) => _swapSection(sectionKey, -1);

  void moveSectionDown(String sectionKey) => _swapSection(sectionKey, 1);

  void _swapSection(String sectionKey, int delta) {
    final index = _candidate.indexWhere((s) => s.key == sectionKey);
    if (index < 0) {
      return;
    }
    final target = index + delta;
    if (target < 0 || target >= _candidate.length) {
      return;
    }
    _mutate(() {
      final tmp = _candidate[index];
      _candidate[index] = _candidate[target];
      _candidate[target] = tmp;
    });
  }

  /// SPEC W2, W4: add a widget or tile with its file size. The host inserts it
  /// into the add target and marks it new in this version.
  void add(String itemKey) {
    if (!_isKnown(itemKey)) {
      throw LayoutFormatError('Cannot add unknown key "$itemKey"');
    }
    if (contains(itemKey)) {
      return;
    }
    final entry = bundle.add.widgets[itemKey];
    if (entry == null) {
      throw LayoutFormatError('"$itemKey" is not addable');
    }
    final target = bundle.add.targetFor(surfaceKey, itemKey);
    if (target == null) {
      throw LayoutFormatError('No add target for "$surfaceKey"');
    }
    _mutate(() {
      final section = _sectionFor(target.targetSection);
      final placement = LayoutPlacement(itemKey: itemKey, size: entry.addSize);
      final anchorIndex = target.anchors
          .map((a) => section.placements.indexWhere((p) => p.itemKey == a))
          .where((i) => i >= 0)
          .fold<int>(-1, (best, i) => i > best ? i : best);
      if (anchorIndex >= 0) {
        section.placements.insert(anchorIndex + 1, placement);
      } else {
        section.placements.add(placement);
      }
      _newKeys.add(itemKey);
    });
  }

  bool contains(String itemKey) =>
      _candidate.any((s) => s.placements.any((p) => p.itemKey == itemKey));

  LayoutSection _sectionFor(String sectionKey) {
    for (final section in _candidate) {
      if (section.key == sectionKey) {
        return section;
      }
    }
    final created =
        LayoutSection(key: sectionKey, placements: <LayoutPlacement>[]);
    _candidate.add(created);
    return created;
  }

  /// SPEC W7, W4: remove a placement for a cross-surface move.
  LayoutPlacement? take(String itemKey) {
    final descriptor = registry.byKey(itemKey);
    if (descriptor != null && !descriptor.movable) {
      throw LayoutFormatError('"$itemKey" cannot move (SPEC W3.9)');
    }
    for (final section in _candidate) {
      final index = section.placements.indexWhere((p) => p.itemKey == itemKey);
      if (index >= 0) {
        late LayoutPlacement removed;
        _mutate(() {
          removed = section.placements.removeAt(index);
        });
        return removed;
      }
    }
    return null;
  }

  /// SPEC W7: insert a placement taken from another surface.
  void insert(String sectionKey, LayoutPlacement placement) {
    _mutate(() {
      _sectionFor(sectionKey).placements.add(placement);
      _newKeys.add(placement.itemKey);
    });
  }

  /// SPEC W4, W13: reset this surface to the default layout.
  void resetToDefault() {
    _mutate(() {
      _candidate = _copy(_defaultSections);
      _newKeys.clear();
    });
  }

  /// SPEC W4: undo the last change in this session.
  void undo() {
    final snapshot = _undoStack.isEmpty ? null : _undoStack.removeLast();
    if (snapshot == null) {
      return;
    }
    _candidate = _copy(snapshot.sections);
    _newKeys.removeWhere((key) => !contains(key));
  }

  /// SPEC W4: finish the session and return the commit. The host writes it and
  /// stamps the base layout version.
  LayoutCommit done() {
    final defaultKeys = <String>{
      for (final section in _defaultSections)
        for (final p in section.placements) p.itemKey,
    };
    final newInThisVersion = <String>{
      for (final section in _candidate)
        for (final p in section.placements)
          if (!defaultKeys.contains(p.itemKey)) p.itemKey,
      ..._newKeys,
    };
    return LayoutCommit(
      surfaceKey: surfaceKey,
      sections: _copy(_candidate),
      baseLayoutVersion: bundle.layoutVersion,
      newInThisVersion: newInThisVersion,
    );
  }
}

List<LayoutSection> _copy(List<LayoutSection> sections) => <LayoutSection>[
      for (final section in sections)
        LayoutSection(
          key: section.key,
          titleKey: section.titleKey,
          placements: List<LayoutPlacement>.of(section.placements),
        ),
    ];

bool _eqSections(List<LayoutSection> a, List<LayoutSection> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
