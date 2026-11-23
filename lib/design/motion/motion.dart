import '../tokens/tokens.g.dart';

/// DESIGN 2.10 (MOTION-002): the only durations. Components use these values;
/// no component writes a raw `Duration`. The toast's 5 s is the SPEC 8.18
/// visible Undo window, not an animation.
abstract final class Motion {
  const Motion._();

  static const Duration press = Duration(milliseconds: MotionTokens.pressScale);
  static const Duration toggle =
      Duration(milliseconds: MotionTokens.toggleTrack);
  static const Duration sheet = Duration(milliseconds: MotionTokens.sheet);
  static const Duration dismiss = Duration(milliseconds: MotionTokens.dismiss);
  static const Duration select = Duration(milliseconds: MotionTokens.select);
  static const Duration toast = Duration(seconds: 5);

  /// DESIGN 7.1, 2.10: one draw-in per chart per session, 400 ms for bars,
  /// 520 ms for lines and 300 ms for a mark. The cap is 900 ms.
  static const Duration drawBar = Duration(milliseconds: MotionTokens.drawBar);
  static const Duration drawLine =
      Duration(milliseconds: MotionTokens.drawLine);
  static const Duration drawDot = Duration(milliseconds: MotionTokens.drawDot);
  static const Duration revisit = Duration(milliseconds: MotionTokens.revisit);
}
