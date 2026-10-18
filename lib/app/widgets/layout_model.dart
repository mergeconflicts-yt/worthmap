/// SPEC W13, DATABASE_DESIGN 5.1: the layout data model.
///
/// A surface is a list of ordered sections. A section has a key, an optional
/// l10n title key and ordered placements. A placement is an item key and a
/// size. The model holds keys only: no amounts, text or personal data.
library;

/// SPEC W1, W13: how wide a widget is.
enum WidgetSize {
  full,
  half;

  /// Parses the stored id (`full` or `half`).
  static WidgetSize fromId(String id) {
    return switch (id) {
      'full' => WidgetSize.full,
      'half' => WidgetSize.half,
      _ => throw LayoutFormatError('Unknown size "$id"'),
    };
  }

  String get id => name;
}

/// SPEC W1, W13: one widget key and its size on a surface.
final class LayoutPlacement {
  const LayoutPlacement({required this.itemKey, required this.size});

  final String itemKey;
  final WidgetSize size;

  LayoutPlacement withSize(WidgetSize value) =>
      LayoutPlacement(itemKey: itemKey, size: value);

  @override
  bool operator ==(Object other) =>
      other is LayoutPlacement &&
      other.itemKey == itemKey &&
      other.size == size;

  @override
  int get hashCode => Object.hash(itemKey, size);

  @override
  String toString() => 'LayoutPlacement($itemKey, ${size.id})';
}

/// SPEC W13: a titled group of widgets. The key is a default-file identifier,
/// never user text or a title. `untitled` is reserved.
final class LayoutSection {
  const LayoutSection({
    required this.key,
    required this.placements,
    this.titleKey,
  });

  final String key;
  final String? titleKey;
  final List<LayoutPlacement> placements;

  LayoutSection copyWith({List<LayoutPlacement>? placements}) => LayoutSection(
        key: key,
        titleKey: titleKey,
        placements: placements ?? this.placements,
      );

  @override
  bool operator ==(Object other) =>
      other is LayoutSection &&
      other.key == key &&
      other.titleKey == titleKey &&
      _listEq(other.placements, placements);

  @override
  int get hashCode => Object.hash(key, titleKey, Object.hashAll(placements));

  @override
  String toString() => 'LayoutSection($key, $placements)';
}

/// SPEC W13: the stored or default layout of one surface. An explicit-empty
/// surface has a row with no section (DATABASE_DESIGN 5.1, DB4-4).
final class SurfaceLayout {
  const SurfaceLayout({required this.surfaceKey, required this.sections});

  final String surfaceKey;
  final List<LayoutSection> sections;

  bool get isExplicitEmpty => sections.isEmpty;

  SurfaceLayout copyWith({List<LayoutSection>? sections}) => SurfaceLayout(
        surfaceKey: surfaceKey,
        sections: sections ?? this.sections,
      );

  @override
  bool operator ==(Object other) =>
      other is SurfaceLayout &&
      other.surfaceKey == surfaceKey &&
      _listEq(other.sections, sections);

  @override
  int get hashCode => Object.hash(surfaceKey, Object.hashAll(sections));
}

/// SPEC W13: one add-block widget entry.
final class AddWidgetEntry {
  const AddWidgetEntry({
    required this.itemKey,
    required this.addSize,
    required this.since,
  });

  final String itemKey;
  final WidgetSize addSize;

  /// The `layout_version` that introduced the key (1..layoutVersion).
  final int since;
}

/// SPEC W13, SY4-6: where an added widget goes on a surface.
final class AddTarget {
  const AddTarget({
    required this.targetSection,
    this.anchors = const <String>[],
  });

  final String targetSection;

  /// Insert after the first anchor that is present.
  final List<String> anchors;
}

/// SPEC W13, SY4-6: the closed add block of a layout file.
final class AddBlock {
  const AddBlock({
    required this.widgets,
    required this.targets,
    this.perKeyTargets = const <String, Map<String, AddTarget>>{},
  });

  final Map<String, AddWidgetEntry> widgets;
  final Map<String, AddTarget> targets;

  /// Optional per-key target override by surface.
  final Map<String, Map<String, AddTarget>> perKeyTargets;

  AddTarget? targetFor(String surfaceKey, String itemKey) =>
      perKeyTargets[itemKey]?[surfaceKey] ?? targets[surfaceKey];
}

/// SPEC W13: the compiled default layout bundle.
final class LayoutBundle {
  const LayoutBundle({
    required this.layoutVersion,
    required this.catalogueVersion,
    required this.surfaces,
    required this.add,
    this.renames = const <String, String>{},
  });

  final int layoutVersion;
  final int catalogueVersion;

  /// One default layout per recognised surface key.
  final Map<String, SurfaceLayout> surfaces;
  final AddBlock add;

  /// Historical key -> current key aliases (cumulative, flattened).
  final Map<String, String> renames;

  SurfaceLayout? defaultFor(String surfaceKey) => surfaces[surfaceKey];

  /// Resolves a stored key to its current key through the rename map.
  String canonicalKey(String key) {
    var current = key;
    final seen = <String>{};
    while (renames.containsKey(current) && seen.add(current)) {
      current = renames[current]!;
    }
    return current;
  }
}

/// Raised when layout data fails a format or validation rule.
final class LayoutFormatError implements Exception {
  const LayoutFormatError(this.message);

  final String message;

  @override
  String toString() => 'LayoutFormatError($message)';
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
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
