import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.4: `PillPicker`. A small 44 pt pill for a currency, date or
/// account. It opens a sheet through [onPressed]; the sheet is the caller's.
class PillPicker extends StatelessWidget {
  const PillPicker({
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  final String label;

  /// The spoken name, for example "Currency: USD. Opens details".
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final enabled = onPressed != null;
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      child: Semantics(
        label: semanticLabel,
        button: true,
        enabled: enabled,
        excludeSemantics: true,
        child: AppInteraction(
          onActivated: onPressed,
          enabled: enabled,
          borderRadius: BorderRadius.circular(RadiusTokens.pill),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? null : tokens.surfaceTile,
              gradient: selected ? role.selectedFill.toLinearGradient() : null,
              borderRadius: BorderRadius.circular(RadiusTokens.pill),
              border: Border.all(
                color: enabled ? tokens.borderChip : tokens.disabled,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: SizeTokens.touchMin),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.card),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: AppText.buttonS.copyWith(
                        color: selected
                            ? tokens.textOnSection
                            : tokens.textPrimary,
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
