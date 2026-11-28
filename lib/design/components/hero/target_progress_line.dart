import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import '../../../core/percent.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.7, SCREENS X10: the net worth target line under the hero number.
///
/// One 36 pt bar, then the share, target and date. The bar is a shape that
/// repeats the percentage, so it is decorative. The line opens Goals (X52)
/// when [onPressed] is set. The caller supplies the visible and spoken line
/// from l10n; this component formats no financial value.
class TargetProgressLine extends StatelessWidget {
  const TargetProgressLine({
    required this.share,
    required this.label,
    this.semanticLabel,
    this.onPressed,
    super.key,
  });

  /// The share of the target reached, in percentage points.
  final Percent share;

  /// The visible line, for example
  /// "18.8% of $1,000,000 target · Dec 2040".
  final String label;

  /// The spoken line when it differs from [label] (the amount is hidden).
  final String? semanticLabel;

  /// Opens Goals. Null until the Goals screen ships (v1.1).
  final VoidCallback? onPressed;

  /// SCREENS X10: the bar is 36 pt wide. Height follows `size.meterS`.
  static const double _barWidth = 36;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        ExcludeSemantics(
          child: _bar(
            filled: _filledFlex(),
            track: tokens.surfaceTrack,
            mark: role.gradientStart,
          ),
        ),
        const HSpace(Space.s),
        Expanded(
          child: Text(
            label,
            style: AppText.captionStrong.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ),
      ],
    );

    if (onPressed == null) {
      if (semanticLabel == null) {
        return content;
      }
      return Semantics(
        label: semanticLabel,
        child: ExcludeSemantics(child: content),
      );
    }
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: AppInteraction(
          onActivated: onPressed,
          borderRadius: BorderRadius.circular(RadiusTokens.s),
          // A tappable line keeps the 44 pt touch target.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SizeTokens.touchMin),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _bar({
    required int filled,
    required Color track,
    required Color mark,
  }) {
    final remaining = 1000 - filled;
    return SizedBox(
      width: _barWidth,
      height: SizeTokens.meterS,
      child: ClipRRect(
        borderRadius:
            const BorderRadius.all(Radius.circular(RadiusTokens.pill)),
        child: ColoredBox(
          color: track,
          child: Row(
            children: <Widget>[
              if (filled > 0)
                Expanded(
                  flex: filled,
                  child:
                      ColoredBox(color: mark, child: const SizedBox.expand()),
                ),
              if (remaining > 0)
                Expanded(
                  flex: remaining,
                  child: const SizedBox.expand(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Integer flex weights in tenths of a percent, capped at 1000 (100%).
  int _filledFlex() {
    final tenths =
        (share.value * Decimal.fromInt(10)).round().toBigInt().toInt();
    return tenths.clamp(0, 1000);
  }
}
