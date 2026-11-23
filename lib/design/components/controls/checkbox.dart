import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../tokens/tokens.g.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.3: `AppCheckbox`. A 30 × 30 box in a 44 × 44 target, radius 10.
///
/// Ticked: `surface.inverse` with a `text.onInverse` tick. Unticked: a 1.5 px
/// `border.chip` edge. The whole 44 pt target toggles, and the label is the
/// item name from the caller.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final bool value;

  /// Null disables the control.
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  static const double boxSize = 30;
  static const double borderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onChanged != null;
    final fill = value ? tokens.surfaceInverse : null;
    final border = value
        ? null
        : Border.all(
            color: enabled ? tokens.borderChip : tokens.disabled,
            width: borderWidth,
          );
    final tick = value ? tokens.textOnInverse : tokens.textPrimary;

    return Align(
      alignment: Alignment.center,
      widthFactor: 1,
      heightFactor: 1,
      child: Semantics(
        label: semanticLabel,
        checked: value,
        enabled: enabled,
        button: true,
        child: AppInteraction(
          onActivated: enabled ? () => onChanged!(!value) : null,
          enabled: enabled,
          borderRadius: BorderRadius.circular(RadiusTokens.pill),
          child: SizedBox(
            width: SizeTokens.touchMin,
            height: SizeTokens.touchMin,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  border: border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox(
                  width: boxSize,
                  height: boxSize,
                  child: value
                      ? Center(
                          child: AppIcon(
                            data: AppIcons.check,
                            size: SizeTokens.iconS,
                            color: tick,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
