@Tags(<String>['golden'])
library;

import 'package:contour/design/design.dart';
import 'package:contour/design/gallery/charts_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// P19/P20: the charts, the period hero, the empty data set and the hidden
/// amount state. Dark and Light, 1.0 and 2.0.
void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('charts ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 3400 : 4400),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: const ChartsGallery(),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('charts_${theme.$1}_${scale}x.png'),
        );
      });
    }
  }
}
