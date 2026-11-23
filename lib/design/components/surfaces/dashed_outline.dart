import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// DESIGN 6.7: a 1 pt dashed outline 6 pt outside a card (WIDGETS-001).
///
/// The dash length and gap are component geometry, not design tokens. The
/// colour comes from `color.border.draft` (white 22% / ink 25%).
class DashedOutline extends StatelessWidget {
  const DashedOutline({
    required this.color,
    required this.radius,
    required this.child,
    super.key,
  });

  /// DESIGN 6.7: the outline sits 6 pt outside the card edge.
  static const double gap = 6;

  /// DESIGN 6.7: the outline is 1 pt.
  static const double strokeWidth = 1;

  static const double dashLength = 4;
  static const double dashGap = 4;

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Component painter for the edit-mode outline; not a chart
    // (DECISIONS T05-DASH-OUTLINE).
    // ignore: no_custom_paint
    return CustomPaint(
      painter: DashedOutlinePainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        dashGap: dashGap,
      ),
      child: Padding(
        padding: const EdgeInsets.all(gap),
        child: child,
      ),
    );
  }
}

// A component painter for the edit-mode outline; not a chart
// (DECISIONS T05-DASH-OUTLINE).
// ignore: no_custom_paint
/// DESIGN 6.7: paints the dashed rounded rectangle for [DashedOutline].
///
/// This is a component painter. DESIGN 9 allows `CustomPaint` only in
/// `lib/design/charts/`; the edit-mode outline needs one here (WIDGETSLOT-DASH,
/// DECISIONS T05-DASH-OUTLINE).
class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - strokeWidth),
      math.max(0, size.height - strokeWidth),
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.dashGap != dashGap;
}
