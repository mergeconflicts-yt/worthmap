import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../tokens/tokens.g.dart';

/// DESIGN 6.3: `IconButton` variants.
enum AppIconButtonVariant {
  /// White 6% / ink 5%, no edge. Back and Close use this.
  onPage,

  /// `surface.tile`.
  onCard,

  /// No fill.
  plain,
}

/// DESIGN 6.3: a 44 × 44 circle, `radius.pill`, icon `size.iconM` in
/// `text.primary`, with a required semantic label.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.variant = AppIconButtonVariant.onPage,
    super.key,
  });

  final AppIconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fill = switch (variant) {
      AppIconButtonVariant.onPage => tokens.surfaceTrack,
      AppIconButtonVariant.onCard => tokens.surfaceTile,
      AppIconButtonVariant.plain => const Color(0x00000000),
    };
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: MouseRegion(
        cursor: onPressed != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: SizeTokens.touchMin,
              height: SizeTokens.touchMin,
              child: Center(
                child: AppIcon(
                  data: icon,
                  size: SizeTokens.iconM,
                  color:
                      onPressed == null ? tokens.disabled : tokens.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
