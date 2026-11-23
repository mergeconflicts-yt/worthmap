import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/token_types.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.3: `SegmentedControl`. A `surface.track` row of 44 pt items. The
/// selected item uses `action.selected.fill` with `text.onSection`; the other
/// items use `text.control`.
///
/// At a text scale above 1.3 the items keep their full labels in a horizontal
/// scroll instead of shrinking or truncating.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  })  : assert(segments.length > 1),
        assert(selectedIndex >= 0 && selectedIndex < segments.length);

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// The group name, for example "Type".
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final items = <Widget>[
      for (var index = 0; index < segments.length; index++)
        _Segment(
          label: segments[index],
          selected: index == selectedIndex,
          onPressed: () => onChanged(index),
          selectedFill: role.selectedFill,
          groupLabel: semanticLabel,
        ),
    ];

    // Above 1.3 the row scrolls sideways. Each segment keeps a 120 pt minimum
    // but grows with its label, so a long word is never clipped.
    final row = scale > 1.3
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final item in items)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 120),
                    child: item,
                  ),
              ],
            ),
          )
        : Row(
            children: <Widget>[
              for (final item in items) Expanded(child: item),
            ],
          );

    return Align(
      heightFactor: 1,
      child: Semantics(
        label: semanticLabel,
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surfaceTrack,
            borderRadius: BorderRadius.circular(RadiusTokens.pill),
            border: Border.all(color: tokens.borderChip),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RadiusTokens.pill),
            child: SizedBox(
              height: SizeTokens.touchMin,
              width: double.infinity,
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.selectedFill,
    required this.groupLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final GradientSpec selectedFill;
  final String groupLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      child: AppInteraction(
        onActivated: onPressed,
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: selected ? selectedFill.toLinearGradient() : null,
            borderRadius: BorderRadius.circular(RadiusTokens.pill),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.m),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: AppText.buttonS.copyWith(
                  color: selected ? tokens.textOnSection : tokens.textControl,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
