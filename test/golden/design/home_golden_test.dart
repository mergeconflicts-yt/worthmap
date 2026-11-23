@Tags(<String>['golden'])
library;

import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/home/x10_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/home/fake_home_gateway.dart';
import 'golden_harness.dart';

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('home ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 2400 : 3400),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: X10Home(
              gateway: const FakeHomeGateway(),
              today: LocalDate(2026, 10, 13),
              onInbox: () {},
              onSettings: () {},
              onSpending: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('screens_x10_home_${theme.$1}_${scale}x.png'),
        );
      });
    }
  }
}
