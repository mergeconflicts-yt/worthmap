import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// DESIGN 2.2, 5: the page background. A near-black page with a neutral
/// spotlight at the top. Static; no backdrop blur.
///
/// The background also owns the page's `Material` ancestor (transparent
/// type, so it paints nothing): every screen runs directly on this canvas,
/// and text and icon buttons need a `Material` ancestor. Without it a debug
/// build renders text with the framework's error pattern (red text, yellow
/// underline; Flutter 3.47) and `AppIconButton` asserts. The golden harness
/// wraps its screens in `Material` too, which had masked this gap; the
/// harness wrapper stays and now matches the app structure.
class PageBackground extends StatelessWidget {
  const PageBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final spotlight = tokens.pageSpotlight;
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(color: tokens.surfacePage),
        child: DecoratedBox(
          // A BoxDecoration paints either its colour or its gradient, not
          // both. The page colour is the base layer; the spotlight is a
          // translucent layer on top of it.
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.1,
              colors: <Color>[
                spotlight.color,
                spotlight.color.withValues(alpha: 0),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
