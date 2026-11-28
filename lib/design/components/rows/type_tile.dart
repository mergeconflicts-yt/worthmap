// DESIGN 6.7: `TypeTile` — one recorded or empty part of a wealth card.
//
// A recorded tile carries a tinted glyph, the name, the value and one fact.
// An empty tile has the dashed edit outline and "None recorded". The caller
// supplies every visible string; this component formats no money.
library;

import 'package:flutter/widgets.dart';

import '../../charts/chart_tone.dart';
import '../../format/money_text.dart';
import '../../format/value_presentation.dart';
import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';
import '../surfaces/dashed_outline.dart';

/// One tile in a [TypeTileGrid].
class TypeTile extends StatelessWidget {
  const TypeTile({
    required this.name,
    required this.icon,
    required this.mark,
    this.value,
    this.fact,
    this.empty = false,
    this.emptyLabel,
    this.hidden,
    this.onTap,
    super.key,
  });

  final String name;
  final AppIconData icon;
  final ChartMark mark;

  /// The amount; null shows [emptyLabel] (for example "None recorded").
  final ValueSpec? value;
  final String? fact;

  /// True draws the dashed outline and no fill (SCREENS X40 empty type).
  final bool empty;
  final String? emptyLabel;

  /// The component override; null follows the hidden-amounts scope.
  final bool? hidden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colours = ChartColours.of(context, ChartTone.onCard);
    final markColour = colours.mark(mark);
    final body = Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(Space.s),
      decoration: empty
          ? null
          : BoxDecoration(
              color: tokens.surfaceTile,
              borderRadius: BorderRadius.circular(RadiusTokens.m),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: markColour.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(RadiusTokens.s),
            ),
            child: Center(
              child: AppIcon(
                data: icon,
                size: SizeTokens.iconS,
                color: empty ? tokens.textSecondary : markColour,
              ),
            ),
          ),
          const VSpace(Space.s),
          Text(
            name,
            style: AppText.captionStrong.copyWith(
              color: tokens.textPrimary,
            ),
            maxLines: 2,
          ),
          const VSpace(Space.xxs),
          if (value != null)
            MoneyText(
              value!,
              hidden: hidden,
              trimZeroFraction: true,
              style: AppText.numberXS.copyWith(color: tokens.textPrimary),
            )
          else
            Text(
              emptyLabel ?? '',
              style: AppText.caption.copyWith(color: tokens.textSecondary),
            ),
          if (fact != null) ...<Widget>[
            const VSpace(Space.xxs),
            Text(
              fact!,
              style: AppText.caption.copyWith(color: tokens.textSecondary),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
    final content = empty
        ? DashedOutline(
            color: tokens.borderDraft,
            radius: RadiusTokens.m,
            child: body,
          )
        : body;
    if (onTap == null) {
      return content;
    }
    return Semantics(
      button: true,
      label: name,
      child: AppInteraction(
        onActivated: onTap,
        borderRadius: BorderRadius.circular(RadiusTokens.m),
        child: content,
      ),
    );
  }
}

/// Three tiles per row (two above 1.3 text scale).
class TypeTileGrid extends StatelessWidget {
  const TypeTileGrid({required this.tiles, super.key});

  final List<TypeTile> tiles;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = scale >= 1.8
        ? 1
        : scale > 1.3
            ? 2
            : 3;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width =
            (constraints.maxWidth - Space.m * (columns - 1)) / columns;
        return Wrap(
          spacing: Space.m,
          runSpacing: Space.m,
          children: <Widget>[
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}
