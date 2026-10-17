@Tags(<String>['golden'])
library;

import 'package:contour/design/design.dart';
import 'package:contour/design/gallery/components_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('components ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 3200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: const ComponentsGallery(),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(ComponentsGallery),
          matchesGoldenFile('components_${theme.$1}_${scale}x.png'),
        );
      });
    }
  }
}
