@Tags(<String>['golden'])
library;

import 'package:contour/design/design.dart';
import 'package:contour/features/spending/payments_models.dart';
import 'package:contour/features/spending/x36_category_detail.dart';
import 'package:contour/features/spending/x37_all_payments.dart';
import 'package:contour/features/spending/x38_filter_sheet.dart';
import 'package:contour/features/spending/x39_payment_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/spending/fake_payments_read_gateway.dart';
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

      testWidgets('category detail ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X36CategoryDetail(
            gateway: FakePaymentsReadGateway(),
            categoryId: 'cat-groceries',
            onClose: () {},
            onOpenPayment: (String id) async => null,
            onAllPayments: (_) {},
          ),
          height: scale == 1.0 ? 3000 : 4300,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x36_category_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('all payments ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X37AllPayments(
            gateway: FakePaymentsReadGateway(),
            onClose: () {},
            onOpenPayment: (String id) async => null,
          ),
          height: scale == 1.0 ? 2300 : 3400,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x37_payments_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('filter sheet ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 980));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: Material(
              color: theme.$2.extension<ContourTokens>()!.surfacePage,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AppSheet(
                  title: 'Filter',
                  semanticLabel: 'Filter',
                  children: <Widget>[
                    X38FilterSheet(
                      gateway: FakePaymentsReadGateway(),
                      initial: const PaymentFilter(
                        period: PaymentPeriod.thisMonth,
                        show: PaymentShowFilter.moneyOut,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x38_filter_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('payment detail ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X39PaymentDetail(
            gateway: FakePaymentsReadGateway(),
            paymentId: 'p3',
            onClose: () {},
            onDeleted: (_) {},
          ),
          height: scale == 1.0 ? 2500 : 3600,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x39_payment_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('delete dialog ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: Material(
              color: theme.$2.extension<ContourTokens>()!.surfacePage,
              child: Center(
                child: Material(
                  color: theme.$2.extension<ContourTokens>()!.surfaceSheet,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                  ),
                  child: AppDialog(
                    leading: const IconTile(icon: AppIcons.trash),
                    title: 'Delete this payment?',
                    body: 'Whole Foods Market, \$121.30 on 5 Oct. '
                        'You can undo for 5 seconds after deleting.',
                    primaryLabel: 'Delete payment',
                    primaryVariant: AppButtonVariant.destructive,
                    secondaryLabel: 'Keep it',
                    semanticLabel: 'Delete this payment?',
                    onPrimary: () {},
                    onSecondary: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x39b_delete_${theme.$1}_${scale}x.png',
          ),
        );
      });
    }
  }
}
