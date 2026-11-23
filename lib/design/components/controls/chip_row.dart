import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';
import '../surfaces/dashed_outline.dart';

/// DESIGN 6.3: a chip has one of three jobs.
enum ChipVariant {
  /// A filter with an item count.
  filter,

  /// A choice with a 12 pt data-colour dot.
  choice,

  /// An empty "all" choice with a dashed edge.
  dashed,
}

/// One chip in a [ChipRow].
final class ChipItem {
  const ChipItem({
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.variant = ChipVariant.choice,
    this.selected = false,
    this.count,
    this.dotColor,
  });

  final String label;

  /// The spoken name. It includes the count for a filter chip.
  final String semanticLabel;
  final VoidCallback? onPressed;
  final ChipVariant variant;
  final bool selected;

  /// The filter count. Shown after the label.
  final int? count;

  /// The `data.category` colour for a choice chip.
  final Color? dotColor;
}

/// DESIGN 6.3: `ChipRow`. A 44 pt, pill-shaped, horizontal scroll row.
class ChipRow extends StatelessWidget {
  const ChipRow({required this.items, super.key});

  final List<ChipItem> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (var index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0) const HSpace(Space.s),
            _Chip(item: items[index]),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.item});

  final ChipItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final enabled = item.onPressed != null;
    final selected = item.selected;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (item.variant == ChipVariant.choice && item.dotColor != null) ...[
          _Dot(color: item.dotColor!),
          const HSpace(Space.s),
        ],
        Text(
          item.label,
          maxLines: 1,
          softWrap: false,
          style: AppText.buttonS.copyWith(
            color: selected ? tokens.textOnSection : tokens.textControl,
          ),
        ),
        if (item.variant == ChipVariant.filter && item.count != null) ...[
          const HSpace(Space.xs),
          Text(
            '${item.count}',
            style: AppText.buttonS.copyWith(
              color: selected ? tokens.textOnSection : tokens.textSecondary,
            ),
          ),
        ],
      ],
    );

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.card),
      child: Center(child: content),
    );

    final Widget visual;
    if (item.variant == ChipVariant.dashed) {
      // Component painter for the dashed chip edge; DESIGN 6.3.
      // ignore: no_custom_paint
      visual = CustomPaint(
        painter: DashedOutlinePainter(
          color: enabled ? tokens.borderChip : tokens.disabled,
          radius: RadiusTokens.pill,
          strokeWidth: BorderTokens.hairline,
          dashLength: 4,
          dashGap: 4,
        ),
        child: body,
      );
    } else {
      visual = DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? null : tokens.surfaceTrack,
          gradient: selected ? role.selectedFill.toLinearGradient() : null,
          borderRadius: BorderRadius.circular(RadiusTokens.pill),
          border: Border.all(
            color: enabled ? tokens.borderChip : tokens.disabled,
          ),
        ),
        child: body,
      );
    }

    return Semantics(
      label: item.semanticLabel,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: AppInteraction(
        onActivated: item.onPressed,
        enabled: enabled,
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SizeTokens.touchMin),
          child: visual,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(RadiusTokens.xs),
      ),
      child: const SizedBox(width: Space.m, height: Space.m),
    );
  }
}
