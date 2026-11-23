import 'package:flutter/widgets.dart';

import '../../core/money.dart';
import '../format/hidden_amounts.dart';
import '../theme/app_theme.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';
import 'chart_frame.dart';
import 'chart_tone.dart';
import 'chart_values.dart';

/// DESIGN 7.2 (X34): one payment mark on a billing-day strip.
class BillingMark {
  const BillingMark({
    required this.day,
    required this.name,
    this.amount,
    this.paid = false,
  });

  /// The day of the month, 1-based.
  final int day;
  final String name;
  final Money? amount;

  /// A paid mark is dimmed in `text.secondary`, not by opacity.
  final bool paid;
}

/// DESIGN 7.2: `BillingStrip` — days 1 to 31 of a month, the today marker and
/// one dot per payment.
///
/// The track is brighter up to today. A paid mark is dimmed. The strip carries
/// no amount text; the exact values are in the label and the table.
class BillingStrip extends StatelessWidget {
  const BillingStrip({
    required this.title,
    required this.period,
    required this.daysInMonth,
    required this.today,
    required this.marks,
    required this.columns,
    this.todayLabel,
    this.paidLabel,
    this.dueLabel,
    this.emptyLabel,
    this.hidden,
    this.tone = ChartTone.onStage,
    this.height = 64,
    super.key,
  });

  final String title;
  final String period;

  /// 28 to 31.
  final int daysInMonth;

  /// The day of the month, 1-based.
  final int today;

  final List<BillingMark> marks;

  /// Table columns: date, payment, amount, state.
  final List<String> columns;

  /// The word "Today" in the label.
  final String? todayLabel;

  /// The state word for a paid mark ("Paid") and an unpaid mark.
  final String? paidLabel;
  final String? dueLabel;

  final String? emptyLabel;
  final bool? hidden;
  final ChartTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hiddenNow = HiddenAmountsScope.resolve(context, hidden);
    final colours = ChartColours.of(context, tone);
    final tokens = context.tokens;

    final rows = <List<String>>[
      for (final mark in marks)
        <String>[
          mark.day.toString(),
          mark.name,
          mark.amount == null
              ? ''
              : chartAmountText(mark.amount!, hidden: hiddenNow),
          mark.paid ? (paidLabel ?? '') : (dueLabel ?? ''),
        ],
    ];
    final label = <String>[
      title,
      period,
      if (todayLabel != null) '$todayLabel $today',
      if (marks.isEmpty)
        (emptyLabel ?? '')
      else
        for (final mark in marks)
          <String>[
            mark.name,
            mark.day.toString(),
            if (mark.amount != null)
              chartAmountText(mark.amount!, hidden: hiddenNow),
            mark.paid ? (paidLabel ?? '') : (dueLabel ?? ''),
          ].where((part) => part.isNotEmpty).join(' '),
    ].where((part) => part.isNotEmpty).join('. ');

    final textScale =
        (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(1.0, 2.0);
    return ChartFrame(
      label: label,
      emptyLabel: emptyLabel,
      table: ChartTable(columns: columns, rows: rows),
      chart: SizedBox(
        height: height * (textScale >= 1.3 ? 1.4 : 1),
        child: CustomPaint(
          painter: BillingStripPainter(
            daysInMonth: daysInMonth,
            today: today,
            marks: marks,
            track: colours.chrome.track,
            elapsed: colours.chrome.base,
            paid: tokens.textSecondary,
            pending: colours.mark(ChartMark.neutral),
            todayMark: tokens.dataNeutralFill,
            axis: colours.chrome.axis,
            axisStyle: AppText.chartAxis.copyWith(color: colours.chrome.axis),
            startLabel: '1',
            endLabel: daysInMonth.toString(),
            todayText: todayLabel,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Paints the billing-day strip. Only this folder may use `double`
/// coordinates.
class BillingStripPainter extends CustomPainter {
  const BillingStripPainter({
    required this.daysInMonth,
    required this.today,
    required this.marks,
    required this.track,
    required this.elapsed,
    required this.paid,
    required this.pending,
    required this.todayMark,
    required this.axis,
    required this.axisStyle,
    required this.startLabel,
    required this.endLabel,
    required this.todayText,
  });

  final int daysInMonth;
  final int today;
  final List<BillingMark> marks;
  final Color track;
  final Color elapsed;
  final Color paid;
  final Color pending;
  final Color todayMark;
  final Color axis;
  final TextStyle axisStyle;
  final String startLabel;
  final String endLabel;
  final String? todayText;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || daysInMonth <= 0) {
      return;
    }
    const labelHeight = 16.0;
    final lineY = (size.height - labelHeight) * 0.55;
    final span = size.width - SizeTokens.iconS;
    double xFor(int day) =>
        SizeTokens.iconS / 2 + span * ((day - 1) / (daysInMonth - 1));

    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(xFor(1), lineY),
      Offset(xFor(daysInMonth), lineY),
      trackPaint,
    );

    final elapsedPaint = Paint()
      ..color = elapsed
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(xFor(1), lineY),
      Offset(xFor(today.clamp(1, daysInMonth)), lineY),
      elapsedPaint,
    );

    for (final mark in marks) {
      final x = xFor(mark.day.clamp(1, daysInMonth));
      final paint = Paint()
        ..color = mark.paid ? paid : pending
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, lineY), 3, paint);
    }

    final todayX = xFor(today.clamp(1, daysInMonth));
    final todayPaint = Paint()..color = todayMark;
    canvas.drawCircle(Offset(todayX, lineY), 2.5, todayPaint);

    _label(canvas, startLabel, Offset(0, size.height - labelHeight));
    final endPainter = _painter(endLabel);
    endPainter.paint(
      canvas,
      Offset(size.width - endPainter.width, size.height - labelHeight),
    );
    endPainter.dispose();

    if (todayText != null) {
      final painter = _painter('$todayText ${today.clamp(1, daysInMonth)}');
      final left =
          (todayX - painter.width / 2).clamp(0.0, size.width - painter.width);
      painter.paint(canvas, Offset(left, 0));
      painter.dispose();
    }
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final painter = _painter(text);
    painter.paint(canvas, offset);
    painter.dispose();
  }

  TextPainter _painter(String text) => TextPainter(
        text: TextSpan(text: text, style: axisStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

  @override
  bool shouldRepaint(BillingStripPainter oldDelegate) =>
      oldDelegate.daysInMonth != daysInMonth ||
      oldDelegate.today != today ||
      oldDelegate.marks != marks ||
      oldDelegate.track != track ||
      oldDelegate.pending != pending ||
      oldDelegate.axis != axis;
}
