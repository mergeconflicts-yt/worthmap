import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.3, X22: `DayCell`. One day button in a month grid: a 44 pt target,
/// `radius.m`, `surface.tile` with a 1 px `border.chip` edge. Selected: the
/// section `action.selected.fill` with `text.onSection`. Today, when not
/// selected: a 1 px `text.primary` edge. A future day is disabled and its
/// number uses `text.secondary`.
class DayCell extends StatelessWidget {
  const DayCell({
    required this.day,
    required this.semanticLabel,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    this.isToday = false,
    this.compact = false,
    super.key,
  });

  /// The day of the month, 1 to 31.
  final int day;

  /// The full spoken date, with the "today" word when it applies.
  final String semanticLabel;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool isToday;

  /// True above 1.3 text scale; the number uses `bodyS` so it stays in the
  /// cell at 44 pt.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final Color number;
    if (!enabled) {
      number = tokens.textSecondary;
    } else if (selected) {
      number = tokens.textOnSection;
    } else {
      number = tokens.textPrimary;
    }
    final Color edge;
    if (selected) {
      edge = tokens.textOnSection;
    } else if (isToday) {
      edge = tokens.textPrimary;
    } else {
      edge = enabled ? tokens.borderChip : tokens.disabled;
    }
    return Semantics(
      button: enabled,
      selected: selected,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: AppInteraction(
        onActivated: onPressed,
        enabled: enabled,
        borderRadius: BorderRadius.circular(RadiusTokens.m),
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? null : tokens.surfaceTile,
              gradient: selected ? role.selectedFill.toLinearGradient() : null,
              borderRadius: BorderRadius.circular(RadiusTokens.m),
              border: Border.all(
                color: edge,
                width: BorderTokens.hairline,
              ),
            ),
            child: Center(
              child: Text(
                '$day',
                maxLines: 1,
                style: (compact ? AppText.bodyS : AppText.body).copyWith(
                  color: number,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
