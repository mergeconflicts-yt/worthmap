import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import '../../core/money.dart';
import '../../core/percent.dart';
import '../format/hidden_amounts.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';
import 'chart_frame.dart';
import 'chart_tone.dart';
import 'chart_values.dart';

/// DESIGN 7.2, 7.3: the `SplitBar` height variants.
enum SplitBarVariant {
  /// The standard split bar (DESIGN-HTML-005: 132 px).
  standard,

  /// The primary Spending split (164 px).
  primary,

  /// The allocation split (116 px).
  allocation,
}

extension SplitBarHeight on SplitBarVariant {
  double get height => switch (this) {
        SplitBarVariant.standard => 132,
        SplitBarVariant.primary => 164,
        SplitBarVariant.allocation => 116,
      };
}

/// DESIGN 7.2: one part of a split.
class SplitBarPart {
  const SplitBarPart({
    required this.name,
    required this.amount,
    required this.mark,
  });

  final String name;
  final Money amount;
  final ChartMark mark;
}

/// DESIGN 7.2: `SplitBar` — a whole and its parts with exact shares.
///
/// Shares come from `Percent.split` (largest remainder), so they add to 100%.
/// Segments are solid with 3 px gaps and pill ends. Labels sit outside the bar
/// and never resize a segment. No glow.
class SplitBar extends StatelessWidget {
  const SplitBar({
    required this.title,
    required this.period,
    required this.parts,
    required this.columns,
    this.emptyLabel,
    this.hidden,
    this.variant = SplitBarVariant.standard,
    this.tone = ChartTone.onStage,
    super.key,
  });

  final String title;
  final String period;
  final List<SplitBarPart> parts;

  /// Table columns: name, amount, share.
  final List<String> columns;
  final String? emptyLabel;
  final bool? hidden;
  final SplitBarVariant variant;
  final ChartTone tone;

  @override
  Widget build(BuildContext context) {
    final hiddenNow = HiddenAmountsScope.resolve(context, hidden);
    final colours = ChartColours.of(context, tone);
    final tokens = context.tokens;
    final shares = _shares();
    final shareText = <String>[
      for (final share in shares) '${_trim(share.value)}%',
    ];

    final rows = <List<String>>[
      for (var i = 0; i < parts.length; i++)
        <String>[
          parts[i].name,
          chartAmountText(parts[i].amount, hidden: hiddenNow),
          shareText[i],
        ],
    ];
    final label = <String>[
      title,
      period,
      if (parts.isEmpty)
        (emptyLabel ?? '')
      else
        for (var i = 0; i < parts.length; i++)
          '${parts[i].name} '
              '${chartAmountText(parts[i].amount, hidden: hiddenNow)} '
              '${shareText[i]}',
    ].where((part) => part.isNotEmpty).join('. ');

    final legend = parts.isEmpty
        ? Text(
            emptyLabel ?? '',
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < parts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: _legendRow(
                    parts[i],
                    colours,
                    hiddenNow,
                    shareText.isEmpty ? '' : shareText[i],
                  ),
                ),
            ],
          );

    return ChartFrame(
      label: label,
      emptyLabel: emptyLabel,
      table: ChartTable(columns: columns, rows: rows),
      chart: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (parts.isEmpty)
            Text(
              emptyLabel ?? '',
              style: AppText.caption.copyWith(color: tokens.textSecondary),
            )
          else ...<Widget>[
            SizedBox(
              height: variant.height,
              child: _segs(colours),
            ),
            const VSpace(Space.s),
            legend,
          ],
        ],
      ),
    );
  }

  Widget _legendRow(
    SplitBarPart part,
    ChartColours colours,
    bool hiddenNow,
    String share,
  ) {
    final amount = chartAmountText(part.amount, hidden: hiddenNow);
    final name = Row(
      children: <Widget>[
        _Swatch(colour: colours.mark(part.mark)),
        const HSpace(Space.s),
        Expanded(child: Text(part.name, style: AppText.caption)),
      ],
    );
    final values = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(amount, style: AppText.numberXS),
        const HSpace(Space.s),
        Text(share, style: AppText.caption),
      ],
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final largeText =
            MediaQuery.textScalerOf(context).scale(13) >= 13 * 1.3;
        if (largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              name,
              const VSpace(Space.xxs),
              Padding(
                padding: const EdgeInsets.only(left: Space.l),
                child: values,
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: name),
            values,
          ],
        );
      },
    );
  }

  Widget _segs(ChartColours colours) {
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    final basis = <int>[
      for (final part in parts) part.amount.minor.abs().clamp(1, 1 << 30),
    ];
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(RadiusTokens.pill)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < parts.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: basis[i],
              child: ColoredBox(color: colours.mark(parts[i].mark)),
            ),
          ],
        ],
      ),
    );
  }

  static String _trim(Decimal value) {
    final text = value.toString();
    if (!text.contains('.')) {
      return text;
    }
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// SPEC 4.1: shares come from [Percent.split] and add to exactly 100%. A
  /// known zero total has no shares: the bar shows no part and the table keeps
  /// the zero amounts.
  List<Percent> _shares() {
    if (parts.isEmpty) {
      return const <Percent>[];
    }
    var total = Decimal.zero;
    for (final part in parts) {
      total = total + part.amount.toDecimal().abs();
    }
    if (total == Decimal.zero) {
      return <Percent>[for (final _ in parts) Percent.zero];
    }
    return Percent.split(
      <Decimal>[for (final part in parts) part.amount.toDecimal().abs()],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: Space.s,
        width: Space.s,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colour,
            borderRadius: const BorderRadius.all(
              Radius.circular(RadiusTokens.xs),
            ),
          ),
        ),
      );
}
