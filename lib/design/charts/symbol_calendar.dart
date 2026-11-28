// DESIGN 6.7: `SymbolCalendar` — a continuous day grid with one flow glyph
// per event, today outlined, month marks on the first day of a month.
//
// A day with events is a button that opens the Day sheet. Amounts stay out of
// the cells: they live in the spoken label and the list below the grid.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/dates.dart';
import '../../domain/periods/period_math.dart';
import '../../l10n/generated/app_localizations.dart';
import '../components/interaction/app_interaction.dart';
import '../format/date_text.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';
import 'chart_tone.dart';

/// The flow group of one calendar glyph (DESIGN 6.7).
enum CalendarMark { income, investing, spending }

/// One entry on a day.
class CalendarEntry {
  const CalendarEntry({required this.date, required this.mark});

  final LocalDate date;
  final CalendarMark mark;
}

/// A day grid from [first] to [last], Monday first.
class SymbolCalendar extends StatelessWidget {
  const SymbolCalendar({
    required this.first,
    required this.last,
    required this.today,
    required this.entries,
    this.onDay,
    this.spokenLabel,
    this.maxGlyphs = 3,
    super.key,
  });

  final LocalDate first;
  final LocalDate last;
  final LocalDate today;
  final List<CalendarEntry> entries;

  /// Opens the Day sheet for a day with at least one entry.
  final ValueChanged<LocalDate>? onDay;

  /// The spoken name of a day with [count] entries. Null keeps the default.
  final String Function(LocalDate date, int count)? spokenLabel;
  final int maxGlyphs;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l = AppLocalizations.of(context);
    final colours = ChartColours.of(context, ChartTone.onCard);
    final cellHeight =
        MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 96.0 : 72.0;
    final byDay = <String, List<CalendarMark>>{};
    for (final entry in entries) {
      byDay
          .putIfAbsent(entry.date.toString(), () => <CalendarMark>[])
          .add(entry.mark);
    }
    final days = <LocalDate>[];
    var cursor = first;
    while (cursor.compareTo(last) <= 0) {
      days.add(cursor);
      cursor = addDays(cursor, 1);
    }
    final leading = DateTime(first.year, first.month, first.day).weekday - 1;
    final cells = <LocalDate?>[
      for (var i = 0; i < leading; i++) null,
      ...days,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (var weekday = 0; weekday < 7; weekday++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: Text(
                    formatWeekdayShort(addDays(_mondayOf(first), weekday))
                        .toUpperCase(),
                    style: AppText.labelCaps.copyWith(
                      color: tokens.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: _cell(
                    context,
                    l,
                    colours,
                    cells[row * 7 + column],
                    byDay,
                    cellHeight,
                  ),
                ),
            ],
          ),
        const VSpace(Space.s),
        Wrap(
          spacing: Space.m,
          runSpacing: Space.xxs,
          children: <Widget>[
            _legend(
              context,
              colours.mark(ChartMark.moneyIn),
              l.calendarLegendIncome,
              CalendarMark.income,
            ),
            _legend(
              context,
              colours.mark(ChartMark.invested),
              l.calendarLegendInvesting,
              CalendarMark.investing,
            ),
            _legend(
              context,
              colours.mark(ChartMark.spending),
              l.calendarLegendSpending,
              CalendarMark.spending,
            ),
          ],
        ),
      ],
    );
  }

  /// The Monday on or before [first], for the weekday labels.
  static LocalDate _mondayOf(LocalDate first) {
    final weekday = DateTime(first.year, first.month, first.day).weekday;
    return addDays(first, -(weekday - 1));
  }

  Widget _cell(
    BuildContext context,
    AppLocalizations l,
    ChartColours colours,
    LocalDate? date,
    Map<String, List<CalendarMark>> byDay,
    double cellHeight,
  ) {
    if (date == null) {
      return SizedBox(height: cellHeight);
    }
    final tokens = context.tokens;
    final marks = byDay[date.toString()] ?? const <CalendarMark>[];
    final isToday = date == today;
    final isPast = date.compareTo(today) < 0;
    final showMonth = date.day == 1 || date == first;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (showMonth)
          Text(
            formatMonthShort(date).toUpperCase(),
            style: AppText.labelCaps.copyWith(color: tokens.textSecondary),
            maxLines: 1,
          ),
        Text(
          '${date.day}',
          style: AppText.bodyS.copyWith(
            color: isPast ? tokens.textSecondary : tokens.textPrimary,
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (final mark in marks.take(maxGlyphs))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _glyph(
                    mark,
                    colours.mark(
                      switch (mark) {
                        CalendarMark.income => ChartMark.moneyIn,
                        CalendarMark.investing => ChartMark.invested,
                        CalendarMark.spending => ChartMark.spending,
                      },
                    ),
                  ),
                ),
              if (marks.length > maxGlyphs)
                Text(
                  '+${marks.length - maxGlyphs}',
                  style: AppText.labelCaps.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final cell = Container(
      height: cellHeight,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: marks.isEmpty ? null : tokens.surfaceTile,
        borderRadius: BorderRadius.circular(RadiusTokens.m),
        border:
            isToday ? Border.all(color: tokens.textPrimary, width: 1) : null,
      ),
      child: Center(child: content),
    );
    final label = spokenLabel?.call(date, marks.length) ??
        (marks.isEmpty
            ? formatDate(date, DateStyle.monthYear)
            : l.calendarSpoken(
                marks.length,
                formatDate(date, DateStyle.monthYear),
              ));
    if (marks.isEmpty || onDay == null) {
      return Semantics(label: label, excludeSemantics: true, child: cell);
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AppInteraction(
        onActivated: () => onDay!(date),
        borderRadius: BorderRadius.circular(RadiusTokens.m),
        child: cell,
      ),
    );
  }

  Widget _glyph(CalendarMark mark, Color colour) {
    return SizedBox(
      width: 6,
      height: 6,
      child: CustomPaint(painter: _GlyphPainter(mark: mark, colour: colour)),
    );
  }

  Widget _legend(
    BuildContext context,
    Color colour,
    String name,
    CalendarMark mark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _legendGlyph(colour, mark),
        const HSpace(Space.xs),
        Text(
          name,
          style: AppText.caption.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _legendGlyph(Color colour, CalendarMark mark) {
    return SizedBox(
      width: 6,
      height: 6,
      child: CustomPaint(
        painter: _GlyphPainter(mark: mark, colour: colour),
      ),
    );
  }
}

/// A 6 pt flow glyph: a circle, a diamond or a star.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.mark, required this.colour});

  final CalendarMark mark;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colour;
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    switch (mark) {
      case CalendarMark.spending:
        canvas.drawCircle(centre, radius, paint);
      case CalendarMark.investing:
        final path = Path()
          ..moveTo(centre.dx, 0)
          ..lineTo(size.width, centre.dy)
          ..lineTo(centre.dx, size.height)
          ..lineTo(0, centre.dy)
          ..close();
        canvas.drawPath(path, paint);
      case CalendarMark.income:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final angle = (i * 36 - 90) * 3.141592653589793 / 180;
          final r = i.isEven ? radius : radius / 2.4;
          final point = Offset(
            centre.dx + r * math.cos(angle),
            centre.dy + r * math.sin(angle),
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.mark != mark || oldDelegate.colour != colour;
}
