import 'package:contour/design/design.dart';
import 'package:flutter/widgets.dart';

import 'layout_model.dart';
import 'resolver.dart';

/// SPEC W13, W-D: resolves a section title key to a user word. The registry
/// stores keys; l10n (T10) supplies the word.
typedef SectionTitleResolver = String Function(String titleKey);

/// SPEC W4: builds the per-placement tool row in edit mode.
typedef PlacementToolRowBuilder = Widget Function(
  BuildContext context,
  ResolvedPlacement placement,
);

/// SPEC W13, W-D: the two-level host. It draws sections in order and pairs
/// consecutive half-size placements into rows. It is the same host for every
/// screen; only the surface, the fixed hero and the template differ (W13).
///
/// The host reads a already-resolved surface. It starts no work and reads no
/// database (widget-framework 3.1).
class WidgetSurfaceHost extends StatelessWidget {
  const WidgetSurfaceHost({
    required this.surface,
    required this.titleFor,
    this.unavailableLabel = 'Unavailable',
    this.editing = false,
    this.toolRowBuilder,
    this.emptyState,
    super.key,
  });

  final ResolvedSurface surface;
  final SectionTitleResolver titleFor;

  /// The word for a key this release does not know or does not show. It comes
  /// from l10n in T10.
  final String unavailableLabel;

  final bool editing;
  final PlacementToolRowBuilder? toolRowBuilder;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    if (surface.isExplicitEmpty || surface.isEmpty) {
      return emptyState ?? const SizedBox.shrink();
    }
    final sections = <Widget>[];
    for (var i = 0; i < surface.sections.length; i++) {
      if (i > 0) {
        sections.add(const VSpace(Space.l));
      }
      final section = surface.sections[i];
      sections.add(
        WidgetSection(
          title: section.isUntitled ? null : titleFor(section.titleKey!),
          children: _rows(context, section),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections,
    );
  }

  List<Widget> _rows(BuildContext context, ResolvedSection section) {
    final rows = <Widget>[];
    final pending = <Widget>[];

    void flushPending() {
      if (pending.isEmpty) {
        return;
      }
      rows.add(_halfRow(pending));
      pending.clear();
    }

    for (final placement in section.placements) {
      final cell = _cell(context, placement);
      if (placement.size == WidgetSize.half) {
        pending.add(cell);
        if (pending.length == 2) {
          flushPending();
        }
      } else {
        flushPending();
        rows.add(cell);
      }
    }
    flushPending();
    return rows;
  }

  Widget _halfRow(List<Widget> cells) {
    if (cells.length == 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: cells.first),
          const HSpace(Space.card),
          const Expanded(child: SizedBox.shrink()),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: cells[0]),
        const HSpace(Space.card),
        Expanded(child: cells[1]),
      ],
    );
  }

  Widget _cell(BuildContext context, ResolvedPlacement placement) {
    final descriptor = placement.descriptor;
    final Widget content;
    if (descriptor == null || placement.unavailable) {
      content = _unavailable(context);
    } else {
      content = descriptor.builder(context);
    }
    if (!editing) {
      return content;
    }
    return WidgetSlot(
      variant: WidgetSlotVariant.editing,
      toolRow: toolRowBuilder?.call(context, placement),
      child: content,
    );
  }

  Widget _unavailable(BuildContext context) {
    return GlassCard(
      child: Text(
        unavailableLabel,
        style: AppText.body.copyWith(color: context.tokens.textPrimary),
      ),
    );
  }
}
