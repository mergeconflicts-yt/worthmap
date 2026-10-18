import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../typography/app_text.dart';

/// DESIGN 6.7, SPEC W13: the titled group of widgets on a surface.
///
/// An untitled section draws its children with no header. The host passes
/// already-built placements; the section adds the title and the vertical gap.
class WidgetSection extends StatelessWidget {
  const WidgetSection({required this.children, this.title, super.key});

  /// The section title, or null for an untitled section.
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (title == null) {
      return _gapped(children);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: Space.xs),
          child: Text(
            title!,
            style: AppText.titleSection.copyWith(color: tokens.textPrimary),
          ),
        ),
        const VSpace(Space.s),
        _gapped(children),
      ],
    );
  }

  Widget _gapped(List<Widget> widgets) {
    final rows = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) {
        rows.add(const VSpace(Space.card));
      }
      rows.add(widgets[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
