// DESIGN 7.2: `GlyphTimeline` — the X10 "Next 30 days" preview.
//
// A 30-day strip with one glyph per dated item, a legend and the next rows.
// It is a preview chart: one spoken label and no table (PREVIEW-CHART). A
// missing amount stays a gap, never zero.
library;

import 'package:flutter/widgets.dart';

import '../../core/money.dart';
import '../../l10n/generated/app_localizations.dart';
import '../format/hidden_amounts.dart';
import '../format/money_text.dart';
import '../format/value_presentation.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../typography/app_text.dart';
import 'chart_frame.dart';
import 'chart_tone.dart';

/// One dated item on the strip.
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

  /// The date words ("18 Oct").
  final String dateLabel;
  final String name;
  final Money? amount;
  final ChartMark mark;
}

/// The 30-day strip with the first rows below it.
class GlyphTimeline extends StatelessWidget {
  const GlyphTimeline({
    required this.title,
    required this.windowLabel,
    required this.items,
    this.days = 30,
    this.emptyLabel,
    this.hidden,
    super.key,
  });

  final String title;

  /// The spoken window words ("13 Oct to 12 Nov").
  final String windowLabel;
  final List<TimelineItem> items;
  final int days;
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
    return ChartFrame(
      preview: true,
      label: hiddenNow
          ? amountHiddenLabel
          : l.chartLineSpoken(
              l.homeTimelineTitle,
              windowLabel,
              '${items.length}',
            ),
      chart: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 44,
            width: double.infinity,
            child: CustomPaint(
              painter: _StripPainter(
                days: days,
                items: items,
                colours: colours,
              ),
            ),
          ),
          const VSpace(Space.s),
          for (final item in items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colours.mark(item.mark),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const HSpace(Space.xs),
                  Expanded(
                    child: Text(
                      '${item.dateLabel} · ${item.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ),
                  const HSpace(Space.s),
                  if (item.amount != null)
                    MoneyText(
                      ValueSpec.real(item.amount!),
                      style: AppText.caption,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  const _StripPainter({
    required this.days,
    required this.items,
    required this.colours,
  });

  final int days;
  final List<TimelineItem> items;
  final ChartColours colours;

  @override
  void paint(Canvas canvas, Size size) {
    final chrome = colours.chrome;
    final y = size.height * 0.55;
    final step = days <= 1 ? 0.0 : (size.width - 8) / (days - 1);
    final base = Paint()
      ..color = chrome.grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), base);
    for (var i = 0; i < days; i++) {
      final x = 4 + step * i;
      final height = i == 0 || i == days - 1 ? 10.0 : 4.0;
      canvas.drawLine(
        Offset(x, y - height / 2),
        Offset(x, y + height / 2),
        Paint()
          ..color = chrome.grid
          ..strokeWidth = 1,
      );
    }
    for (final item in items) {
      final x = 4 + step * item.dayIndex.clamp(0, days - 1);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = colours.mark(item.mark),
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter oldDelegate) =>
      oldDelegate.items != items || oldDelegate.days != days;
}
