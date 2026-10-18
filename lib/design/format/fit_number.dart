import 'package:flutter/widgets.dart';

/// DESIGN 2.5, 4: shrinks a number to fit its box.
///
/// It follows the system text scale up to 2.0 and shrinks the hero number from
/// its style size down to [minFontSize] (40 for `numberHero.light`), never
/// below. It never removes a digit and never shows an ellipsis. Only when the
/// text still does not fit at [minFontSize] does it wrap, at group boundaries
/// (after each thousands separator and after the decimal point), by inserting
/// zero-width spaces that paint nothing.
///
/// N-11: the floor is an unscaled font size, so the effective floor grows
/// with the system scale (80 px at 2.0). Confirm with the design owner that
/// this is the intent. DECISION-PENDING: FITNUMBER-FLOOR.
class FitNumber extends StatelessWidget {
  const FitNumber({
    required this.text,
    required this.style,
    this.minFontSize = 40,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
    super.key,
  });

  final String text;
  final TextStyle style;
  final double minFontSize;
  final TextAlign textAlign;

  /// The clean spoken text (no zero-width breaks). Falls back to [text].
  final String? semanticsLabel;

  /// U+200B: a zero-width space, a break opportunity that paints nothing.
  static const String _zwsp = '\u200B';

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = style.fontSize ?? minFontSize;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double? maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        if (maxWidth == null) {
          return _render(text, base);
        }
        // N-11: a style already at or below the floor cannot shrink further,
        // but it can still wrap instead of clipping.
        if (base <= minFontSize) {
          if (_fits(context, text, base, scaler, maxWidth)) {
            return _render(text, base);
          }
          return _render(_withBreaks(text), base);
        }

        final singleSize = _fitSingleLine(
          context,
          text,
          scaler: scaler,
          maxWidth: maxWidth,
          base: base,
        );
        if (singleSize != null) {
          return _render(text, singleSize);
        }

        // Even the minimum size does not fit on one line: wrap at group
        // boundaries so no digit is lost and nothing is clipped.
        return _render(_withBreaks(text), minFontSize);
      },
    );
  }

  Widget _render(String value, double size) => Text(
        value,
        style: style.copyWith(fontSize: size),
        textAlign: textAlign,
        softWrap: true,
        semanticsLabel: semanticsLabel ?? text,
      );

  /// The largest font size in [minFontSize, base] that fits [value] on one line,
  /// or null when none does. Width is monotonic in the font size, so bisection
  /// is exact enough.
  double? _fitSingleLine(
    BuildContext context,
    String value, {
    required TextScaler scaler,
    required double maxWidth,
    required double base,
  }) {
    if (_lineWidth(context, value, base, scaler) <= maxWidth) {
      return base;
    }
    var low = minFontSize;
    var high = base;
    if (_lineWidth(context, value, low, scaler) > maxWidth) {
      return null;
    }
    for (var i = 0; i < 18; i++) {
      final mid = (low + high) / 2;
      if (_lineWidth(context, value, mid, scaler) <= maxWidth) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return low;
  }

  double _lineWidth(
    BuildContext context,
    String value,
    double fontSize,
    TextScaler scaler,
  ) {
    // N-11: every measuring painter is disposed; up to 19 are made per build.
    final painter = TextPainter(
      text: TextSpan(text: value, style: style.copyWith(fontSize: fontSize)),
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

  bool _fits(
    BuildContext context,
    String value,
    double fontSize,
    TextScaler scaler,
    double maxWidth,
  ) =>
      _lineWidth(context, value, fontSize, scaler) <= maxWidth;

  /// Inserts a break opportunity after each thousands separator, decimal point
  /// and space so a long number can wrap without losing a digit.
  static String _withBreaks(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      buffer.write(char);
      if (char == ',' || char == '.' || char == ' ') {
        buffer.write(_zwsp);
      }
    }
    return buffer.toString();
  }
}
