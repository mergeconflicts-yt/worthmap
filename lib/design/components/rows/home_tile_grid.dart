// DESIGN 6.4: `HomeTileGrid` — the 2-column tile grid used by X10 Quick look.
//
// A tile has a decorative icon, a label, one value and one line. The value is
// a widget so the caller can use `MoneyText` and keep the hidden state.
library;

import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../rows/icon_tile.dart';

/// One tile.
class HomeTile {
  const HomeTile({
    required this.icon,
    required this.label,
    required this.value,
    this.line,
  });

  final AppIconData icon;
  final String label;
  final Widget value;
  final String? line;
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
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final left = _tile(context, tiles[i], i);
      final right =
          i + 1 < tiles.length ? _tile(context, tiles[i + 1], i + 1) : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            const HSpace(Space.s),
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
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
    return Semantics(
      label: label,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(Space.s),
        decoration: BoxDecoration(
          color: tokens.surfaceTile,
          borderRadius: const BorderRadius.all(Radius.circular(RadiusTokens.m)),
          border: Border.all(color: tokens.borderChip),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconTile(icon: tile.icon),
            const VSpace(Space.s),
            Text(
              tile.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: tokens.textSecondary),
            ),
            const VSpace(Space.xxs),
            DefaultTextStyle.merge(
              style: AppText.bodyStrong.copyWith(color: tokens.textPrimary),
              child: tile.value,
            ),
            if (tile.line != null) ...<Widget>[
              const VSpace(Space.xxs),
              Text(
                tile.line!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: tokens.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
