import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';

/// DESIGN 6.7: `CapsuleMeter` (fixed mode for the Get started meter).
/// Track `size.capsule`, `radius.pill`, `surface.track`, 1 px inner edge.
/// Solid fill in the section colour to value ÷ limit (capped). No glow, no
/// gradient. The spoken label carries the exact count; the fill is never
/// the only signal (AGENTS 2.2, 6.9).
///
/// The fill uses integer flex weights only: no `double` exists in this
/// component, so the bounded-coordinate rule (AGENTS 12) needs no chart
/// folder exception.
class CapsuleMeter extends StatelessWidget {
  const CapsuleMeter({
    required this.value,
    required this.limit,
    required this.spokenLabel,
    super.key,
  }) : assert(value >= 0 && limit >= 0);

  /// The reached amount or count.
  final int value;

  /// The limit or total the value is a share of.
  final int limit;

  /// The spoken description, e.g. "Get started: 0 of 5 steps done."
  final String spokenLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    // Integer flex weights: the fill and the remainder stay exact.
    final filled = value.clamp(0, limit);
    final remaining = limit - filled;
    return Semantics(
      label: spokenLabel,
      child: SizedBox(
        height: SizeTokens.capsule,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surfaceTrack,
            borderRadius: const BorderRadius.all(
              Radius.circular(RadiusTokens.pill),
            ),
            border: Border.all(color: tokens.borderChip, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.xxs),
            child: Row(
              children: [
                if (filled > 0)
                  Expanded(
                    flex: filled,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: role.gradientStart,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(RadiusTokens.pill),
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (remaining > 0)
                  Expanded(
                    flex: remaining,
                    child: const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
