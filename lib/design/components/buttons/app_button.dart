import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';

/// DESIGN 6.3: `AppButton` variants.
enum AppButtonVariant {
  /// Solid `action.primary.fill` (the section colour); `text.onSection`.
  primary,

  /// `action.neutral.fill`; `text.onInverse`.
  neutral,

  /// Transparent with a `border.chip` edge.
  ghost,

  /// `surface.track`.
  soft,

  /// Filled neutral grey with a trash icon (DESTRUCTIVE-ROLE).
  destructive,
}

/// DESIGN 6.3: height `size.button`, `radius.pill`, `button` text, optional
/// leading icon, full width by default. No gradient, no glow.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.fullWidth = true,
    this.compact = false,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppIconData? icon;
  final bool fullWidth;

  /// Uses `size.buttonCompact` (44) instead of `size.button` (52).
  final bool compact;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final enabled = onPressed != null;

    final Color fill;
    final Color textColor;
    Border? border;
    switch (variant) {
      case AppButtonVariant.primary:
        fill = role.gradientStart;
        textColor = tokens.textOnSection;
      case AppButtonVariant.neutral:
        fill = tokens.actionNeutralFill;
        textColor = tokens.textOnInverse;
      case AppButtonVariant.ghost:
        fill = const Color(0x00000000);
        textColor = tokens.textPrimary;
        border = Border.all(color: tokens.borderChip);
      case AppButtonVariant.soft:
        fill = tokens.surfaceTrack;
        textColor = tokens.textPrimary;
      case AppButtonVariant.destructive:
        fill = tokens.actionDestructiveFill;
        textColor = tokens.actionDestructiveText;
    }

    final effectiveIcon = icon ??
        (variant == AppButtonVariant.destructive ? AppIcons.trash : null);
    final disabled = !enabled;
    final effectiveFill = disabled ? tokens.disabled : fill;
    final resolvedText = disabled ? tokens.textSecondary : textColor;
    final effectiveBorder = disabled ? null : border;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (effectiveIcon != null) ...<Widget>[
          AppIcon(
            data: effectiveIcon,
            size: SizeTokens.iconM,
            color: resolvedText,
          ),
          const HSpace(Space.s),
        ],
        Flexible(
          child: Text(
            label,
            style: AppText.button.copyWith(color: resolvedText),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final button = DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveFill,
        border: effectiveBorder,
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: compact ? SizeTokens.buttonCompact : SizeTokens.button,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Center(child: content),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: fullWidth
              ? SizedBox(width: double.infinity, child: button)
              : button,
        ),
      ),
    );
  }
}
