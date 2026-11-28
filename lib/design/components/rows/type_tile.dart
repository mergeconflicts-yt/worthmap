// DESIGN 6.7: `TypeTile` — one recorded or empty part of a wealth card.
//
// The tile copies the X30 category tile (DESIGN 7.2, `RingMeterVariant.card`):
// a centred icon, name, number and one fact. The icon has no ring or circle
// (owner request 28 Nov 2026). An empty tile has the dashed edit outline and
// "None recorded". The caller supplies every visible string; this component
// formats no money.
library;

import 'dart:math' as math;

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
    this.nameLines = 2,
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

  /// The lines kept for the name in every tile of one grid. The grid reads the
  /// longest name at the cell width, so all tiles share one height.
  final int nameLines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colours = ChartColours.of(context, ChartTone.onCard);
    final markColour = colours.mark(mark);
    final nameStyle = AppText.bodyStrong.copyWith(color: tokens.textSecondary);
    final valueStyle = AppText.numberXS.copyWith(color: tokens.textPrimary);
    final factStyle = AppText.bodyS.copyWith(color: tokens.textSecondary);
    // One slot height for every tile, so every row has one height. The name
    // takes [nameLines] lines and a fact one line.
    final nameSlot = _lineHeight(context, nameStyle) * nameLines;
    final valueSlot = math.max(
      _lineHeight(context, valueStyle),
      _lineHeight(context, factStyle),
    );
    final factSlot = _lineHeight(context, factStyle);

    final body = Container(
      // A filled tile takes the dashed outline's 6 pt gap as inner vertical
      // padding, so a filled and an empty tile have the same outer height. The
      // 1 pt border sits inside the box, so it comes off the padding. The width
      // keeps the category tile's inset, so a long name does not break.
      padding: empty
          ? const EdgeInsets.symmetric(
              horizontal: Space.xxs,
              vertical: Space.s,
            )
          : const EdgeInsets.symmetric(
              horizontal: Space.xxs,
              vertical: Space.s + DashedOutline.gap - 1,
            ),
      decoration: empty
          ? null
          : BoxDecoration(
              color: tokens.surfaceTile,
              borderRadius: BorderRadius.circular(RadiusTokens.m),
              border: Border.all(color: tokens.borderChip),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          AppIcon(
            data: icon,
            size: SizeTokens.iconS,
            color: empty ? tokens.textSecondary : markColour,
          ),
          const VSpace(Space.xs),
          SizedBox(
            height: nameSlot,
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: nameLines,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
            ),
          ),
          if (!empty)
            SizedBox(
              height: valueSlot,
              child: Align(
                alignment: Alignment.topCenter,
                child: MoneyText(
                  value!,
                  hidden: hidden,
                  trimZeroFraction: true,
                  style: valueStyle,
                ),
              ),
            ),
          SizedBox(
            height: empty ? valueSlot + factSlot : factSlot,
            child: empty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      emptyLabel ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: factStyle,
                    ),
                  )
                : fact == null
                    ? null
                    : Text(
                        fact!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: factStyle,
                      ),
          ),
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

  /// The line box of [style] at the active text scale.
  double _lineHeight(BuildContext context, TextStyle style) {
    final size = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14);
    return size * (style.height ?? 1.2);
  }

  /// A copy for the grid, with the name space the grid found.
  TypeTile withNameLines(int lines) => TypeTile(
        name: name,
        icon: icon,
        mark: mark,
        value: value,
        fact: fact,
        empty: empty,
        emptyLabel: emptyLabel,
        hidden: hidden,
        onTap: onTap,
        nameLines: lines,
      );
}

/// Three tiles per row (two above 1.3 text scale).
///
/// Every row uses equal columns and one height, so all tiles share one size.
/// The grid reads the longest name at the cell width, and every tile keeps
/// that many name lines.
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
            (constraints.maxWidth - Space.s * (columns - 1)) / columns;
        final nameLines = _nameLines(context, width);
        final rows = <Widget>[];
        for (var start = 0; start < tiles.length; start += columns) {
          final cells = <Widget>[];
          for (var offset = 0; offset < columns; offset++) {
            if (offset > 0) {
              cells.add(const HSpace(Space.s));
            }
            final index = start + offset;
            cells.add(
              Expanded(
                child: index < tiles.length
                    ? tiles[index].withNameLines(nameLines)
                    : const SizedBox.shrink(),
              ),
            );
          }
          if (rows.isNotEmpty) {
            rows.add(const VSpace(Space.s));
          }
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }

  /// Two name lines when any name needs them at [cellWidth], else one.
  int _nameLines(BuildContext context, double cellWidth) {
    final style = AppText.bodyStrong;
    // The content width is one gap plus one padding smaller than the cell.
    // The empty tile is the narrowest, so it sets the name space.
    final textWidth = cellWidth - 2 * (Space.xxs + DashedOutline.gap);
    final scaler = MediaQuery.textScalerOf(context);
    for (final tile in tiles) {
      final painter = TextPainter(
        text: TextSpan(text: tile.name, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 2,
      )..layout(maxWidth: textWidth > 0 ? textWidth : 0);
      final lines = painter.computeLineMetrics().length;
      painter.dispose();
      if (lines > 1) {
        return 2;
      }
    }
    return 1;
  }
}
