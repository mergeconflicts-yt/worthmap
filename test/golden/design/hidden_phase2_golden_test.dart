@Tags(<String>['golden'])
library;

import 'package:contour/app/hidden_amounts.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/inbox/x60_inbox.dart';
import 'package:contour/features/spending/x30_spending.dart';
import 'package:contour/features/spending/x36_category_detail.dart';
import 'package:contour/features/spending/x37_all_payments.dart';
import 'package:contour/features/spending/x39_payment_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/inbox/fake_inbox_gateway.dart';
import '../../features/spending/fake_payments_read_gateway.dart';
import '../../features/spending/fake_spending_gateway.dart';
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
        Section section = Section.spending,
      }) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(Size(420, height));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = HiddenAmountsController(initial: true);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          HiddenAmountsHost(
            controller: controller,
            child: goldenApp(
              theme: theme.$2,
              section: section,
              textScale: scale,
              child: child,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('hidden spending root ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X30Spending(
            gateway: FakeSpendingGateway(),
            onWhereItGoes: () {},
            onAllPayments: () {},
            onMoneyIn: () {},
            onBudget: () {},
            onEditLimits: () {},
          ),
          height: scale == 1.0 ? 2900 : 4200,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x30_spending_hidden_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('hidden category ${theme.$1} ${scale}x', (tester) async {
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
            'screens_x36_category_hidden_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('hidden payments ${theme.$1} ${scale}x', (tester) async {
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
            'screens_x37_payments_hidden_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('hidden payment detail ${theme.$1} ${scale}x',
          (tester) async {
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
            'screens_x39_payment_hidden_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('hidden inbox ${theme.$1} ${scale}x', (tester) async {
        await pump(
          tester,
          X60Inbox(
            gateway: FakeInboxGateway(),
            showToast: false,
            onClose: () {},
          ),
          height: scale == 1.0 ? 1800 : 2600,
          section: Section.home,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x60_inbox_hidden_${theme.$1}_${scale}x.png',
          ),
        );
      });
    }
  }
}
