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

  final double size;

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

    return Semantics(
      label: spoken,
      container: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
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
                ),
                child: icon == null
                    ? const SizedBox.shrink()
                    : Center(
                        child: AppIcon(
                          data: icon!,
                          size: SizeTokens.iconM,
                          color: tokens.iconSecondary,
                        ),
                      ),
              ),
            ),
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
        ),
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
          : Wrap(
              spacing: Space.xl,
              runSpacing: Space.l,
              children: <Widget>[
                for (final meter in meters)
                  RingMeter(
                    name: meter.name,
                    value: meter.value,
                    limit: meter.limit,
                    icon: meter.icon,
                    fixed: meter.fixed,
                    todayShare: meter.todayShare,
                    paidLabel: paidLabel,
                    leftLabel: leftLabel,
                    hidden: hiddenNow,
                    mark: meter.mark,
                    size: meter.size,
                  ),
              ],
            ),
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
  });

  final double share;
  final bool fixed;
  final double? todayShare;
  final Color track;
  final Color mark;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final radius =
        (math.min(size.width, size.height) - SizeTokens.ringStroke) / 2;
    if (radius <= 0) {
      return;
    }
    final centre = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = SizeTokens.ringStroke
      ..isAntiAlias = true;
    canvas.drawCircle(centre, radius, trackPaint);

    final arcPaint = Paint()
      ..color = mark
      ..style = PaintingStyle.stroke
      ..strokeWidth = SizeTokens.ringStroke
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
          centre + Offset(math.cos(angle), math.sin(angle)) * (radius - 7);
      final outer =
          centre + Offset(math.cos(angle), math.sin(angle)) * (radius + 7);
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
      oldDelegate.tick != tick;
}
