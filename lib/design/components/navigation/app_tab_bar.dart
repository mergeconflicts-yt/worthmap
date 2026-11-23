import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/token_types.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// One tab in the [AppTabBar].
final class AppTabItem {
  const AppTabItem({
    required this.section,
    required this.label,
    required this.semanticLabel,
    required this.icon,
    this.badgeCount,
  });

  final Section section;
  final String label;

  /// The spoken name. It includes the count when a badge shows.
  final String semanticLabel;
  final AppIconData icon;

  /// A count badge on this tab. Zero or null hides it.
  final int? badgeCount;
}

/// SPEC 5.1 / DESIGN 6.7: `AppTabBar`. A floating 64 pt bar with four section
/// tabs and one centre Add pill. The active tab uses its section colour. The
/// Add is the only add control; a long press starts voice input.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.addSemanticLabel,
    this.onVoice,
    super.key,
  }) : assert(items.length == 4, 'The tab bar has four sections');

  final List<AppTabItem> items;
  final Section selected;
  final ValueChanged<Section> onSelect;
  final VoidCallback onAdd;
  final String addSemanticLabel;
  final VoidCallback? onVoice;

  /// The tab bar floats 14 pt above the bottom and 16 pt from the sides.
  static const double lift = 14;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final iconOnly = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Align(
      heightFactor: 1,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.elevationNav.fill ?? tokens.surfaceSheet,
            borderRadius: BorderRadius.circular(RadiusTokens.pill),
            border: Border.all(color: tokens.surfaceGlassEdge),
            boxShadow: tokens.elevationNav.shadows,
          ),
          child: SizedBox(
            height: SizeTokens.tabBar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _Tab(
                      item: items[0],
                      selected: selected == items[0].section,
                      onPressed: () => onSelect(items[0].section),
                      iconOnly: iconOnly,
                    ),
                  ),
                  Expanded(
                    child: _Tab(
                      item: items[1],
                      selected: selected == items[1].section,
                      onPressed: () => onSelect(items[1].section),
                      iconOnly: iconOnly,
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Center(
                      child: _AddPill(
                        semanticLabel: addSemanticLabel,
                        onAdd: onAdd,
                        onVoice: onVoice,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Tab(
                      item: items[2],
                      selected: selected == items[2].section,
                      onPressed: () => onSelect(items[2].section),
                      iconOnly: iconOnly,
                    ),
                  ),
                  Expanded(
                    child: _Tab(
                      item: items[3],
                      selected: selected == items[3].section,
                      onPressed: () => onSelect(items[3].section),
                      iconOnly: iconOnly,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.onPressed,
    required this.iconOnly,
  });

  final AppTabItem item;
  final bool selected;
  final VoidCallback onPressed;

  /// Above 1.3 text scale the bar keeps all four targets and the one Add. The
  /// labels move to the semantic tree instead of truncating in the pixels.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(item.section);
    final colour = selected ? role.text : tokens.textControl;
    final badge = item.badgeCount ?? 0;

    return Semantics(
      label: item.semanticLabel,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: AppInteraction(
        onActivated: onPressed,
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: SizeTokens.touchMin,
            minWidth: SizeTokens.touchMin,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AppIcon(
                    data: item.icon,
                    size: SizeTokens.iconL,
                    color: colour,
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -Space.s,
                      top: -Space.s,
                      child: ExcludeSemantics(
                        child: _Badge(count: badge, colour: role.gradientStart),
                      ),
                    ),
                ],
              ),
              if (!iconOnly) ...<Widget>[
                const VSpace(Space.xxs),
                Text(
                  item.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.tabLabel.copyWith(
                    color: colour,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.colour});

  final int count;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Center(
            child: Text(
              '$count',
              style: AppText.tabLabel.copyWith(
                color: tokens.textOnSection,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({
    required this.semanticLabel,
    required this.onAdd,
    required this.onVoice,
  });

  final String semanticLabel;
  final VoidCallback onAdd;
  final VoidCallback? onVoice;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: semanticLabel,
      button: true,
      onLongPress: onVoice,
      child: AppInteraction(
        onActivated: onAdd,
        onLongPressed: onVoice,
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.actionNeutralFill,
            borderRadius: BorderRadius.circular(RadiusTokens.pill),
          ),
          child: SizedBox(
            width: 56,
            height: SizeTokens.buttonCompact,
            child: Center(
              child: AppIcon(
                data: AppIcons.addTabBar,
                size: SizeTokens.iconL,
                color: tokens.textOnInverse,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
