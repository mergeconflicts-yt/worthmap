@Tags(<String>['golden'])
library;

import 'package:contour/design/design.dart';
import 'package:contour/features/spending/x30_spending.dart';
import 'package:contour/features/spending/x30c_where_it_goes.dart';
import 'package:contour/features/spending/x31_money_in.dart';
import 'package:contour/features/spending/x32_budget.dart';
import 'package:contour/features/spending/x33_edit_limits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/spending/fake_spending_gateway.dart';
import 'golden_harness.dart';

Widget _spending(Widget child) => child;

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
            child: _spending(child),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('spending root ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X30Spending(
            gateway: FakeSpendingGateway(),
            onWhereItGoes: () {},
            onAllPayments: () {},
            onRepeating: () {},
            onMoneyIn: () {},
            onBudget: () {},
            onEditLimits: () {},
          ),
          height: scale == 1.0 ? 2900 : 4200,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('screens_x30_spending_${theme.$1}_${scale}x.png'),
        );
      });

      testWidgets('where it goes ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X30cWhereItGoes(
            gateway: FakeSpendingGateway(),
            onClose: () {},
          ),
          height: scale == 1.0 ? 1900 : 2800,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('screens_x30c_where_${theme.$1}_${scale}x.png'),
        );
      });

      testWidgets('money in ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X31MoneyIn(
            gateway: FakeSpendingGateway(),
            onClose: () {},
          ),
          height: scale == 1.0 ? 1700 : 2500,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('screens_x31_money_in_${theme.$1}_${scale}x.png'),
        );
      });

      testWidgets('budget ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X32Budget(
            gateway: FakeSpendingGateway(),
            onClose: () {},
            onEditLimits: () {},
          ),
          height: scale == 1.0 ? 2200 : 3300,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('screens_x32_budget_${theme.$1}_${scale}x.png'),
        );
      });

      testWidgets('edit limits ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X33EditLimits(
            gateway: FakeSpendingGateway(),
            onClose: () {},
          ),
          height: scale == 1.0 ? 2800 : 4000,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('screens_x33_limits_${theme.$1}_${scale}x.png'),
        );
      });
    }
  }
}
