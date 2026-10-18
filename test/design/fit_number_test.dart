import 'package:contour/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const amounts = <String>[
    r'$4,123.65',
    r'$129,800.00',
    r'$1,234,567.89',
    '\u2212\$92,233,720,368,547,758.08',
    r'$0.00',
    r'NT$1,234,567.89',
    r'$······',
    'None recorded',
  ];

  for (final width in <double>[320, 375, 420]) {
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('FitNumber stays inside $width at ${scale}x', (tester) async {
        for (final text in amounts) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: FitNumber(
                      text: text,
                      style: AppText.numberHeroLight,
                      minFontSize: 40,
                    ),
                  ),
                ),
              ),
            ),
          );

          final textWidget = tester.widget<Text>(find.byType(Text));
          final painter = TextPainter(
            text: TextSpan(text: textWidget.data, style: textWidget.style),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(scale),
          )..layout(maxWidth: width);
          var widestLine = 0.0;
          for (final metrics in painter.computeLineMetrics()) {
            if (metrics.width > widestLine) {
              widestLine = metrics.width;
            }
          }

          expect(
            widestLine,
            lessThanOrEqualTo(width + 0.5),
            reason: '"$text" overflows at $width / ${scale}x',
          );
          expect(textWidget.style!.fontSize, greaterThanOrEqualTo(40));
        }
      });
    }
  }
}
