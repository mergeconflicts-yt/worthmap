@Tags(<String>['golden'])
library;

import 'package:contour/design/design.dart';
import 'package:contour/design/gallery/phase2_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// P18: the Phase 2 components and the tab shell. Dark and Light, 1.0 and 2.0.
/// The surface is tall enough that the 2.0 text does not clip the gallery.
void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('phase 2 components ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 3100 : 3600),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: const Phase2Gallery(),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('phase2_components_${theme.$1}_${scale}x.png'),
        );
      });
    }
  }
}
