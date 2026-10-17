import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../typography/app_text.dart';

/// DESIGN 6.7: `ScreenHeader`. TOPLINE-001: one top line. Left: an optional
/// leading control (Back or Close), then the kicker label (`label.caps`,
/// `section.text`); or SegmentTabs. Title and date line are reader headings.
/// Up to three icon buttons sit right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    this.dateLine,
    this.kicker,
    this.leading,
    this.tabs,
    this.actions = const <Widget>[],
    super.key,
  }) : assert(actions.length <= 3, 'At most three actions');

  final String title;
  final String? dateLine;

  /// The section kicker label (for example "HOME · THIS MONTH").
  final String? kicker;

  /// A Back or Close `IconButton.onPage`, if any.
  final Widget? leading;

  /// SegmentTabs; replaces the kicker when present.
  final Widget? tabs;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);

    final topLine = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading!,
          const HSpace(Space.xs),
        ],
        if (tabs != null)
          Expanded(child: tabs!)
        else if (kicker != null)
          Flexible(
            child: Text(
              kicker!.toUpperCase(),
              style: AppText.labelCaps.copyWith(color: role.text),
            ),
          )
        else
          const Spacer(),
        for (final action in actions) ...<Widget>[
          const HSpace(Space.xs),
          action,
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        topLine,
        const VSpace(Space.s),
        Text(
          title,
          style: AppText.titleScreen.copyWith(color: tokens.textPrimary),
        ),
        if (dateLine != null) ...<Widget>[
          const VSpace(Space.xxs),
          Text(
            dateLine!,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          ),
        ],
      ],
    );
  }
}
