@Tags(<String>['golden'])
library;

import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/add/transfer_form_controller.dart';
import 'package:contour/features/add/x26_transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/add/fake_transfer_gateway.dart';
import 'golden_harness.dart';

Future<TransferFormController> _draft(
  FakeTransferGateway gateway,
  String amount,
) async {
  final controller = TransferFormController(
    gateway: gateway,
    today: LocalDate(2026, 10, 22),
  );
  await controller.initialize();
  for (final key in amount.split('')) {
    controller.pressKey(key);
  }
  return controller;
}

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('transfer to a card ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1400 : 2200),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final gateway = FakeTransferGateway();
        final controller = await _draft(gateway, '1240');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: X26Transfer(
              gateway: gateway,
              today: LocalDate(2026, 10, 22),
              controller: controller,
              showToast: false,
              onClose: () {},
              onSaved: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x26_transfer_card_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('transfer to a bank account ${theme.$1} ${scale}x',
          (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1400 : 2200),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final gateway = FakeTransferGateway(
          accounts: const <AccountSummary>[
            AccountSummary(
              id: 'account-checking',
              name: 'Checking',
              kind: AccountKind.bank,
              currencyCode: 'USD',
              balanceMinor: 645000,
            ),
            AccountSummary(
              id: 'account-savings',
              name: 'Savings',
              kind: AccountKind.bank,
              currencyCode: 'USD',
              balanceMinor: 1500000,
            ),
          ],
        );
        final controller = await _draft(gateway, '2000');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: X26Transfer(
              gateway: gateway,
              today: LocalDate(2026, 10, 22),
              controller: controller,
              showToast: false,
              onClose: () {},
              onSaved: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x26_transfer_bank_${theme.$1}_${scale}x.png',
          ),
        );
      });
    }
  }
}
