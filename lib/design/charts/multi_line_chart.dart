// DESIGN 7.2: `AreaLineChart` multi — up to three series on one zero-based
// scale (SCREENS X40: net worth, investments, cash).
//
// A Missing point is a gap, never a zero. The legend names each series in
// words; the table holds the exact values. The caller formats every amount.
library;

import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';
import 'area_line_chart.dart';
import 'chart_frame.dart';
import 'chart_tone.dart';

/// One line of the chart.
class MultiLineSeries {
  const MultiLineSeries({
    required this.name,
    required this.mark,
    required this.points,
  });

  /// The legend name in words.
  final String name;
  final ChartMark mark;

  /// Oldest first. Every series shares the same dates.
  final List<LinePoint> points;
}

/// A line chart with up to three series, a zero-based scale and a legend.
class MultiLineChart extends StatelessWidget {
  const MultiLineChart({
    required this.label,
    required this.series,
    required this.table,
    this.emptyLabel,
    this.height = 168,
    super.key,
  });

  /// The one spoken label, built by the caller with the exact values.
  final String label;
  final List<MultiLineSeries> series;

  /// The exact rows; the first column is the date.
  final ChartTable table;
  final String? emptyLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colours = ChartColours.of(context, ChartTone.onCard);
    final hasValue = series.any(
      (MultiLineSeries line) =>
          line.points.any((LinePoint point) => point.amount != null),
    );
    if (!hasValue) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            emptyLabel ?? AppLocalizations.of(context).chartNoneRecorded,
            style: AppText.caption.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ChartFrame(
          label: label,
          table: table,
          chart: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _MultiLinePainter(
                series: <({Color colour, List<LinePoint> points})>[
                  for (final MultiLineSeries line in series)
                    (
                      colour: colours.mark(line.mark),
                      points: line.points,
                    ),
                ],
                grid: colours.chrome.grid,
              ),
            ),
          ),
        ),
        const VSpace(Space.s),
        Wrap(
          spacing: Space.m,
          runSpacing: Space.xxs,
          children: <Widget>[
            for (final MultiLineSeries line in series)
              _LegendItem(
                name: line.name,
                colour: colours.mark(line.mark),
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.name, required this.colour});

  final String name;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: Space.xxs + 2,
          height: Space.xxs + 2,
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
          ),
        ),
        const HSpace(Space.xs),
        Text(
          name,
          style: AppText.caption.copyWith(color: context.tokens.textSecondary),
        ),
      ],
    );
  }
}

class _MultiLinePainter extends CustomPainter {
  const _MultiLinePainter({required this.series, required this.grid});

  final List<({Color colour, List<LinePoint> points})> series;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    var max = 0.0;
    var count = 0;
    var hasValue = false;
    for (final line in series) {
      if (line.points.length > count) {
        count = line.points.length;
      }
      for (final point in line.points) {
        final amount = point.amount;
        if (amount == null) continue;
        final value = amount.minor.toDouble();
        if (!hasValue || value > max) {
          max = value;
          hasValue = true;
        }
      }
    }
    if (!hasValue) return;
    const padTop = 8.0;
    const padBottom = 8.0;
    final plotHeight = size.height - padTop - padBottom;
    final span = max <= 0 ? 1.0 : max;
    final stepX = count <= 1 ? 0.0 : (size.width - 8) / (count - 1);

    Offset pointAt(int index, double value) {
      final y = padTop + plotHeight - (value / span) * plotHeight;
      return Offset(4 + stepX * index, y);
    }

    // The zero baseline (one scale from $0).
    canvas.drawLine(
      Offset(0, size.height - padBottom),
      Offset(size.width, size.height - padBottom),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );

    for (final line in series) {
      final path = Path();
      var started = false;
      var index = 0;
      Offset? end;
      for (final point in line.points) {
        final amount = point.amount;
        if (amount == null) {
          started = false;
          index++;
          continue;
        }
        final offset = pointAt(index, amount.minor.toDouble());
        if (!started) {
          path.moveTo(offset.dx, offset.dy);
          started = true;
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
        end = offset;
        index++;
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line.colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (end != null) {
        canvas.drawCircle(
          end,
          GlowTokens.endDotDiameter / 2,
          Paint()..color = line.colour,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MultiLinePainter oldDelegate) => true;
}
