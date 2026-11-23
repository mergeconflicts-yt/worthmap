// DESIGN 7.2: `AreaLineChart` — a preview line for a short series.
//
// Used by X10 for the last 12 month-end net worth values. It is a preview
// chart: one spoken label with the main values and no table (PREVIEW-CHART).
// A missing point is a gap, never a zero. The hidden state keeps the shape and
// masks the spoken values.
library;

import 'package:flutter/widgets.dart';

import '../../core/money.dart';
import '../../l10n/generated/app_localizations.dart';
import '../format/hidden_amounts.dart';
import '../format/money_format.dart';
import '../format/value_presentation.dart';
import '../theme/app_theme.dart';
import '../typography/app_text.dart';
import 'chart_frame.dart';
import 'chart_tone.dart';

/// One point of the line. A null [amount] is Missing and leaves a gap.
class LinePoint {
  const LinePoint({required this.label, required this.amount});

  /// The axis label, already formatted (for example "Nov" or "Oct 25").
  final String label;
  final Money? amount;
}

/// A preview line chart over [points], oldest first.
class AreaLineChart extends StatelessWidget {
  const AreaLineChart({
    required this.title,
    required this.points,
    this.emptyLabel,
    this.hidden,
    this.mark = ChartMark.neutral,
    this.height = 96,
    super.key,
  });

  final String title;
  final List<LinePoint> points;

  /// Shown when every point is Missing.
  final String? emptyLabel;
  final bool? hidden;
  final ChartMark mark;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hiddenNow = HiddenAmountsScope.resolve(context, hidden);
    final values = <Money>[
      for (final point in points)
        if (point.amount != null) point.amount!,
    ];
    if (values.isEmpty) {
      final l = AppLocalizations.of(context);
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            emptyLabel ?? l.chartNoneRecorded,
            style: AppText.caption.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
      );
    }
    final first = values.first;
    final last = values.last;
    final label = hiddenNow
        ? amountHiddenLabel
        : AppLocalizations.of(context).chartLineSpoken(
            formatMoney(first),
            formatMoney(last),
            title,
          );
    return ChartFrame(
      preview: true,
      label: label,
      chart: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(
            points: points,
            mark: ChartColours.of(context, ChartTone.onCard).mark(mark),
            grid: ChartColours.of(context, ChartTone.onCard).chrome.grid,
            axis: ChartColours.of(context, ChartTone.onCard).chrome.axis,
            fill: ChartColours.of(context, ChartTone.onCard)
                .mark(mark)
                .withValues(alpha: 0.16),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.points,
    required this.mark,
    required this.grid,
    required this.axis,
    required this.fill,
  });

  final List<LinePoint> points;
  final Color mark;
  final Color grid;
  final Color axis;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final values = <double>[];
    var min = 0.0;
    var max = 0.0;
    var hasValue = false;
    for (final point in points) {
      final amount = point.amount;
      if (amount == null) continue;
      final value = amount.minor.toDouble();
      if (!hasValue) {
        min = value;
        max = value;
        hasValue = true;
      } else {
        if (value < min) min = value;
        if (value > max) max = value;
      }
      values.add(value);
    }
    if (values.isEmpty) return;
    final range = max - min;
    final span = range == 0 ? 1.0 : range;
    const padTop = 10.0;
    const padBottom = 16.0;
    final plotHeight = size.height - padTop - padBottom;
    final stepX =
        points.length <= 1 ? 0.0 : (size.width - 8) / (points.length - 1);

    Offset pointAt(int index, double value) {
      final y = padTop + plotHeight - ((value - min) / span) * plotHeight;
      return Offset(4 + stepX * index, y);
    }

    final line = Path();
    final area = Path();
    var started = false;
    var index = 0;
    double? lastX;
    for (final point in points) {
      final amount = point.amount;
      if (amount == null) {
        started = false;
        index++;
        continue;
      }
      final offset = pointAt(index, amount.minor.toDouble());
      if (!started) {
        line.moveTo(offset.dx, offset.dy);
        area.moveTo(offset.dx, size.height - padBottom);
        area.lineTo(offset.dx, offset.dy);
        started = true;
      } else {
        line.lineTo(offset.dx, offset.dy);
        area.lineTo(offset.dx, offset.dy);
      }
      lastX = offset.dx;
      index++;
    }
    area.lineTo(lastX ?? size.width, size.height - padBottom);
    area.close();

    canvas.drawPath(
      area,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = mark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // The end dot.
    if (lastX != null) {
      final lastValue = _lastValue();
      if (lastValue != null) {
        final end = pointAt(points.length - 1, lastValue);
        canvas.drawCircle(end, 3.5, Paint()..color = mark);
      }
    }
    // The baseline.
    canvas.drawLine(
      Offset(0, size.height - padBottom),
      Offset(size.width, size.height - padBottom),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
    // The first and last axis labels.
    _label(canvas, size, points.first.label, 0, alignEnd: false);
    _label(canvas, size, points.last.label, size.width, alignEnd: true);
  }

  double? _lastValue() {
    for (var i = points.length - 1; i >= 0; i--) {
      final amount = points[i].amount;
      if (amount != null) return amount.minor.toDouble();
    }
    return null;
  }

  void _label(
    Canvas canvas,
    Size size,
    String text,
    double x, {
    required bool alignEnd,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.chartAxis.copyWith(color: axis),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final dx = alignEnd ? x - painter.width : x;
    painter.paint(canvas, Offset(dx, size.height - painter.height));
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.mark != mark;
}
