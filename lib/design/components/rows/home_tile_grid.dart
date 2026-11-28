// DESIGN 6.4: `HomeTileGrid` — the 2-column tile grid used by X10.
//
// A tile has an optional decorative icon, a label, one value and optional
// parts under it. The value is a widget so the caller can use `MoneyText` and
// keep the hidden state. The value is the largest element of the tile
// (DESIGN 6.4: `numberM`; X10 This month figures use `numberL`).
library;

import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';

/// One tile.
class HomeTile {
  const HomeTile({
    required this.label,
    required this.value,
    this.icon,
    this.line,
    this.lineColor,
    this.footer,
    this.valueStyle,
    this.openBottom = false,
  });

  /// The decorative glyph. Null draws no icon (X10 This month).
  final AppIconData? icon;
  final String label;
  final Widget value;

  /// One context line under the value.
  final String? line;

  /// The colour of [line]. Null uses `text.secondary`.
  final Color? lineColor;

  /// A component under the line, for example the limit meter (X10 This
  /// month).
  final Widget? footer;

  /// The value style. Null uses `numberM` (DESIGN 6.4).
  final TextStyle? valueStyle;

  /// Draws no bottom border, so the tile merges into the content under it
  /// (X10 This month, owner's mockup).
  final bool openBottom;
}

/// The tile grid. Two columns; the last tile keeps half the width.
class HomeTileGrid extends StatelessWidget {
  const HomeTileGrid({
    required this.tiles,
    this.spokenLabels = const <String>[],
    super.key,
  });

  final List<HomeTile> tiles;

  /// One spoken label per tile, in the same order.
  final List<String> spokenLabels;

  @override
  Widget build(BuildContext context) {
    // SCREENS X10: tiles stack at 200%.
    final largeText = MediaQuery.textScalerOf(context).scale(13) >= 13 * 1.3;
    if (largeText) {
      return Column(
        children: <Widget>[
          for (var i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) const VSpace(Space.s),
            _tile(context, tiles[i], i),
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final left = _tile(context, tiles[i], i);
      final right =
          i + 1 < tiles.length ? _tile(context, tiles[i + 1], i + 1) : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: left),
              const HSpace(Space.s),
              Expanded(child: right ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (var i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const VSpace(Space.s),
          rows[i],
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, HomeTile tile, int index) {
    final tokens = context.tokens;
    final label =
        index < spokenLabels.length ? spokenLabels[index] : tile.label;
    final icon = tile.icon;
    final line = tile.line;
    final footer = tile.footer;
    final borderSide = BorderSide(color: tokens.borderChip);
    return Semantics(
      label: label,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(Space.s),
        decoration: BoxDecoration(
          color: tokens.surfaceTile,
          borderRadius: const BorderRadius.all(Radius.circular(RadiusTokens.m)),
          border: Border(
            top: borderSide,
            left: borderSide,
            right: borderSide,
            bottom: tile.openBottom ? BorderSide.none : borderSide,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  ExcludeSemantics(
                    child: AppIcon(
                      data: icon,
                      size: SizeTokens.iconS,
                      color: tokens.textControl,
                    ),
                  ),
                  const HSpace(Space.s),
                ],
                Expanded(
                  child: Text(
                    tile.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: icon == null
                        ? AppText.caption.copyWith(
                            color: tokens.textSecondary,
                          )
                        : AppText.captionStrong.copyWith(
                            color: tokens.textPrimary,
                          ),
                  ),
                ),
              ],
            ),
            const VSpace(Space.s),
            DefaultTextStyle.merge(
              style: (tile.valueStyle ?? AppText.numberM)
                  .copyWith(color: tokens.textPrimary),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: tile.value,
              ),
            ),
            if (line != null) ...<Widget>[
              const VSpace(Space.xs),
              Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  color: tile.lineColor ?? tokens.textSecondary,
                ),
              ),
            ],
            if (footer != null) ...<Widget>[
              const VSpace(Space.s),
              footer,
            ],
          ],
        ),
      ),
    );
  }
}
