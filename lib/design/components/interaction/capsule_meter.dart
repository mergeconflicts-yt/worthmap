import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import '../../../core/percent.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';

/// DESIGN 6.7: `CapsuleMeter` (fixed mode for the Get started meter, variable
/// mode with an optional "today" tick for a limit).
/// Track `size.capsule`, `radius.pill`, `surface.track`, 1 px inner edge.
/// Solid fill in the section colour to value ÷ limit (capped). No glow, no
/// gradient. The spoken label carries the exact count; the fill is never
/// the only signal (AGENTS 2.2, 6.9).
///
/// The fill uses integer flex weights only: no `double` exists in this
/// component, so the bounded-coordinate rule (AGENTS 12) needs no chart
/// folder exception. The "today" tick is placed with the same integer share.
class CapsuleMeter extends StatelessWidget {
  const CapsuleMeter({
    required this.value,
    required this.limit,
    required this.spokenLabel,
    this.today,
    super.key,
  }) : assert(value >= 0 && limit >= 0);

  /// The reached amount or count.
  final int value;

  /// The limit or total the value is a share of.
  final int limit;

  /// The spoken description, e.g. "Get started: 0 of 5 steps done."
  final String spokenLabel;

  /// Where the current period sits on the track, e.g. the month gone. Null
  /// draws no tick.
  final Percent? today;

  /// The tick share, in ten-thousandths of the track: 50 is 0.5%, about 2 pt
  /// on a phone. Integer weight, so no `double` exists here.
  static const int _units = 10000;
  static const int _tickUnits = 50;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    // Integer flex weights: the fill and the remainder stay exact.
    final filled = value.clamp(0, limit);
    final remaining = limit - filled;
    final track = SizedBox(
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
    );
    final tick = today;
    if (tick == null) return Semantics(label: spokenLabel, child: track);
    // DESIGN 6.7: the today tick is data.neutral.fill, 1.5–2 pt wide, 4 pt
    // over the track at each side.
    final points = (tick.value * Decimal.fromInt(100)).toBigInt().toInt();
    final at = points < 0
        ? 0
        : points > _units - _tickUnits
            ? _units - _tickUnits
            : points;
    final after = _units - _tickUnits - at;
    return Semantics(
      label: spokenLabel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          track,
          // DESIGN 6.7: 4 pt over the track at each side.
          Positioned(
            left: 0,
            right: 0,
            top: -4,
            bottom: -4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (at > 0) Expanded(flex: at, child: const SizedBox.shrink()),
                SizedBox(
                  width: 2,
                  child: ColoredBox(color: tokens.dataNeutralFill),
                ),
                if (after > 0)
                  Expanded(flex: after, child: const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
