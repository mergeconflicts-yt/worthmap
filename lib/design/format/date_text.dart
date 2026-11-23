import 'package:flutter/widgets.dart';

import '../../core/dates.dart';

/// DESIGN 4: how much of a date shows.
enum DateStyle {
  /// "22 Nov" (a row or a chip).
  short,

  /// "22 Nov 2026" (a form field or a card line).
  monthYear,

  /// "22 November 2026" (a sentence).
  long,
}

/// DESIGN 4: one calendar date in words.
///
/// A payment date is a local calendar date, never a time (SPEC 4.1). The month
/// names are English in v1 (SPEC 7).
class DateText extends StatelessWidget {
  const DateText(
    this.date, {
    this.style = DateStyle.monthYear,
    this.semanticLabel,
    this.styleText,
    super.key,
  });

  final LocalDate date;
  final DateStyle style;

  /// The spoken form when it differs from the visible text.
  final String? semanticLabel;

  /// The text style; `AppText.body` by default.
  final TextStyle? styleText;

  @override
  Widget build(BuildContext context) => Text(
        formatDate(date, style),
        style: styleText,
        semanticsLabel: semanticLabel,
      );
}

const List<String> _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _longMonths = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// DESIGN 4: formats one [LocalDate] for the visible text and the spoken name.
String formatDate(LocalDate date, DateStyle style) {
  final month = style == DateStyle.long
      ? _longMonths[date.month - 1]
      : _shortMonths[date.month - 1];
  return switch (style) {
    DateStyle.short => '${date.day} $month',
    DateStyle.monthYear => '${date.day} $month ${date.year}',
    DateStyle.long => '${date.day} $month ${date.year}',
  };
}

/// DESIGN 4: the short month name of [date], for a monthly chart axis.
String formatMonthShort(LocalDate date) => _shortMonths[date.month - 1];

/// DESIGN 4: an inclusive date range, for example "1–13 Oct 2026".
///
/// One month: "1–13 Oct 2026". Two months in one year: "25 Sep – 24 Oct 2026".
/// Two years: "20 Dec 2025 – 5 Jan 2026".
String formatDateRange(LocalDate start, LocalDate end) {
  if (start == end) {
    return formatDate(start, DateStyle.monthYear);
  }
  if (start.year == end.year && start.month == end.month) {
    return '${start.day}–${formatDate(end, DateStyle.monthYear)}';
  }
  if (start.year == end.year) {
    return '${start.day} ${formatMonthShort(start)} – '
        '${formatDate(end, DateStyle.monthYear)}';
  }
  return '${formatDate(start, DateStyle.monthYear)} – '
      '${formatDate(end, DateStyle.monthYear)}';
}

/// DESIGN 4: the long month name of [date], for a screen kicker.
String formatMonthLong(LocalDate date) => _longMonths[date.month - 1];

/// DESIGN 4: the short weekday name of [date], for a day group title.
String formatWeekdayShort(LocalDate date) {
  const names = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[DateTime.utc(date.year, date.month, date.day).weekday - 1];
}
