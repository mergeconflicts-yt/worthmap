import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/money.dart';
import '../../l10n/generated/app_localizations.dart';
import '../format/hidden_amounts.dart';
import '../motion/motion.dart';
import '../theme/app_theme.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';
import 'chart_frame.dart';
import 'chart_tone.dart';
import 'chart_values.dart';

/// DESIGN 7.2: one period bar: a day or a month.
class PeriodBar {
  const PeriodBar({
    required this.label,
    required this.amount,
    this.current = false,
    this.incomplete = false,
  });

  /// The axis label, already formatted (for example "7" or "Oct").
  final String label;

  /// The exact value of the period. Bars of one chart share one scale.
  final Money amount;

  /// The current day or month. It uses the chart mark colour.
  final bool current;

  /// An incomplete period is hatched and named in the label.
  final bool incomplete;
}

/// DESIGN 7.2: `PeriodBarChart` — spending or money per day or month with an
/// optional average and limit line.
///
/// Bars are neutral: a past bar is white 24% (ink equivalent in Light) and the
/// current bar uses the chart mark. An incomplete period is hatched. The chart
/// never invents a zero for a missing period: a caller leaves that period out
/// and states "Missing" in the label and table.
class PeriodBarChart extends StatelessWidget {
  const PeriodBarChart({
    required this.title,
    required this.period,
    required this.bars,
    required this.columns,
    this.average,
    this.limit,
    this.incompleteLabel,
    this.emptyLabel,
    this.averageLabel,
    this.limitLabel,
    this.hidden,
    this.preview = false,
    this.tone = ChartTone.onStage,
    this.mark = ChartMark.neutral,
    this.height = 160,
    super.key,
  });

  /// What the bars are, for example "Spent" (l10n from the screen).
  final String title;

  /// The period in words, for example "1–13 Oct 2026".
  final String period;

  final List<PeriodBar> bars;

  /// Table columns: name and amount (and more if the caller adds them).
  final List<String> columns;

  final Money? average;
  final Money? limit;

  /// The word for an incomplete period, for example "October is not closed
  /// yet" (l10n from the screen).
  final String? incompleteLabel;

  /// The phrase for an empty data set, for example "None recorded".
  final String? emptyLabel;

  /// The table row name for the average; "Average" by default.
  final String? averageLabel;

  /// The table row name for the limit; "Limit" by default.
  final String? limitLabel;

  /// The component override; null follows [HiddenAmountsScope].
  final bool? hidden;

  /// PREVIEW-CHART: no table, the label keeps the exact values.
  final bool preview;

  final ChartTone tone;
  final ChartMark mark;
  final double height;

  bool _isHidden(BuildContext context) =>
      HiddenAmountsScope.resolve(context, hidden);

  @override
  Widget build(BuildContext context) {
    final hiddenNow = _isHidden(context);
    final colours = ChartColours.of(context, tone);
    final tokens = context.tokens;
    final averageLabelText = averageLabel ?? 'Average';
    final averageShort = AppLocalizations.of(context).chartAverageShort;
    final textScale =
        (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(1.0, 2.0);
    final limitLabelText = limitLabel ?? 'Limit';

    final rows = <List<String>>[
      for (final bar in bars)
        <String>[
          bar.incomplete && incompleteLabel != null
              ? '${bar.label} · $incompleteLabel'
              : bar.label,
          chartAmountText(bar.amount, hidden: hiddenNow),
        ],
      if (average != null)
        <String>[
          averageLabelText,
          chartAmountText(average!, hidden: hiddenNow),
        ],
      if (limit != null)
        <String>[limitLabelText, chartAmountText(limit!, hidden: hiddenNow)],
    ];

    final labelParts = <String>[
      title,
      period,
      if (bars.isEmpty)
        (emptyLabel ?? '')
      else
        for (final bar in bars)
          '${bar.label} ${chartAmountText(bar.amount, hidden: hiddenNow)}',
      if (average != null)
        '$averageLabelText ${chartAmountText(average!, hidden: hiddenNow)}',
      if (limit != null)
        '$limitLabelText ${chartAmountText(limit!, hidden: hiddenNow)}',
      if (incompleteLabel != null)
        for (final bar in bars)
          if (bar.incomplete) '${bar.label} $incompleteLabel',
    ];
    final label = labelParts.where((part) => part.isNotEmpty).join('. ');

    return ChartFrame(
      label: label,
      emptyLabel: emptyLabel,
      preview: preview,
      table: preview ? null : ChartTable(columns: columns, rows: rows),
      chart: SizedBox(
        height: preview ? height : height * textScale,
        child: bars.isEmpty
            ? Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyLabel ?? '',
                  style: AppText.caption.copyWith(color: tokens.textSecondary),
                ),
              )
            : ChartMotion(
                duration: Motion.drawBar,
                builder: (BuildContext context, double progress) => CustomPaint(
                  painter: PeriodBarPainter(
                    bars: bars,
                    average: average,
                    limit: limit,
                    averageLabel: average == null
                        ? null
                        : '$averageShort ${chartShortAmount(average!)}',
                    limitLabel: null,
                    colours: colours,
                    mark: colours.mark(mark),
                    axisStyle:
                        AppText.chartAxis.copyWith(color: colours.chrome.axis),
                    tickStyle:
                        AppText.chartAxis.copyWith(color: colours.chrome.axis),
                    hidden: hiddenNow,
                    progress: progress,
                    textScale: textScale,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
      ),
    );
  }
}

/// Paints [PeriodBarChart]. Only this folder may use `double` coordinates.
class PeriodBarPainter extends CustomPainter {
  const PeriodBarPainter({
    required this.bars,
    required this.average,
    required this.limit,
    required this.averageLabel,
    required this.limitLabel,
    required this.colours,
    required this.mark,
    required this.axisStyle,
    required this.tickStyle,
    required this.hidden,
    required this.progress,
    required this.textScale,
  });

  final List<PeriodBar> bars;
  final Money? average;
  final Money? limit;
  final String? averageLabel;
  final String? limitLabel;
  final ChartColours colours;
  final Color mark;
  final TextStyle axisStyle;
  final TextStyle tickStyle;
  final bool hidden;
  final double progress;
  final double textScale;

  static const double _bottomAxis = 18;
  static const double _valueGutter = 40;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final gutter = hidden ? 0.0 : _valueGutter * textScale;
    final plotRight = size.width - gutter;
    final plotHeight = size.height - _bottomAxis * textScale;
    if (plotRight <= 0 || plotHeight <= 0) {
      return;
    }

    var maxMinor = 1;
    for (final bar in bars) {
      maxMinor = math.max(maxMinor, bar.amount.minor.abs());
    }
    if (average != null) {
      maxMinor = math.max(maxMinor, average!.minor.abs());
    }
    if (limit != null) {
      maxMinor = math.max(maxMinor, limit!.minor.abs());
    }

    double yFor(int minor) =>
        plotHeight - (minor.abs() / maxMinor) * plotHeight;

    _paintGrid(canvas, plotRight, plotHeight, gutter, maxMinor);

    if (bars.isEmpty) {
      return;
    }

    final slot = plotRight / bars.length;
    final barWidth = slot * 0.64;
    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final left = slot * i + (slot - barWidth) / 2;
      final top = yFor(bar.amount.minor);
      final scaledTop = plotHeight - (plotHeight - top) * progress;
      final rect = Rect.fromLTRB(left, scaledTop, left + barWidth, plotHeight);
      final paint = Paint()
        ..color = bar.current ? mark : colours.chrome.pastBar
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final rounded = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(RadiusTokens.xs),
        topRight: const Radius.circular(RadiusTokens.xs),
      );
      canvas.drawRRect(rounded, paint);
      if (bar.incomplete) {
        _paintHatch(canvas, rect);
      }
    }

    if (average != null) {
      _paintReference(
        canvas,
        plotRight,
        yFor(average!.minor),
        averageLabel,
      );
    }
    if (limit != null) {
      _paintReference(canvas, plotRight, yFor(limit!.minor), limitLabel);
    }

    _paintDateLabels(canvas, slot, barWidth, plotHeight);
  }

  void _paintGrid(
    Canvas canvas,
    double plotRight,
    double plotHeight,
    double gutter,
    int maxMinor,
  ) {
    final gridPaint = Paint()
      ..color = colours.chrome.grid
      ..strokeWidth = 1;
    final basePaint = Paint()
      ..color = colours.chrome.base
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = plotHeight - (plotHeight / 3) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(plotRight, y),
        i == 0 ? basePaint : gridPaint,
      );
      if (!hidden && bars.isNotEmpty && (textScale < 1.3 || i == 0 || i == 3)) {
        final value = maxMinor * i ~/ 3;
        final label = chartShortAmount(
          Money.fromMinor(
            value,
            bars.isEmpty ? _fallbackCurrency : bars.first.amount.currency,
          ),
        );
        _paintText(
          canvas,
          label,
          Offset(plotRight + 4, y - 6),
          tickStyle,
          maxWidth: gutter - 4,
        );
      }
    }
  }

  static const Currency _fallbackCurrency = Currency.usd;

  void _paintReference(
    Canvas canvas,
    double plotRight,
    double y,
    String? label,
  ) {
    final paint = Paint()
      ..color = colours.chrome.reference
      ..strokeWidth = 1;
    const dash = 3.0;
    for (var x = 0.0; x < plotRight; x += dash * 2) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, plotRight), y),
        paint,
      );
    }
    if (!hidden && label != null) {
      _paintText(
        canvas,
        label,
        Offset(0, math.max(0, y - 14)),
        tickStyle,
        maxWidth: plotRight,
      );
    }
  }

  void _paintDateLabels(
    Canvas canvas,
    double slot,
    double barWidth,
    double plotHeight,
  ) {
    final candidates = <int>[];
    if (bars.isNotEmpty) {
      candidates.add(0);
      if (textScale < 1.3) {
        final current = bars.indexWhere((bar) => bar.current);
        if (current >= 0) {
          candidates.add(current);
        }
      }
      candidates.add(bars.length - 1);
    }
    candidates.sort();
    final painted = <String>[];
    var lastRight = double.negativeInfinity;
    for (final index in candidates) {
      final painter = TextPainter(
        text: TextSpan(text: bars[index].label, style: axisStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      var left = slot * index + (slot - painter.width) / 2;
      left = left.clamp(0.0, math.max(0.0, slot * bars.length - painter.width));
      if (left < lastRight + 4 && painted.isNotEmpty) {
        painter.dispose();
        continue;
      }
      painter.paint(canvas, Offset(left, plotHeight + 4));
      lastRight = left + painter.width;
      painted.add(bars[index].label);
      painter.dispose();
    }
  }

  void _paintHatch(Canvas canvas, Rect rect) {
    canvas.save();
    canvas.clipRect(rect);
    final paint = Paint()
      ..color = colours.chrome.hatch
      ..strokeWidth = 1;
    for (var x = rect.left - rect.height; x < rect.right; x += 4) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
    canvas.restore();
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required double maxWidth,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(alignRight ? offset.dx - painter.width : offset.dx, offset.dy),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(PeriodBarPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.average != average ||
      oldDelegate.limit != limit ||
      oldDelegate.hidden != hidden ||
      oldDelegate.progress != progress ||
      oldDelegate.textScale != textScale ||
      oldDelegate.mark != mark ||
      oldDelegate.colours != colours;
}
