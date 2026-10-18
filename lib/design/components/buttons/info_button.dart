import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../tokens/tokens.g.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.3: `InfoButton` — the (i) icon at a 44 pt target. It opens the
/// glossary or "about this number" sheet. A semantic label is required.
class InfoButton extends StatelessWidget {
  const InfoButton({required this.semanticLabel, this.onPressed, super.key});

  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: AppInteraction(
        onActivated: onPressed,
        enabled: onPressed != null,
        borderRadius: BorderRadius.circular(SizeTokens.touchMin / 2),
        child: SizedBox(
          width: SizeTokens.touchMin,
          height: SizeTokens.touchMin,
          child: Center(
            child: AppIcon(
              data: AppIcons.info,
              size: SizeTokens.iconM,
              color: tokens.iconSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
