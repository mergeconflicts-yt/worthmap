import 'package:contour/design/design.dart';
import 'package:contour/features/history/c06_history.dart';
import 'package:contour/features/history/history_models.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.home, child: child),
    );

final class FakeHistoryGateway implements HistoryGateway {
  FakeHistoryGateway({List<HistoryEntry>? entries})
      : entries = entries ??
            <HistoryEntry>[
              const HistoryEntry(
                operationId: 'o1',
                commandType: 'payment.create',
                committedAtMs: 1700000000000,
                state: HistoryEntryState.reversible,
              ),
              const HistoryEntry(
                operationId: 'o2',
                commandType: 'transfer.create',
                committedAtMs: 1699990000000,
                state: HistoryEntryState.reversed,
              ),
              const HistoryEntry(
                operationId: 'o3',
                commandType: 'budget.saveLimits',
                committedAtMs: 1699980000000,
                state: HistoryEntryState.change,
              ),
            ];

  List<HistoryEntry> entries;
  final List<String> undone = <String>[];
  bool failUndo = false;

  @override
  Future<List<HistoryEntry>> load() async => entries;

  @override
  Future<bool> undo(HistoryEntry entry) async {
    if (failUndo) {
      return false;
    }
    undone.add(entry.operationId);
    entries = <HistoryEntry>[
      for (final item in entries)
        if (item.operationId == entry.operationId)
          HistoryEntry(
            operationId: item.operationId,
            commandType: item.commandType,
            committedAtMs: item.committedAtMs,
            state: HistoryEntryState.reversed,
          )
        else
          item,
    ];
    return true;
  }
}

void main() {
  testWidgets('C06 lists the entries and Undo only for a reversible one',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeHistoryGateway();
    await tester.pumpWidget(
      _wrap(
        C06History(gateway: gateway, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity history'), findsOneWidget);
    expect(find.text('Payment added'), findsOneWidget);
    expect(find.text('Transfer added'), findsOneWidget);
    expect(find.text('Limits saved'), findsOneWidget);
    expect(find.text('Reversed'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Undo'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Undo'));
    await tester.pumpAndSettle();

    expect(gateway.undone, <String>['o1']);
    expect(find.widgetWithText(AppButton, 'Undo'), findsNothing);
    expect(find.text('Reversed'), findsNWidgets(2));
  });

  testWidgets('a failed Undo keeps the entry reversible', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeHistoryGateway()..failUndo = true;
    await tester.pumpWidget(
      _wrap(C06History(gateway: gateway, onClose: () {})),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Undo'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppButton, 'Undo'), findsOneWidget);
  });
}
