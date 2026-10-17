import 'package:flutter/widgets.dart';

import 'tokens.g.dart';

/// DESIGN 2.7: the only spacing scale. Components use [Space] values or the
/// [VSpace] / [HSpace] widgets; never a raw number (DESIGN 9, no_raw_spacing).
abstract final class Space {
  const Space._();

  static const double xxs = SpaceTokens.xxs;
  static const double xs = SpaceTokens.xs;
  static const double s = SpaceTokens.s;
  static const double m = SpaceTokens.m;
  static const double card = SpaceTokens.card;
  static const double cardTitleGap = SpaceTokens.cardTitleGap;
  static const double l = SpaceTokens.l;
  static const double page = SpaceTokens.page;
  static const double cardPad = SpaceTokens.cardPad;
  static const double xl = SpaceTokens.xl;
  static const double xxl = SpaceTokens.xxl;
  static const double xxxl = SpaceTokens.xxxl;
  static const double tabClearance = SpaceTokens.tabClearance;
}

/// A vertical gap on the token scale.
class VSpace extends StatelessWidget {
  const VSpace(this.size, {super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size);
}

/// A horizontal gap on the token scale.
class HSpace extends StatelessWidget {
  const HSpace(this.size, {super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size);
}
