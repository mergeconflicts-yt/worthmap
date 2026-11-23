import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.3: `SelectTile`. A square choice tile for a grid of named
/// categories: `surface.tile`, `radius.m`, a 1 px `border.chip` edge, an
/// optional 12 pt data dot and a centred `bodyS` name. Selected: a 2 px
/// `text.primary` edge. The tile fills its parent width and is at least
/// [minHeight] tall, so a grid of four columns keeps 80 pt targets.
///
/// No colour is chosen here: [dotColor] comes from the caller's data role.
class SelectTile extends StatelessWidget {
  const SelectTile({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onPressed,
    this.dotColor,
    this.minHeight = 80,
    super.key,
  });

  final String label;

  /// The spoken name. Required for every tappable tile (AGENTS 6.9).
  final String semanticLabel;
  final bool selected;
  final VoidCallback? onPressed;

  /// The `data.category` role colour, or null for a name with no role.
  final Color? dotColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
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
              color: tokens.surfaceTile,
              borderRadius: BorderRadius.circular(RadiusTokens.m),
              border: Border.all(
                color: selected
                    ? tokens.textPrimary
                    : (enabled ? tokens.borderChip : tokens.disabled),
                width:
                    selected ? BorderTokens.focusRing : BorderTokens.hairline,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: const EdgeInsets.all(Space.s),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (dotColor != null) ...<Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: dotColor,
                          borderRadius: BorderRadius.circular(RadiusTokens.xs),
                        ),
                        child: const SizedBox(
                          width: Space.m,
                          height: Space.m,
                        ),
                      ),
                      const VSpace(Space.xs),
                    ],
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppText.bodyS.copyWith(
                        color: enabled ? tokens.textPrimary : tokens.disabled,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
