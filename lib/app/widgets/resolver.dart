import 'layout_model.dart';
import 'registry.dart';

/// SPEC W6: a released-feature check. A gated widget stays stored but is not
/// shown until the gate is on.
typedef FeatureReleased = bool Function(String gate);

/// SPEC 4.3, W3: the resolved state of one placement.
final class ResolvedPlacement {
  const ResolvedPlacement({
    required this.itemKey,
    required this.canonicalKey,
    required this.size,
    required this.descriptor,
    required this.unavailable,
  });

  final String itemKey;

  /// The stored key after renames.
  final String canonicalKey;
  final WidgetSize size;

  /// Null when the key is unknown to this release (W3.10).
  final WidgetDescriptor? descriptor;

  /// True when there is nothing to render: an unknown key, or a gate that is
  /// off. In edit mode the host shows a placeholder for it.
  final bool unavailable;
}

/// SPEC W3, W7: one resolved section. A section with no visible placement is
/// dropped in normal mode and kept in edit mode.
final class ResolvedSection {
  const ResolvedSection({
    required this.key,
    required this.titleKey,
    required this.placements,
  });

  final String key;
  final String? titleKey;
  final List<ResolvedPlacement> placements;

  bool get isUntitled => titleKey == null || titleKey == 'untitled';
}

/// SPEC W3, W7: the resolved surface.
final class ResolvedSurface {
  const ResolvedSurface({
    required this.surfaceKey,
    required this.sections,
    required this.isExplicitEmpty,
  });

  final String surfaceKey;
  final List<ResolvedSection> sections;

  /// True when the saved layout is an explicit-empty surface (DB4-4): the host
  /// shows the empty state and never the default.
  final bool isExplicitEmpty;

  bool get isEmpty => sections.every((s) => s.placements.isEmpty);
}

/// SPEC W6, W7, W3: turns a stored or default layout into a resolved surface.
final class LayoutResolver {
  const LayoutResolver({required this.registry, required this.bundle});

  final WidgetRegistry registry;
  final LayoutBundle bundle;

  /// Resolves [saved] (or the default when null) for [surfaceKey].
  ///
  /// * [editing] keeps empty sections and shows unknown or gated keys as
  ///   placeholders, so the user keeps their arrangement (W3.12).
  /// * [isReleased] is the gate check for a gated descriptor (W6).
  ResolvedSurface resolve({
    required String surfaceKey,
    SurfaceLayout? saved,
    required bool editing,
    FeatureReleased? isReleased,
  }) {
    final committed = saved ?? bundle.defaultFor(surfaceKey);
    if (committed == null) {
      throw LayoutFormatError('No layout for "$surfaceKey"');
    }
    if (committed.isExplicitEmpty && saved != null) {
      return ResolvedSurface(
        surfaceKey: surfaceKey,
        sections: const <ResolvedSection>[],
        isExplicitEmpty: true,
      );
    }
    final sections = <ResolvedSection>[];
    for (final section in committed.sections) {
      final placements = <ResolvedPlacement>[];
      for (final placement in section.placements) {
        final resolved = _resolvePlacement(
          placement,
          editing: editing,
          isReleased: isReleased,
        );
        if (resolved == null) {
          continue;
        }
        placements.add(resolved);
      }
      if (placements.isEmpty && !editing) {
        continue;
      }
      sections.add(
        ResolvedSection(
          key: section.key,
          titleKey: section.titleKey,
          placements: placements,
        ),
      );
    }
    return ResolvedSurface(
      surfaceKey: surfaceKey,
      sections: sections,
      isExplicitEmpty: false,
    );
  }

  ResolvedPlacement? _resolvePlacement(
    LayoutPlacement placement, {
    required bool editing,
    required FeatureReleased? isReleased,
  }) {
    final canonical = bundle.canonicalKey(placement.itemKey);
    final descriptor = registry.byKey(canonical);
    final size = _effectiveSize(placement.size, descriptor);

    if (descriptor == null) {
      if (!editing) {
        return null; // W3.10: unknown stored key is skipped.
      }
      return ResolvedPlacement(
        itemKey: placement.itemKey,
        canonicalKey: canonical,
        size: size,
        descriptor: null,
        unavailable: true,
      );
    }

    final gate = descriptor.featureGate;
    final released = gate == null || (isReleased?.call(gate) ?? false);
    if (!released) {
      if (!editing) {
        return null; // W3.12/W6: unreleased stays out of view.
      }
      return ResolvedPlacement(
        itemKey: placement.itemKey,
        canonicalKey: canonical,
        size: size,
        descriptor: descriptor,
        unavailable: true,
      );
    }

    return ResolvedPlacement(
      itemKey: placement.itemKey,
      canonicalKey: canonical,
      size: size,
      descriptor: descriptor,
      unavailable: false,
    );
  }

  /// W3.11: a released widget keeps the user's arrangement. When the stored
  /// size is no longer allowed, the descriptor's other allowed size applies.
  WidgetSize _effectiveSize(WidgetSize stored, WidgetDescriptor? descriptor) {
    if (descriptor == null || descriptor.allowedSizes.contains(stored)) {
      return stored;
    }
    if (descriptor.allowedSizes.contains(WidgetSize.full)) {
      return WidgetSize.full;
    }
    return descriptor.allowedSizes.first;
  }
}
