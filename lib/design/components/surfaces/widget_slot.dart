import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';

/// DESIGN 6.7: `WidgetSlot` variants.
enum WidgetSlotVariant { normal, editing }

/// DESIGN 6.7, WIDGETS-001: wraps each tab-screen card with its title. In
/// editing mode it shows an outline and a tool row and its content is inert.
///
/// Placeholder for Phase 1 (T05): the dashed outline and the drag handle need a
/// component painter (DECISION-PENDING: WIDGETSLOT-DASH, T06).
class WidgetSlot extends StatelessWidget {
  const WidgetSlot({
    required this.child,
    this.variant = WidgetSlotVariant.normal,
    this.toolRow,
    super.key,
  });

  final Widget child;
  final WidgetSlotVariant variant;

  /// The edit tool row (Hide, title, Move up, Move down, drag handle). Drawn on
  /// the title line in editing mode.
  final Widget? toolRow;

  @override
  Widget build(BuildContext context) {
    if (variant == WidgetSlotVariant.normal) {
      return child;
    }
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (toolRow != null) ...<Widget>[
          toolRow!,
          const VSpace(Space.s),
        ],
        Opacity(
          opacity: 0.72,
          // N-12: edit-mode content is inert for screen readers too, not only
          // for touch. The tool row above stays accessible.
          child: ExcludeSemantics(
            excluding: true,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: tokens.borderChip),
                  borderRadius: BorderRadius.circular(RadiusTokens.card + 6),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Space.s),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
