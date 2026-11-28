@Tags(<String>['golden'])
library;

import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/spending/c02_schedule_editor.dart';
import 'package:contour/features/spending/c03_rule_editor.dart';
import 'package:contour/features/spending/x34_repeating.dart';
import 'package:contour/features/spending/x35_repeating_detail.dart';
import 'package:contour/features/spending/x84_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/spending/fake_repeating_gateway.dart';
import 'golden_harness.dart';

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      Future<void> pump(
        WidgetTester tester,
        Widget child, {
        required double height,
      }) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(Size(420, height));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: child,
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('repeating list ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X34Repeating(
            gateway: FakeRepeatingGateway(),
            onClose: () {},
            onOpenSchedule: (_) {},
          ),
          height: scale == 1.0 ? 2000 : 2900,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x34_repeating_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('repeating detail ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X35RepeatingDetail(
            gateway: FakeRepeatingGateway(),
            scheduleId: 's2',
            onClose: () {},
          ),
          height: scale == 1.0 ? 2600 : 3800,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x35_repeating_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('rules ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X84Rules(
            gateway: FakeRepeatingGateway(),
            onClose: () {},
            onAddRule: () {},
          ),
          height: scale == 1.0 ? 2000 : 2900,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('screens_x84_rules_${theme.$1}_${scale}x.png'),
        );
      });

      testWidgets('schedule editor ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          C02ScheduleEditor(
            gateway: FakeRepeatingGateway(),
            onClose: () {},
            onSaved: () {},
            today: LocalDate(2026, 11, 22),
          ),
          height: scale == 1.0 ? 2300 : 3400,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_c02_schedule_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('rule editor ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          C03RuleEditor(
            gateway: FakeRepeatingGateway(),
            onClose: () {},
            onSaved: () {},
          ),
          height: scale == 1.0 ? 1600 : 2300,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_c03_rule_${theme.$1}_${scale}x.png',
          ),
        );
      });
    }
  }
}
