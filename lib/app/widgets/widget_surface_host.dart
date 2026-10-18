import 'package:contour/design/design.dart';
import 'package:flutter/widgets.dart';

import 'layout_model.dart';
import 'read_store.dart';
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
    required this.unavailableLabel,
    this.store,
    this.editing = false,
    this.toolRowBuilder,
    this.emptyState,
    super.key,
  });

  final ResolvedSurface surface;
  final SectionTitleResolver titleFor;

  /// N-09: the word for a key this release does not know or does not show.
  /// Required, so it comes from l10n in T10 (T06-L10N-CONSTANTS).
  final String unavailableLabel;

  /// N-02: the shared read store. Each shown placement acquires its metric
  /// keys on mount and releases them on unmount, so a hide releases its
  /// lease at once. Null only in tests that check layout without leases.
  final SharedReadStore? store;

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

  Widget _halfRow(List<Widget> cells) => WidgetGrid(cells: cells);

  Widget _cell(BuildContext context, ResolvedPlacement placement) {
    final descriptor = placement.descriptor;
    final Widget content;
    if (descriptor == null || placement.unavailable) {
      content = UnavailableCard(label: unavailableLabel);
    } else if (store != null && descriptor.metricKeys.isNotEmpty) {
      content = _LeasedPlacement(
        key: ValueKey<String>(placement.itemKey),
        store: store!,
        keys: descriptor.metricKeys,
        child: descriptor.builder(context),
      );
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
}

/// N-02: one lease per shown placement. It acquires its metric keys in
/// `initState` and releases them in `dispose`, so hiding the placement (in
/// edit mode or by layout change) releases its reference at once. A shared
/// request stays alive while another placement or the hero holds it.
class _LeasedPlacement extends StatefulWidget {
  const _LeasedPlacement({
    required this.store,
    required this.keys,
    required this.child,
    super.key,
  });

  final SharedReadStore store;
  final List<MetricKey> keys;
  final Widget child;

  @override
  State<_LeasedPlacement> createState() => _LeasedPlacementState();
}

class _LeasedPlacementState extends State<_LeasedPlacement> {
  @override
  void initState() {
    super.initState();
    for (final key in widget.keys) {
      widget.store.acquire(key);
    }
  }

  @override
  void dispose() {
    for (final key in widget.keys) {
      widget.store.release(key);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
