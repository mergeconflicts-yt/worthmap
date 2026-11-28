// DESIGN 7.2: `SplitStrip` — a thin segmented share bar.
//
// `SplitBar` is the tall 132 pt bar used on Wealth and Spending. Home needs the
// compact 8 pt strip from the mockup, with the same exact shares from
// `Percent.split` and the same table. Labels stay outside the bar.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import '../../core/money.dart';
import '../../core/percent.dart';
import '../format/hidden_amounts.dart';
import '../format/percent_text.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';
import 'chart_frame.dart';
import 'chart_tone.dart';
import 'chart_values.dart';

/// One part of the strip.
class SplitStripPart {
  const SplitStripPart({
    required this.name,
    required this.amount,
    required this.mark,
  });

  final String name;
  final Money amount;
  final ChartMark mark;
}

/// A thin share strip with a legend and a table.
class SplitStrip extends StatelessWidget {
  const SplitStrip({
    required this.title,
    required this.period,
    required this.parts,
    required this.columns,
    this.shareDecimals = 1,
    this.showTable = false,
    this.emptyLabel,
    this.hidden,
    super.key,
  });

  final String title;
  final String period;
  final List<SplitStripPart> parts;

  /// Table columns: name, amount, share.
  final List<String> columns;

  /// Decimal places in the shares. 0 gives whole shares that still add to
  /// exactly 100% (SPEC 4.1).
  final int shareDecimals;

  /// Shows the "Show as table" disclosure. Off by default; the legend already
  /// lists every value (X10 This month).
  final bool showTable;

  final String? emptyLabel;
  final bool? hidden;

  @override
  Widget build(BuildContext context) {
    final hiddenNow = HiddenAmountsScope.resolve(context, hidden);
    final colours = ChartColours.of(context, ChartTone.onCard);
    final tokens = context.tokens;
    final shares = parts.isEmpty
        ? const <Percent>[]
        : Percent.split(
            <Decimal>[
              for (final part in parts) Decimal.fromInt(part.amount.minor),
            ],
            scale: shareDecimals,
          );
    final shareText = <String>[
      for (final share in shares) formatPercent(share, decimals: shareDecimals),
    ];
    final table = ChartTable(
      columns: columns,
      rows: <List<String>>[
        for (var i = 0; i < parts.length; i++)
          <String>[
            parts[i].name,
            chartAmountText(parts[i].amount, hidden: hiddenNow),
            shareText[i],
          ],
      ],
    );
    final label = <String>[
      title,
      period,
      for (var i = 0; i < parts.length; i++)
        '${parts[i].name} '
            '${chartAmountText(parts[i].amount, hidden: hiddenNow)} '
            '${shareText[i]}',
    ].where((part) => part.isNotEmpty).join('. ');

    return ChartFrame(
      label: label,
      emptyLabel: emptyLabel,
      table: table,
      showTable: showTable,
      chart: parts.isEmpty
          ? Text(
              emptyLabel ?? '',
              style: AppText.caption.copyWith(color: tokens.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 8,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(RadiusTokens.xs),
                    ),
                    child: Row(
                      children: <Widget>[
                        for (var i = 0; i < parts.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 2),
                          if (shares[i].value > Decimal.zero)
                            Expanded(
                              flex: shares[i].value.toDouble().round(),
                              child: SizedBox.expand(
                                child: ColoredBox(
                                  color: colours.mark(parts[i].mark),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const VSpace(Space.s),
                for (var i = 0; i < parts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xxs),
                    child: Row(
                      children: <Widget>[
                        _Swatch(colour: colours.mark(parts[i].mark)),
                        const HSpace(Space.s),
                        Expanded(
                          child: Text(
                            parts[i].name,
                            style: AppText.caption.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          chartAmountText(parts[i].amount, hidden: hiddenNow),
                          style: AppText.caption,
                        ),
                        const HSpace(Space.s),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 48),
                          child: Text(
                            shareText[i],
                            textAlign: TextAlign.end,
                            style: AppText.caption.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A tiny colour swatch for the legend.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
      );
}
