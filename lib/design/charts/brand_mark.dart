/// DESIGN 6.7: `BrandMark` — one luminous contour line
/// #9BAFFF → #C9B6FF with a white end dot and two faint lower lines on a
/// dark squircle. Welcome shows 64 pt, Lock 76 pt.
///
/// The mark is decorative: it is excluded from semantics, and each screen
/// provides its own l10n label for the group (AGENTS 6.9).
///
/// The painter lives under `lib/design/charts/` because DESIGN 9 confines
/// `CustomPainter` to that folder; it draws the brand, not data.
///
/// T10-BRANDMARK closed 2026-11-22 (DECISIONS "Decided"): the painter's
/// approximation is acceptable for Phase 1 prototyping. The source SVGs
/// (`docs/brand/*.svg`) are still absent, so the painter follows the written
/// anatomy, not the asset; replace it with the bundled asset before any
/// release-facing use of the mark.
library;

import 'package:flutter/widgets.dart';

/// DESIGN 6.7: `BrandMark` — one luminous contour line
/// #9BAFFF → #C9B6FF with a white end dot and two faint lower lines on a
/// dark squircle. Welcome shows 64 pt, Lock 76 pt.
///
/// The mark is decorative: it is excluded from semantics, and each screen
/// provides its own l10n label for the group (AGENTS 6.9).
///
/// The painter lives under `lib/design/charts/` because DESIGN 9 confines
/// `CustomPainter` to that folder; it draws the brand, not data.
///
/// T10-BRANDMARK closed 2026-11-22 (DECISIONS "Decided"): the painter's
/// approximation is acceptable for Phase 1 prototyping. The source SVGs
/// (`docs/brand/*.svg`) are still absent, so the painter follows the written
/// anatomy, not the asset; replace it with the bundled asset before any
/// release-facing use of the mark.
class BrandMark extends StatelessWidget {
  const BrandMark({
    required this.point,
    super.key,
  });

  /// The mark size in logical points (64 for Welcome, 76 for Lock).
  final double point;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: point,
        child: CustomPaint(painter: _BrandMarkPainter()),
      ),
    );
  }
}

final class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Colour literals live in this file only because the brand source asset
    // is absent (T10-BRANDMARK, closed 2026-11-22: painter acceptable for
    // Phase 1). The values are the ones DESIGN 6.7 states for the mark.
    const squircle = Color(0xFF0B0C0E);
    const lineStart = Color(0xFF9BAFFF);
    const lineEnd = Color(0xFFC9B6FF);
    const faint = Color(0x2EFFFFFF);
    const endDot = Color(0xFFFFFFFF);

    final rect = Offset.zero & size;
    final radius = size.width * 0.24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(radius),
      ),
      Paint()..color = squircle,
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [lineStart, lineEnd],
      ).createShader(rect);
    canvas.drawPath(_contourPath(size), stroke);

    // Two faint lower lines.
    final faintPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round
      ..color = faint;
    canvas.drawPath(_faintPath(size, dy: size.height * 0.10), faintPaint);
    canvas.drawPath(_faintPath(size, dy: size.height * 0.18), faintPaint);

    // White end dot at the main line's end.
    canvas.drawCircle(
      const Offset(_endX, _endY) * size.width,
      size.width * 0.055,
      Paint()..color = endDot,
    );
  }

  // Contour anchor points, as fractions of the mark size.
  static const double _endX = 0.82;
  static const double _endY = 0.34;

  Path _contourPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.16, h * 0.72)
      ..quadraticBezierTo(w * 0.30, h * 0.30, w * 0.52, h * 0.42)
      ..quadraticBezierTo(w * 0.70, h * 0.52, w * _endX, h * _endY);
  }

  Path _faintPath(Size size, {required double dy}) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.20, h * 0.80)
      ..quadraticBezierTo(w * 0.34, h * 0.58 + dy, w * 0.52, h * 0.62)
      ..quadraticBezierTo(w * 0.68, h * 0.66 + dy * 0.4, w * 0.78, h * 0.55);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) => false;
}
