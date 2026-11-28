// DESIGN 7.2, 6.7: `GlyphTimeline` — the X10 "Next 30 days" preview.
//
// One date scale over the window, sideways scroll at 34 pt a day, 104 high.
// A white today dot opens the scale and every day carries a tick and its day
// number. Each dated item is a dot whose area follows the amount, with the
// name and the amount beside it — labels alternate above and below the line,
// so they never overlap. The track turns dashed after the next income. A
// legend in words closes the chart. It is a preview chart: one spoken label
// and no table (PREVIEW-CHART). A missing amount stays a gap, never zero.
library;

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../l10n/generated/app_localizations.dart';
import '../components/surfaces/edge_fade.dart';
import '../format/date_text.dart';
import '../format/hidden_amounts.dart';
import '../format/value_presentation.dart';
import '../motion/motion.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';
import 'chart_frame.dart';
import 'chart_tone.dart';
import 'chart_values.dart';

/// DESIGN 6.7: the scale step. 34 pt a day, so a phone width shows about
/// ten days and the rest scrolls sideways.
const double _dayWidth = 34;

/// The scale starts this far in, so the today label reads from the left edge
/// like the reference.
const double _origin = 26;

/// DESIGN 6.7 gives 104 for the scroll region. The reference anatomy — a
/// two-line label above and below the line, plus the day numbers — does not
/// fit 104; GL-TIMELINE-HEIGHT records the 118 the reference needs.
// DECISION-PENDING: GL-TIMELINE-HEIGHT.
const double _timelineHeight = 118;

/// The track line, from the left edge to the day centres.
const double _trackY = 50;

/// The top edge of the day numbers and of the below-labels.
const double _numbersTop = 64;
const double _belowTop = 80;

/// The largest item dot. The area of a dot follows its amount, with a small
/// floor so a single-figure payment stays visible.
const double _dotMax = 13;
const double _dotMin = 5;

/// One dated item on the axis.
class TimelineItem {
  const TimelineItem({
    required this.dayIndex,
    required this.dateLabel,
    required this.name,
    this.amount,
    this.mark = ChartMark.neutral,
  });

  /// The day offset inside the window, 0-based.
  final int dayIndex;

  /// The date words ("18 Oct"), used in the spoken label.
  final String dateLabel;
  final String name;

  /// Null is Missing: the amount is not known yet.
  final Money? amount;
  final ChartMark mark;
}

/// The 30-day axis with the item labels and the legend in words.
class GlyphTimeline extends StatelessWidget {
  const GlyphTimeline({
    required this.title,
    required this.windowLabel,
    required this.start,
    required this.items,
    this.days = 30,
    this.incomeDayIndex,
    this.emptyLabel,
    this.hidden,
    super.key,
  });

  final String title;

  /// The spoken window words ("13 Oct to 12 Nov").
  final String windowLabel;

  /// The first day of the window (today). The scale numbers every day from
  /// here; day 0 and the first of a month carry the month words.
  final LocalDate start;
  final List<TimelineItem> items;

  /// The window length in days.
  final int days;

  /// The day of the next income. The track draws dashed after it. Null when
  /// no income date is known: the whole track stays solid.
  final int? incomeDayIndex;
  final String? emptyLabel;
  final bool? hidden;

  @override
  Widget build(BuildContext context) {
    final hiddenNow = HiddenAmountsScope.resolve(context, hidden);
    final l = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Text(
        emptyLabel ?? l.homeTimelineEmpty,
        style: AppText.caption.copyWith(color: context.tokens.textSecondary),
      );
    }
    final colours = ChartColours.of(context, ChartTone.onCard);
    final spoken = StringBuffer('$title. $windowLabel.');
    for (final item in items) {
      spoken.write('. ${item.dateLabel} ${item.name} ');
      spoken.write(
        hiddenNow
            ? amountHiddenLabel
            : item.amount == null
                ? l.chartNoneRecorded
                : chartAmountText(item.amount!, hidden: hiddenNow),
      );
    }
    return ChartFrame(
      preview: true,
      label: spoken.toString(),
      chart: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TimelineScroll(
            // The trailing edge fades, so a day that continues past the
            // viewport reads as "more to scroll" (the reference fades the
            // last visible day).
            child: EdgeFade(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _dayWidth * days,
                  height: _timelineHeight,
                  child: _TimelineBody(
                    start: start,
                    days: days,
                    items: items,
                    incomeDayIndex: incomeDayIndex,
                    hidden: hiddenNow,
                    colours: colours,
                  ),
                ),
              ),
            ),
          ),
          const VSpace(Space.s),
          const _Legend(),
        ],
      ),
    );
  }
}

/// The scroll region: a focus ring and horizontal arrow-key scrolling
/// (DESIGN 6.7, 13.2). The chart inside is excluded from semantics by the
/// frame; the frame label is the accessible name.
class _TimelineScroll extends StatefulWidget {
  const _TimelineScroll({required this.child});

  final Widget child;

  @override
  State<_TimelineScroll> createState() => _TimelineScrollState();
}

class _TimelineScrollState extends State<_TimelineScroll> {
  final ScrollController _controller = ScrollController();
  var _focused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_controller.hasClients) {
      return KeyEventResult.ignored;
    }
    const step = _dayWidth * 3;
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => _controller.offset - step,
      LogicalKeyboardKey.arrowRight => _controller.offset + step,
      _ => null,
    };
    if (target == null) {
      return KeyEventResult.ignored;
    }
    _controller.animateTo(
      target.clamp(0.0, _controller.position.maxScrollExtent),
      duration: Motion.select,
      curve: Curves.easeOut,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Focus(
      onKeyEvent: _onKey,
      onFocusChange: (value) => setState(() => _focused = value),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          widget.child,
          if (_focused)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: tokens.focusRing,
                      width: BorderTokens.focusRing,
                    ),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(RadiusTokens.m),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The painted scale and the label widgets over it.
class _TimelineBody extends StatelessWidget {
  const _TimelineBody({
    required this.start,
    required this.days,
    required this.items,
    required this.incomeDayIndex,
    required this.hidden,
    required this.colours,
  });

  final LocalDate start;
  final int days;
  final List<TimelineItem> items;
  final int? incomeDayIndex;
  final bool hidden;
  final ChartColours colours;

  /// The gap between the top of the largest dot and the label row above it.
  static const double _labelGap = 7;

  /// The bottom edge of every above-label, from the top of the timeline.
  double get _aboveBottom => _timelineHeight - (_trackY - _dotMax - _labelGap);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l = AppLocalizations.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _AxisPainter(
              days: days,
              items: items,
              incomeDayIndex: incomeDayIndex,
              todayColour: tokens.textPrimary,
              colours: colours,
            ),
          ),
        ),
        // The today label sits over the scale start. An item on day 0 keeps
        // the below side, so the two never meet.
        Positioned(
          left: 0,
          bottom: _aboveBottom,
          child: Text(
            l.chartToday.toUpperCase(),
            style: AppText.labelCaps.copyWith(color: tokens.textPrimary),
          ),
        ),
        for (var day = 0; day < days; day++) _dayNumber(context, day),
        for (final placed in _sorted()) _label(context, placed),
      ],
    );
  }

  /// The number under every day tick. Day 0 and the first of a month carry
  /// the month words; day 0 reads from the left edge, like the reference.
  Widget _dayNumber(BuildContext context, int day) {
    final date = _shiftDate(start, day);
    final marked = day == 0 || date.day == 1;
    final text = marked
        ? '${date.day} ${formatMonthShort(date)}'.toUpperCase()
        : '${date.day}';
    final centre = _origin + _dayWidth * day;
    return Positioned(
      // A marked day reads from left of its tick, like the reference; the
      // rest centre in their day cell.
      left: marked ? centre - 20 : centre - _dayWidth / 2,
      width: marked ? null : _dayWidth,
      top: _numbersTop,
      child: Text(
        text,
        textAlign: marked ? TextAlign.start : TextAlign.center,
        style: AppText.chartAxis.copyWith(color: colours.chrome.axis),
      ),
    );
  }

  /// Items in day order. Sides alternate above and below, so same-side
  /// neighbours sit at least two days apart and centred labels never
  /// overlap. An item on day 0 always takes the below side (the today label
  /// is above it).
  List<_Placed> _sorted() {
    final sorted = List<TimelineItem>.of(items)
      ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));
    final placed = <_Placed>[];
    var above = true;
    for (final item in sorted) {
      if (item.dayIndex == 0) {
        placed.add(_Placed(item, false));
      } else {
        placed.add(_Placed(item, above));
        above = !above;
      }
    }
    return placed;
  }

  Widget _label(BuildContext context, _Placed placed) {
    final tokens = context.tokens;
    const slot = 120.0;
    final item = placed.item;
    final centre = _origin + _dayWidth * item.dayIndex;
    final left = (centre - slot / 2).clamp(0.0, _dayWidth * days - slot);
    // A due amount reads as its magnitude; the mark colour and the legend
    // carry the direction (the reference shows "$1,240", not "−$1,240").
    final amount = item.amount == null
        ? '—'
        : chartAmountText(
            Money.fromMinor(item.amount!.minor.abs(), item.amount!.currency),
            hidden: hidden,
          );
    return Positioned(
      left: left,
      width: slot,
      top: placed.above ? null : _belowTop,
      bottom: placed.above ? _aboveBottom : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.captionStrong.copyWith(color: tokens.textPrimary),
          ),
          Text(
            amount,
            maxLines: 1,
            style: AppText.captionStrong.copyWith(
              color: colours.mark(item.mark),
            ),
          ),
        ],
      ),
    );
  }
}

class _Placed {
  const _Placed(this.item, this.above);

  final TimelineItem item;

  /// True when the label sits above the line.
  final bool above;
}

/// The track, the day ticks with their numbers and the item dots. The dot
/// area follows the amount: the largest item takes the full radius and the
/// rest scale with the square root of their share, with the floor radius.
class _AxisPainter extends CustomPainter {
  const _AxisPainter({
    required this.days,
    required this.items,
    required this.incomeDayIndex,
    required this.todayColour,
    required this.colours,
  });

  final int days;
  final List<TimelineItem> items;
  final int? incomeDayIndex;
  final Color todayColour;
  final ChartColours colours;

  @override
  void paint(Canvas canvas, Size size) {
    final chrome = colours.chrome;
    final track = Paint()
      ..color = chrome.base
      ..strokeWidth = 1.5;

    // Solid to the next income, dashed after it.
    final incomeX = incomeDayIndex == null
        ? size.width
        : _x(incomeDayIndex!.clamp(0, days - 1));
    canvas.drawLine(
      const Offset(0, _trackY),
      Offset(incomeX, _trackY),
      track,
    );
    if (incomeX < size.width) {
      _dashed(
        canvas,
        Offset(incomeX, _trackY),
        Offset(size.width, _trackY),
        track,
      );
    }

    // The today dot: white, over the scale start.
    canvas.drawCircle(Offset(_x(0), _trackY), 7, Paint()..color = todayColour);

    for (var i = 0; i < days; i++) {
      final x = _x(i);
      canvas.drawLine(
        Offset(x, _trackY - 4),
        Offset(x, _trackY + 4),
        Paint()
          ..color = chrome.grid
          ..strokeWidth = 1,
      );
    }

    final maxAmount = items.fold<double>(
      0,
      (value, item) {
        final amount = item.amount;
        if (amount == null) {
          return value;
        }
        return math.max(value, amount.minor.abs().toDouble());
      },
    );
    for (final item in items) {
      final amount = item.amount;
      final share = amount == null || maxAmount == 0
          ? 0.0
          : amount.minor.abs() / maxAmount;
      final radius =
          _dotMin + (_dotMax - _dotMin) * math.sqrt(share).toDouble();
      canvas.drawCircle(
        Offset(_x(item.dayIndex.clamp(0, days - 1)), _trackY),
        radius,
        Paint()..color = colours.mark(item.mark),
      );
    }
  }

  /// The centre of [day] on the scale.
  double _x(int day) => _origin + _dayWidth * day;

  void _dashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 3.0;
    var x = from.dx;
    while (x < to.dx) {
      final end = x + dash < to.dx ? x + dash : to.dx;
      canvas.drawLine(Offset(x, from.dy), Offset(end, to.dy), paint);
      x += dash * 2;
    }
  }

  @override
  bool shouldRepaint(_AxisPainter oldDelegate) =>
      oldDelegate.items != items ||
      oldDelegate.days != days ||
      oldDelegate.incomeDayIndex != incomeDayIndex;
}

/// The date [days] after [start]. The same UTC shift as the domain helper,
/// kept local so the chart library does not depend on `lib/domain/`.
LocalDate _shiftDate(LocalDate start, int days) {
  final shifted = DateTime.utc(start.year, start.month, start.day + days);
  return LocalDate(shifted.year, shifted.month, shifted.day);
}

/// The legend in words (SCREENS X10): one glyph per flow group, then its name.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colours = ChartColours.of(context, ChartTone.onCard);
    return Wrap(
      spacing: Space.m,
      runSpacing: Space.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _item(ChartMark.spending, l.chartLegendSpending, colours),
        _item(ChartMark.investing, l.chartLegendInvesting, colours),
        _item(ChartMark.moneyIn, l.chartLegendMoneyIn, colours),
      ],
    );
  }

  Widget _item(ChartMark mark, String label, ChartColours colours) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 14,
          height: 14,
          child: CustomPaint(
            painter: _GlyphPainter(mark: mark, colour: colours.mark(mark)),
          ),
        ),
        const HSpace(Space.xxs),
        Text(
          label,
          style: AppText.caption.copyWith(color: colours.chrome.axis),
        ),
      ],
    );
  }
}

/// The flow glyphs: ● spending, ◆ investing, ★ money in.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.mark, required this.colour});

  final ChartMark mark;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.fill;
    final centre = Offset(size.width / 2, size.height / 2);
    switch (mark) {
      case ChartMark.investing:
        final r = size.width * 0.3;
        canvas.drawPath(
          Path()
            ..moveTo(centre.dx, centre.dy - r)
            ..lineTo(centre.dx + r, centre.dy)
            ..lineTo(centre.dx, centre.dy + r)
            ..lineTo(centre.dx - r, centre.dy)
            ..close(),
          paint,
        );
      case ChartMark.moneyIn:
        final r = size.width * 0.42;
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? r : r * 0.45;
          final point = Offset(
            centre.dx + radius * math.cos(angle),
            centre.dy + radius * math.sin(angle),
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      default:
        canvas.drawCircle(centre, size.width * 0.3, paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.mark != mark;
}
