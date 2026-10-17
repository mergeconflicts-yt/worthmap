import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// One shadow layer of an elevation token (DESIGN 2.9).
final class ShadowLayer {
  const ShadowLayer({
    required this.dx,
    required this.dy,
    required this.blur,
    required this.spread,
    required this.color,
    required this.inset,
  });

  final double dx;
  final double dy;
  final double blur;
  final double spread;
  final Color color;
  final bool inset;
}

/// An elevation token: shadow layers plus an optional translucent fill and a
/// backdrop blur radius (DESIGN 2.9).
final class ElevationSpec {
  const ElevationSpec({required this.layers, this.fill, this.blur});

  final List<ShadowLayer> layers;
  final Color? fill;
  final double? blur;
}

/// The raw values of one text style (DESIGN 2.5). T04 builds the TextStyle.
final class TypeStyle {
  const TypeStyle({
    required this.size,
    required this.weight,
    required this.letterSpacing,
    required this.lineHeight,
    required this.uppercase,
  });

  final double size;
  final int weight;

  /// Letter spacing in em units.
  final double letterSpacing;

  /// Line height as a multiplier of the size.
  final double lineHeight;
  final bool uppercase;
}

/// A linear gradient: an angle in degrees and its stops at even spacing
/// (DESIGN 2.2, 2.3).
final class GradientSpec {
  const GradientSpec({
    required this.angle,
    required this.colors,
    required this.stops,
  });

  final double angle;
  final List<Color> colors;
  final List<double> stops;

  /// Builds a [LinearGradient]. The angle is in degrees, 0 points right.
  LinearGradient toLinearGradient() {
    final radians = angle * math.pi / 180;
    final dx = math.cos(radians);
    final dy = math.sin(radians);
    return LinearGradient(
      begin: Alignment(-dx, -dy),
      end: Alignment(dx, dy),
      colors: colors,
      stops: stops,
    );
  }
}

/// DESIGN 2.9: the outer shadow layers of an elevation token as
/// [BoxShadow]s. Inset layers are ignored (Flutter has no inset shadow).
extension ElevationShadows on ElevationSpec {
  List<BoxShadow> get shadows => <BoxShadow>[
        for (final layer in layers)
          if (!layer.inset)
            BoxShadow(
              color: layer.color,
              offset: Offset(layer.dx, layer.dy),
              blurRadius: layer.blur,
              spreadRadius: layer.spread,
            ),
      ];
}

/// The page spotlight: a soft radial wash anchored to an edge (DESIGN 2.2).
final class SpotlightSpec {
  const SpotlightSpec({required this.color, required this.anchor});

  final Color color;
  final String anchor;
}
