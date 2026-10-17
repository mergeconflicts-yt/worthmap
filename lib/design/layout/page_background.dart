import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// DESIGN 2.2, 5: the page background. A near-black page with a neutral
/// spotlight at the top. Static; no backdrop blur.
class PageBackground extends StatelessWidget {
  const PageBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final spotlight = tokens.pageSpotlight;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfacePage,
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
    );
  }
}
