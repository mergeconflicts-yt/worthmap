import 'package:flutter/widgets.dart';

import '../../format/fit_number.dart';
import '../../format/hero_value.dart';
import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../typography/app_text.dart';

/// DESIGN 2.5, 6.7: the hero number with split parts.
///
/// The currency mark is [currencyScale] em at weight 300 and raised by
/// [currencyRaise] em. The cents are [fractionScale] em in `text.secondary`.
/// The whole units keep the `numberHero.light` style and the 14.1(c) fill.
/// `FitNumber` behaviour is kept: the number shrinks from the style size down
/// to [minFontSize] and never loses a digit.
class HeroAmount extends StatelessWidget {
  const HeroAmount({
    required this.value,
    this.minFontSize = 40,
    super.key,
  });

  final HeroValue value;
  final double minFontSize;

  /// DESIGN 2.5: the currency mark is 0.45 em.
  static const double currencyScale = 0.45;

  /// DESIGN 2.5: the cents are 0.5 em.
  static const double fractionScale = 0.5;

  /// DESIGN 2.5 says the currency mark is raised; it does not give the offset.
  /// This is the component geometry, not a colour or a text token.
  static const double currencyRaise = 0.14;

  @override
  Widget build(BuildContext context) {
    final parts = value.parts;
    if (!parts.isAmount) {
      return FitNumber(
        text: parts.plain,
        style: AppText.numberHeroLight,
        minFontSize: minFontSize,
        semanticsLabel: value.semanticsLabel,
      );
    }

    final tokens = context.tokens;
    final scaler = MediaQuery.textScalerOf(context);
    final base = AppText.numberHeroLight.fontSize ?? minFontSize;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double? maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        final double? size = maxWidth == null
            ? base
            : _fitSize(
                context: context,
                scaler: scaler,
                maxWidth: maxWidth,
                base: base,
              );
        if (size == null) {
          // Even the split parts at the minimum size do not fit on one line.
          // Keep the old FitNumber behaviour: one string that shrinks and
          // wraps at group boundaries, so no digit is lost.
          return FitNumber(
            text: parts.text,
            style: AppText.numberHeroLight,
            minFontSize: minFontSize,
            semanticsLabel: value.semanticsLabel,
          );
        }

        final amount = ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) =>
              tokens.textHeroFill.toLinearGradient().createShader(bounds),
          child: Text(
            parts.whole,
            style: AppText.numberHeroLight.copyWith(fontSize: size),
            softWrap: true,
          ),
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            if (parts.signMark.isNotEmpty)
              Transform.translate(
                offset: Offset(0, -size * currencyRaise),
                child: Text(
                  parts.signMark,
                  style: AppText.numberHeroLight.copyWith(
                    fontSize: size * currencyScale,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            if (maxWidth == null) amount else Flexible(child: amount),
            if (parts.fraction.isNotEmpty)
              Text(
                parts.fraction,
                style: AppText.numberHeroLight.copyWith(
                  fontSize: size * fractionScale,
                  color: tokens.textSecondary,
                ),
              ),
            if (parts.marker.isNotEmpty) ...<Widget>[
              const HSpace(Space.xxs),
              Text(
                parts.marker,
                style: AppText.caption.copyWith(color: tokens.textSecondary),
              ),
            ],
          ],
        );
      },
    );
  }

  double? _fitSize({
    required BuildContext context,
    required TextScaler scaler,
    required double maxWidth,
    required double base,
  }) {
    if (_width(context, scaler, base) <= maxWidth) {
      return base;
    }
    var low = minFontSize;
    if (_width(context, scaler, low) > maxWidth) {
      return null;
    }
    var high = base;
    for (var i = 0; i < 18; i++) {
      final mid = (low + high) / 2;
      if (_width(context, scaler, mid) <= maxWidth) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return low;
  }

  double _width(BuildContext context, TextScaler scaler, double size) {
    final painter = TextPainter(
      text: _span(size),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    );
    try {
      painter.layout();
      return painter.width;
    } finally {
      painter.dispose();
    }
  }

  TextSpan _span(double size) {
    final parts = value.parts;
    return TextSpan(
      style: AppText.numberHeroLight.copyWith(fontSize: size),
      children: <InlineSpan>[
        if (parts.signMark.isNotEmpty)
          TextSpan(
            text: parts.signMark,
            style: AppText.numberHeroLight.copyWith(
              fontSize: size * currencyScale,
              fontWeight: FontWeight.w300,
            ),
          ),
        TextSpan(text: parts.whole),
        if (parts.fraction.isNotEmpty)
          TextSpan(
            text: parts.fraction,
            style: AppText.numberHeroLight.copyWith(
              fontSize: size * fractionScale,
            ),
          ),
        if (parts.marker.isNotEmpty)
          TextSpan(
            text: ' ${parts.marker}',
            style: AppText.caption,
          ),
      ],
    );
  }
}
