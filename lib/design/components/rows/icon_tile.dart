import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/tokens.g.dart';

/// DESIGN 6.3: `IconTile` — a 40 pt icon tile with the section colour at
/// 14% and a 1 px edge (`border.chip`), used by list rows. The tile is
/// decorative: the row's own label carries the meaning.
enum IconTileVariant {
  /// The section colour at 14% (Home, Spending, Wealth, Plan rows).
  section,

  /// A neutral `surface.tile` fill (Settings rows in the reference).
  neutral,
}

/// DESIGN 6.3: `IconTile` — a 40 pt icon tile, used by list rows. The tile is
/// decorative: the row's own label carries the meaning.
class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    this.variant = IconTileVariant.section,
    super.key,
  });

  final AppIconData icon;
  final IconTileVariant variant;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    return Semantics(
      excludeSemantics: true,
      child: Container(
        width: SizeTokens.badgeM,
        height: SizeTokens.badgeM,
        decoration: BoxDecoration(
          color: variant == IconTileVariant.neutral
              ? tokens.surfaceTile
              : role.gradientStart.withAlpha(36), // 14% tint
          borderRadius: const BorderRadius.all(Radius.circular(RadiusTokens.m)),
          border: Border.all(color: tokens.borderChip, width: 1),
        ),
        child: Center(
          child: AppIcon(
            data: icon,
            size: SizeTokens.iconM,
            color: tokens.textPrimary,
          ),
        ),
      ),
    );
  }
}
