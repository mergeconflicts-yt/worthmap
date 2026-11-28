import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/money.dart';
import '../format/hidden_amounts.dart';
import '../icons/app_icons.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';
import 'chart_frame.dart';
import 'chart_tone.dart';
import 'chart_values.dart';

/// DESIGN 7.2: the `RingMeter` variants.
enum RingMeterVariant {
  /// The plain ring: track, left-aligned text (X32, gallery).
  plain,

  /// A category tile: centred text and a smaller ring, with no today tick
  /// (X30 By category, owner request 23 Nov 2026).
  card,
}

/// DESIGN 7.2: `RingMeter` — one amount against its limit.
///
/// The track is `surface.track`; the arc is the chart mark. A fixed bill (rent,
/// insurance) draws a dashed arc. The white tick marks today's share of the
/// period. There is no glow on the arc (GLOW-001).
///
/// The widget is one mark, not a chart frame. A grid of rings is one chart:
/// `RingMeterGrid` supplies the single label and the one table.
class RingMeter extends StatelessWidget {
  const RingMeter({
    required this.name,
    required this.value,
    required this.limit,
    this.icon,
    this.fixed = false,
    this.todayShare,
    this.paidLabel,
    this.leftLabel,
    this.hidden,
    this.mark = ChartMark.neutral,
    this.iconUsesMark = false,
    this.variant = RingMeterVariant.plain,
    this.size = 76,
    super.key,
  });

  /// The category or limit name, for example "Groceries".
  final String name;

  /// The amount used in the period.
  final Money value;

  /// The limit for the period.
  final Money limit;

  final AppIconData? icon;

  /// DESIGN 7.2: fixed bills draw a dashed arc.
  final bool fixed;

  /// Today's share of the period, from 0 to 1. Null hides the tick.
  final double? todayShare;

  /// The word for "Paid" when the value reaches the limit (l10n).
  final String? paidLabel;

  /// The word after the remaining amount, for example "left" (l10n).
  final String? leftLabel;

  /// The component override; null follows [HiddenAmountsScope].
  final bool? hidden;

  /// The arc data colour (DESIGN 7.2).
  final ChartMark mark;

  /// Draws the centre icon in the arc colour, so the glyph and the ring read as
  /// one mark (X30 By category, owner request 23 Nov 2026).
  final bool iconUsesMark;

  final RingMeterVariant variant;

  final double size;

  /// The size at which `size.ringStroke` (7 pt) is drawn. A smaller ring keeps
  /// the stroke in proportion.
  static const double _strokeSize = 76;

  double get _stroke => SizeTokens.ringStroke * size / _strokeSize;

  bool _isHidden(BuildContext context) =>
      HiddenAmountsScope.resolve(context, hidden);

  @override
  Widget build(BuildContext context) {
    final hiddenNow = _isHidden(context);
    final tokens = context.tokens;
    final colours = ChartColours.of(context, ChartTone.onCard);
    final spent = chartAmountText(value, hidden: hiddenNow);
    final limitText = chartAmountText(limit, hidden: hiddenNow);
    final remaining = limit - value;
    final paid = value.compareTo(limit) >= 0;
    final status = paid
        ? (paidLabel ?? '')
        : leftLabel == null
            ? ''
            : '${chartAmountText(remaining, hidden: hiddenNow)} $leftLabel';
    final spoken = <String>[
      name,
      spent,
      limitText,
      if (status.isNotEmpty) status,
    ].join(', ');

    final ring = SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: RingMeterPainter(
          share: _share(value, limit),
          fixed: fixed,
          todayShare: todayShare,
          track: colours.chrome.track,
          mark: colours.mark(mark),
          tick: tokens.dataNeutralFill,
          stroke: _stroke,
        ),
        child: icon == null
            ? const SizedBox.shrink()
            : Center(
                child: AppIcon(
                  data: icon!,
                  size: variant == RingMeterVariant.card
                      ? SizeTokens.iconS
                      : SizeTokens.iconM,
                  color:
                      iconUsesMark ? colours.mark(mark) : tokens.iconSecondary,
                ),
              ),
      ),
    );

    return Semantics(
      label: spoken,
      container: true,
      child: ExcludeSemantics(
        child: variant == RingMeterVariant.card
            ? _card(tokens, ring, spent, status)
            : _plain(tokens, ring, spent, status),
      ),
    );
  }

  Widget _plain(
    ContourTokens tokens,
    Widget ring,
    String spent,
    String status,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ring,
        const VSpace(Space.xs),
        Text(
          name,
          style: AppText.captionStrong.copyWith(color: tokens.textPrimary),
        ),
        if (spent.isNotEmpty)
          Text(
            spent,
            style: AppText.numberXS.copyWith(color: tokens.textPrimary),
          ),
        if (status.isNotEmpty)
          Text(
            status,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          ),
      ],
    );
  }

  /// The card variant: a tile with centred text, the track circle and the
  /// progress arc, and a larger type scale (X30 By category).
  Widget _card(
    ContourTokens tokens,
    Widget ring,
    String spent,
    String status,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xxs,
        vertical: Space.s,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceTile,
        borderRadius: const BorderRadius.all(Radius.circular(RadiusTokens.m)),
        border: Border.all(color: tokens.borderChip),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          ring,
          const VSpace(Space.xs),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyStrong.copyWith(color: tokens.textSecondary),
          ),
          if (spent.isNotEmpty)
            Text(
              spent,
              textAlign: TextAlign.center,
              style: AppText.numberXS.copyWith(color: tokens.textPrimary),
            ),
          if (status.isNotEmpty)
            Text(
              status,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppText.bodyS.copyWith(color: tokens.textSecondary),
            ),
        ],
      ),
    );
  }

  static double _share(Money value, Money limit) {
    if (limit.minor <= 0) {
      return value.minor > 0 ? 1 : 0;
    }
    return (value.minor / limit.minor).clamp(0.0, 1.0);
  }
}

/// DESIGN 7.2: a grid of rings is one chart with one label and one table.
class RingMeterGrid extends StatelessWidget {
  const RingMeterGrid({
    required this.title,
    required this.period,
    required this.meters,
    required this.columns,
    this.paidLabel,
    this.leftLabel,
    this.emptyLabel,
    this.hidden,
    this.maxColumns = 3,
    super.key,
  });

  final String title;
  final String period;
  final List<RingMeter> meters;
  final List<String> columns;
  final String? paidLabel;
  final String? leftLabel;
  final String? emptyLabel;
  final bool? hidden;

  /// Rings per row. Three is the X30 By category grid; large text drops to two
  /// so each name keeps its full width.
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    final hiddenNow = HiddenAmountsScope.resolve(context, hidden);
    final rows = <List<String>>[
      for (final meter in meters)
        <String>[
          meter.name,
          chartAmountText(meter.value, hidden: hiddenNow),
          chartAmountText(meter.limit, hidden: hiddenNow),
          if (meter.value.compareTo(meter.limit) >= 0)
            paidLabel ?? ''
          else if (meter.limit.minor > meter.value.minor)
            chartAmountText(meter.limit - meter.value, hidden: hiddenNow),
        ],
    ];
    final label = <String>[
      title,
      period,
      if (meters.isEmpty)
        (emptyLabel ?? '')
      else
        for (final meter in meters)
          '${meter.name} ${chartAmountText(meter.value, hidden: hiddenNow)} '
              'of ${chartAmountText(meter.limit, hidden: hiddenNow)}',
    ].where((part) => part.isNotEmpty).join('. ');

    return ChartFrame(
      label: label,
      emptyLabel: emptyLabel,
      table: ChartTable(columns: columns, rows: rows),
      chart: meters.isEmpty
          ? Text(
              emptyLabel ?? '',
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            )
          : _grid(context, hiddenNow),
    );
  }

  /// A fixed-column grid. Every row shares the card width, so the rings keep
  /// one size and line up across rows (owner request 23 Nov 2026).
  Widget _grid(BuildContext context, bool hiddenNow) {
    final largeText = MediaQuery.textScalerOf(context).scale(13) >= 13 * 1.3;
    // At large text one ring keeps its full width, so a long category name
    // never breaks mid-word.
    final columns = largeText ? 1 : maxColumns;
    final card = meters.any(
      (meter) => meter.variant == RingMeterVariant.card,
    );
    // Equal gaps in both directions, as the owner asked for the card grid.
    final gap = card ? Space.m : Space.l;
    final rows = <Widget>[];
    for (var start = 0; start < meters.length; start += columns) {
      final cells = <Widget>[];
      for (var offset = 0; offset < columns; offset += 1) {
        if (offset > 0) {
          cells.add(HSpace(gap));
        }
        final index = start + offset;
        cells.add(
          Expanded(
            child: index < meters.length
                ? RingMeter(
                    name: meters[index].name,
                    value: meters[index].value,
                    limit: meters[index].limit,
                    icon: meters[index].icon,
                    fixed: meters[index].fixed,
                    todayShare: meters[index].todayShare,
                    paidLabel: paidLabel,
                    leftLabel: leftLabel,
                    hidden: hiddenNow,
                    mark: meters[index].mark,
                    iconUsesMark: meters[index].iconUsesMark,
                    variant: meters[index].variant,
                    size: meters[index].size,
                  )
                : const SizedBox.shrink(),
          ),
        );
      }
      final row = Row(
        crossAxisAlignment:
            card ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: cells,
      );
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: rows.isEmpty ? 0 : gap),
          child: card ? IntrinsicHeight(child: row) : row,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Paints one ring. Only this folder may use `double` coordinates.
class RingMeterPainter extends CustomPainter {
  const RingMeterPainter({
    required this.share,
    required this.fixed,
    required this.todayShare,
    required this.track,
    required this.mark,
    required this.tick,
    this.stroke = SizeTokens.ringStroke,
  });

  final double share;
  final bool fixed;
  final double? todayShare;
  final Color track;
  final Color mark;
  final Color tick;

  /// The arc stroke. Scales with the ring size.
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    if (radius <= 0) {
      return;
    }
    final centre = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;
    canvas.drawCircle(centre, radius, trackPaint);

    final arcPaint = Paint()
      ..color = mark
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    const start = -math.pi / 2;
    final sweep = math.pi * 2 * share;
    if (sweep > 0) {
      if (fixed) {
        _dashedArc(canvas, rect, start, sweep, arcPaint);
      } else {
        canvas.drawArc(rect, start, sweep, false, arcPaint);
      }
    }

    final today = todayShare;
    if (today != null) {
      final angle = start + math.pi * 2 * today.clamp(0.0, 1.0);
      final inner =
          centre + Offset(math.cos(angle), math.sin(angle)) * (radius - stroke);
      final outer =
          centre + Offset(math.cos(angle), math.sin(angle)) * (radius + stroke);
      final tickPaint = Paint()
        ..color = tick
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  void _dashedArc(
    Canvas canvas,
    Rect rect,
    double start,
    double sweep,
    Paint paint,
  ) {
    const dash = 0.10;
    const gap = 0.06;
    var angle = start;
    final end = start + sweep;
    while (angle < end) {
      final step = math.min(dash, end - angle);
      canvas.drawArc(rect, angle, step, false, paint);
      angle += step + gap;
    }
  }

  @override
  bool shouldRepaint(RingMeterPainter oldDelegate) =>
      oldDelegate.share != share ||
      oldDelegate.fixed != fixed ||
      oldDelegate.todayShare != todayShare ||
      oldDelegate.track != track ||
      oldDelegate.mark != mark ||
      oldDelegate.tick != tick ||
      oldDelegate.stroke != stroke;
}
