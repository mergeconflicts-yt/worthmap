import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../tokens/tokens.g.dart';

/// DESIGN 6.5: `TrackShape` — an empty neutral shape in `surface.track`.
/// It draws silhouettes and empty-state geometry; it never carries data or
/// text. The radius is a token name, not a raw value.
class TrackShape extends StatelessWidget {
  const TrackShape.rect({
    required this.height,
    this.width,
    super.key,
  }) : radius = RadiusTokens.m;

  const TrackShape.tile({
    required this.height,
    this.width,
    super.key,
  }) : radius = RadiusTokens.tile;

  const TrackShape.pill({
    required this.height,
    this.width,
    super.key,
  }) : radius = RadiusTokens.pill;

  final double height;

  /// Null takes the parent's width.
  final double? width;

  /// The radius token value.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: tokens.surfaceTrack,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      ),
    );
  }
}
