import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../feedback/count_badge.dart';
import '../interaction/app_interaction.dart';

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
    this.badgeCount,
    super.key,
  });

  final AppIconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;

  /// A count badge at the top right of the button. Zero or null hides it. The
  /// spoken [semanticLabel] must include the count; the badge is decorative.
  final int? badgeCount;

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
      child: AppInteraction(
        onActivated: onPressed,
        enabled: onPressed != null,
        borderRadius: BorderRadius.circular(SizeTokens.touchMin / 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: SizeTokens.touchMin,
            height: SizeTokens.touchMin,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: <Widget>[
                AppIcon(
                  data: icon,
                  size: SizeTokens.iconM,
                  color:
                      onPressed == null ? tokens.disabled : tokens.textPrimary,
                ),
                if ((badgeCount ?? 0) > 0)
                  Positioned(
                    right: 0,
                    top: -Space.xs,
                    child: ExcludeSemantics(
                      child: CountBadge(
                        count: badgeCount!,
                        color: tokens.role(context.section).gradientStart,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
