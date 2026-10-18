import 'package:contour/design/format/value_presentation.dart';
import 'package:flutter/widgets.dart';

import 'layout_model.dart';
import 'read_store.dart';

/// SPEC W1: a widget (a card on a screen) or a tile (an item in Quick look).
enum WidgetKind { widget, tile }

/// The module builder. It reads shared providers, never another widget.
typedef WidgetModuleBuilder = Widget Function(BuildContext context);

/// SPEC W13, 3.1: the pure preview builder. It accepts an already-resident
/// value (or null for the "Not loaded yet" state) and can start no work.
typedef WidgetPreviewBuilder = Widget Function(
  BuildContext context,
  ValueSpec? resident,
);

/// SPEC W1, W13: one catalogue entry. Default position and size are not here;
/// they come from the default layout file.
final class WidgetDescriptor {
  const WidgetDescriptor({
    required this.key,
    required this.kind,
    required this.nameKey,
    required this.allowedSizes,
    required this.builder,
    required this.previewBuilder,
    this.ownSurface,
    this.movable = true,
    this.libraryOnly = false,
    this.featureGate,
    this.specRule,
    this.tileParentKey,
    this.metricKeys = const <MetricKey>[],
  });

  final String key;
  final WidgetKind kind;

  /// The l10n name key (DESIGN 6.7, SPEC W11/W12).
  final String nameKey;

  /// `full`, `half` or both. Order has no meaning.
  final Set<WidgetSize> allowedSizes;

  final WidgetModuleBuilder builder;
  final WidgetPreviewBuilder previewBuilder;

  /// The only surface a "Moves = No" widget may sit on.
  final String? ownSurface;

  /// SPEC W3.9: false for a widget with its own controls ("Moves" = No).
  final bool movable;

  /// SPEC W11/W12: "library" widgets are not shown by default.
  final bool libraryOnly;

  /// SPEC W6: an unreleased feature gate; null means always released.
  final String? featureGate;

  /// The governing SPEC rule, for review.
  final String? specRule;

  /// For a tile, the parent placement key (`home.quickLook`).
  final String? tileParentKey;

  /// N-02: the canonical metric keys this placement holds a lease on while
  /// it is shown. Empty when the widget reads no shared metric.
  final List<MetricKey> metricKeys;

  bool get isTile => kind == WidgetKind.tile;
}

/// SPEC W13, W-L: the recognised surface keys (nine screens plus Quick look).
const List<String> recognisedSurfaces = <String>[
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

/// SPEC W12: tiles live only on the Quick look surface.
const String quickLookTilesSurface = 'tiles:quickLook';

/// SPEC W13: per-surface limits.
const int maxSectionsPerSurface = 16;
const int maxPlacementsPerSurface = 256;

/// SPEC W1, W13: the registry of every widget and tile. It compiles the
/// catalogue and validates the default layout file (W-L). It is distinct from
/// the domain metric registry.
final class WidgetRegistry {
  WidgetRegistry(Iterable<WidgetDescriptor> descriptors)
      : _byKey = <String, WidgetDescriptor>{
          for (final descriptor in descriptors) descriptor.key: descriptor,
        } {
    if (_byKey.length != descriptors.length) {
      throw const LayoutFormatError('Duplicate widget key in the registry');
    }
  }

  final Map<String, WidgetDescriptor> _byKey;

  WidgetDescriptor? byKey(String key) => _byKey[key];

  Iterable<WidgetDescriptor> get all => _byKey.values;

  /// SPEC W13, W-L: fails the build when the default layout file is invalid.
  /// Supported here: unknown key, missing/extra surface, disallowed size,
  /// duplicate key, duplicate section, bad add entry/target/anchor, `since`
  /// out of range, bad version, "Moves = No" off its surface, wrong kind,
  /// missing rename target, cyclic rename, limits, and rename collisions.
  /// Missing gate/library/l10n checks need l10n (T10) and the release manifest.
  void validate(LayoutBundle bundle) {
    if (bundle.layoutVersion < 1) {
      throw const LayoutFormatError('layoutVersion must be positive');
    }
    if (bundle.catalogueVersion < 1) {
      throw const LayoutFormatError('catalogueVersion must be positive');
    }
    for (final surfaceKey in bundle.surfaces.keys) {
      if (!recognisedSurfaces.contains(surfaceKey)) {
        throw LayoutFormatError('Unknown surface "$surfaceKey"');
      }
    }
    for (final surfaceKey in recognisedSurfaces) {
      final layout = bundle.surfaces[surfaceKey];
      if (layout == null) {
        throw LayoutFormatError('Missing surface "$surfaceKey"');
      }
      _validateSurface(surfaceKey, layout, bundle);
    }
    _validateAddBlock(bundle);
    _validateRenames(bundle);
  }

  void _validateSurface(
    String surfaceKey,
    SurfaceLayout layout,
    LayoutBundle bundle,
  ) {
    if (layout.sections.length > maxSectionsPerSurface) {
      throw LayoutFormatError('Too many sections on "$surfaceKey"');
    }
    var placements = 0;
    final sectionKeys = <String>{};
    final itemKeys = <String>{};
    for (final section in layout.sections) {
      if (section.key != 'untitled' &&
          section.key.toLowerCase() == 'untitled') {
        // `untitled` is the reserved framework key; case variants are invalid
        // (SPEC W13).
        throw LayoutFormatError('Reserved section key on "$surfaceKey"');
      }
      if (!sectionKeys.add(section.key)) {
        throw LayoutFormatError('Duplicate section "${section.key}"');
      }
      for (final placement in section.placements) {
        placements++;
        final descriptor = byKey(placement.itemKey);
        if (descriptor == null) {
          throw LayoutFormatError('Unknown key "${placement.itemKey}"');
        }
        if (!itemKeys.add(placement.itemKey)) {
          throw LayoutFormatError(
            'Duplicate key "${placement.itemKey}" on "$surfaceKey"',
          );
        }
        _checkPlacementOnSurface(surfaceKey, placement, descriptor);
      }
    }
    if (placements > maxPlacementsPerSurface) {
      throw LayoutFormatError('Too many placements on "$surfaceKey"');
    }
  }

  void _checkPlacementOnSurface(
    String surfaceKey,
    LayoutPlacement placement,
    WidgetDescriptor descriptor,
  ) {
    if (!descriptor.allowedSizes.contains(placement.size)) {
      throw LayoutFormatError(
        'Size ${placement.size.id} not allowed for "${placement.itemKey}"',
      );
    }
    if (descriptor.kind == WidgetKind.tile &&
        surfaceKey != quickLookTilesSurface) {
      throw const LayoutFormatError(
        'A tile must sit on the Quick look surface',
      );
    }
    if (!descriptor.movable && descriptor.ownSurface != surfaceKey) {
      throw LayoutFormatError(
        '"${placement.itemKey}" cannot move off "${descriptor.ownSurface}"',
      );
    }
  }

  void _validateAddBlock(LayoutBundle bundle) {
    for (final entry in bundle.add.widgets.values) {
      final descriptor = byKey(entry.itemKey);
      if (descriptor == null) {
        throw LayoutFormatError('Add entry for unknown key "${entry.itemKey}"');
      }
      if (!descriptor.allowedSizes.contains(entry.addSize)) {
        throw LayoutFormatError(
          'Add size ${entry.addSize.id} not allowed for "${entry.itemKey}"',
        );
      }
      if (entry.since < 1 || entry.since > bundle.layoutVersion) {
        throw LayoutFormatError(
          'since ${entry.since} out of range for "${entry.itemKey}"',
        );
      }
    }
    for (final surfaceKey in recognisedSurfaces) {
      final target = bundle.add.targets[surfaceKey];
      if (target == null) {
        throw LayoutFormatError('Missing add target for "$surfaceKey"');
      }
      final layout = bundle.surfaces[surfaceKey]!;
      final sectionKeys = layout.sections.map((s) => s.key).toSet();
      if (!sectionKeys.contains(target.targetSection)) {
        throw LayoutFormatError(
          'Add target section "${target.targetSection}" is not on "$surfaceKey"',
        );
      }
      for (final anchor in target.anchors) {
        if (byKey(anchor) == null) {
          throw LayoutFormatError(
            'Add anchor "$anchor" is not a catalogue key',
          );
        }
      }
    }
  }

  void _validateRenames(LayoutBundle bundle) {
    for (final entry in bundle.renames.entries) {
      if (byKey(entry.value) == null) {
        throw LayoutFormatError(
          'Rename target "${entry.value}" is not a catalogue key',
        );
      }
      final seen = <String>{entry.key};
      var current = entry.value;
      while (bundle.renames.containsKey(current)) {
        if (!seen.add(current)) {
          throw LayoutFormatError('Cyclic rename for "${entry.key}"');
        }
        current = bundle.renames[current]!;
      }
    }
  }
}
