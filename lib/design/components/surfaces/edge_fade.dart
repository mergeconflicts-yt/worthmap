// DESIGN 14.1: the allowed "fade" gradient use.
//
// Masks the trailing edge of a scroll region, so the content that continues
// past the viewport reads as "more to scroll", not as a cut. The hero
// background fade (ObHero) uses the same mask grammar.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A trailing-edge fade over [child]. The last [extent] points fade out.
class EdgeFade extends StatelessWidget {
  const EdgeFade({required this.child, this.extent = 28, super.key});

  final Widget child;

  /// How much of the trailing edge fades.
  final double extent;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        final stop = bounds.width <= 0
            ? 1.0
            : math.max(0.0, (bounds.width - extent) / bounds.width);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: <double>[0, stop, 1],
          colors: const <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
