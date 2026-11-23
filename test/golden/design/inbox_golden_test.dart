@Tags(<String>['golden'])
library;

import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/inbox/inbox_models.dart';
import 'package:contour/features/inbox/x60_inbox.dart';
import 'package:contour/features/inbox/x61_item_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/inbox/fake_inbox_gateway.dart';
import 'golden_harness.dart';

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('inbox ready ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1800 : 2600),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: X60Inbox(
              gateway: FakeInboxGateway(),
              showToast: false,
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('screens_x60_inbox_${theme.$1}_${scale}x.png'),
        );
      });

      testWidgets('inbox empty ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1300 : 1900),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: X60Inbox(
              gateway: FakeInboxGateway(
                rows: const <InboxRow>[],
                pendingCount: 0,
              ),
              showToast: false,
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x62_inbox_empty_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('inbox item sheet ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final row = InboxRow(
          id: 2,
          title: 'PX Market',
          source: 'statement',
          date: LocalDate(2026, 10, 10),
          amountMinor: -3175,
          currencyCode: 'USD',
          editRevision: 1,
          suggestion: 'new',
          categoryName: 'Groceries',
          accountName: 'Checking',
          isUnsure: true,
        );

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: Material(
              color: theme.$2.extension<ContourTokens>()!.surfaceSheet,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AppSheet(
                  title: 'Check this payment',
                  semanticLabel: 'Check this payment',
                  children: <Widget>[
                    X61InboxItemSheet(
                      row: row,
                      onConfirm: () {},
                      onDelete: () {},
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
            'screens_x61_inbox_item_${theme.$1}_${scale}x.png',
          ),
        );
      });
    }
  }
}
