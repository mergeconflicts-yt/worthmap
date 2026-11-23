@Tags(<String>['golden'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:contour/app/demo/sample_statement.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/import/import_controller.dart';
import 'package:contour/features/import/import_models.dart';
import 'package:contour/features/import/x63_import.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/import/fake_import.dart';
import 'golden_harness.dart';

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('import hub ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1700 : 2400),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = ImportController(
          gateway: FakeImportGateway(
            layoutsList: const <SavedLayout>[
              SavedLayout(
                fingerprint: 'a',
                name: 'First Bank, checking',
                usedCount: 4,
              ),
            ],
            historyList: <ImportBatchView>[
              ImportBatchView(
                id: 'b1',
                label: 'First Bank statement, October',
                createdAtMs: DateTime(2026, 10, 13).millisecondsSinceEpoch,
                staged: 36,
                existing: 7,
                accepted: 0,
                status: 'review',
              ),
            ],
          ),
          intake: FakeIntake(buildSyntheticStatement()),
        );
        await controller.load();
        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: X63Import(
              gateway: FakeImportGateway(),
              intake: FakeIntake(buildSyntheticStatement()),
              accounts: FakeAccountsGateway(
                accounts: const <AccountSummary>[checkingAccount],
              ),
              onClose: () {},
              onOpenInbox: () {},
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x63_import_hub_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('import preview ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 2500 : 3400),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = ImportController(
          gateway: FakeImportGateway(),
          intake: FakeIntake(buildSyntheticStatement()),
        );
        await controller.load();
        await controller.chooseFile();
        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: X63Import(
              gateway: FakeImportGateway(),
              intake: FakeIntake(buildSyntheticStatement()),
              accounts: FakeAccountsGateway(
                accounts: const <AccountSummary>[checkingAccount],
              ),
              onClose: () {},
              onOpenInbox: () {},
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x65_import_preview_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('import done ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1700 : 2400),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = ImportController(
          gateway: FakeImportGateway(),
          intake: FakeIntake(buildSyntheticStatement()),
        );
        await controller.load();
        await controller.chooseFile();
        await controller.send(accountId: checkingAccount.id);
        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: X63Import(
              gateway: FakeImportGateway(),
              intake: FakeIntake(buildSyntheticStatement()),
              accounts: FakeAccountsGateway(
                accounts: const <AccountSummary>[checkingAccount],
              ),
              onClose: () {},
              onOpenInbox: () {},
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x68_import_done_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('import error ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1500 : 2100),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = ImportController(
          gateway: FakeImportGateway(),
          intake: FakeIntake(
            Uint8List.fromList(utf8.encode('not a pdf')),
            name: 'scan_0412.pdf',
          ),
        );
        await controller.load();
        await controller.chooseFile();
        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: X63Import(
              gateway: FakeImportGateway(),
              intake: FakeIntake(buildSyntheticStatement()),
              accounts: FakeAccountsGateway(
                accounts: const <AccountSummary>[checkingAccount],
              ),
              onClose: () {},
              onOpenInbox: () {},
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x88_import_error_${theme.$1}_${scale}x.png',
          ),
        );
      });
    }
  }
}
