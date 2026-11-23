import 'package:contour/core/money.dart';
import 'package:contour/design/design.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Section section = Section.home}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SectionScope(
      section: section,
      child: PageBackground(child: child),
    ),
  );
}

const _items = <AppTabItem>[
  AppTabItem(
    section: Section.home,
    label: 'Home',
    semanticLabel: 'Home, 12 to check',
    icon: AppIcons.house,
    badgeCount: 12,
  ),
  AppTabItem(
    section: Section.spending,
    label: 'Spending',
    semanticLabel: 'Spending',
    icon: AppIcons.chart,
  ),
  AppTabItem(
    section: Section.wealth,
    label: 'Wealth',
    semanticLabel: 'Wealth',
    icon: AppIcons.bank,
  ),
  AppTabItem(
    section: Section.plan,
    label: 'Plan',
    semanticLabel: 'Plan',
    icon: AppIcons.calendar,
  ),
];

void main() {
  testWidgets('the tab bar has four tabs, one Add and a count badge',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = Section.home;
    var added = 0;
    var voice = 0;
    await tester.pumpWidget(
      _wrap(
        AppTabBar(
          items: _items,
          selected: Section.home,
          onSelect: (value) => selected = value,
          onAdd: () => added += 1,
          addSemanticLabel: 'Add',
          onVoice: () => voice += 1,
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Spending'), findsOneWidget);
    expect(find.text('Wealth'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.bySemanticsLabel('Add'), findsOneWidget);

    await tester.tap(find.text('Spending'));
    expect(selected, Section.spending);

    await tester.tap(find.bySemanticsLabel('Add'));
    expect(added, 1);

    await tester.longPress(find.bySemanticsLabel('Add'));
    expect(voice, 1);
    semantics.dispose();
  });

  testWidgets('the keypad sends digits, a decimal point and delete',
      (tester) async {
    final values = <String>[];
    var deletes = 0;
    await tester.pumpWidget(
      _wrap(
        Keypad(
          onDigit: values.add,
          onDelete: () => deletes += 1,
          deleteLabel: 'Delete',
          decimalLabel: 'Decimal point',
        ),
      ),
    );

    await tester.tap(find.text('7'));
    await tester.tap(find.text('.'));
    await tester.tap(find.text('Delete'));
    expect(values, <String>['7', '.']);
    expect(deletes, 1);
    expect(
      tester.getSize(find.text('7')).height,
      greaterThanOrEqualTo(20),
    );
  });

  testWidgets('the checkbox toggles in a 44 pt target', (tester) async {
    var changed = false;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: <Widget>[
            AppCheckbox(
              value: false,
              onChanged: (value) => changed = value,
              semanticLabel: 'PX Market',
            ),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppCheckbox)).width, SizeTokens.touchMin);
    expect(
      tester.getSize(find.byType(AppCheckbox)).height,
      SizeTokens.touchMin,
    );
    await tester.tap(find.byType(AppCheckbox));
    expect(changed, isTrue);
  });

  testWidgets('the segmented control selects one item', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: <Widget>[
            SegmentedControl(
              segments: const <String>['Expense', 'Income', 'Transfer'],
              selectedIndex: 0,
              onChanged: (value) => selected = value,
              semanticLabel: 'Type',
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SegmentedControl)).height,
      SizeTokens.touchMin,
    );
    await tester.tap(find.text('Income'));
    expect(selected, 1);
  });

  testWidgets('filter, choice and dashed chips show their data',
      (tester) async {
    var tapped = '';
    await tester.pumpWidget(
      _wrap(
        Column(
          children: <Widget>[
            ChipRow(
              items: <ChipItem>[
                ChipItem(
                  label: 'Notifications',
                  semanticLabel: 'Notifications, 6',
                  count: 6,
                  variant: ChipVariant.filter,
                  onPressed: () => tapped = 'filter',
                ),
              ],
            ),
            ChipRow(
              items: <ChipItem>[
                ChipItem(
                  label: 'Dining',
                  semanticLabel: 'Dining',
                  dotColor: ColorTokensDark.dataCategoryDining,
                  selected: true,
                  onPressed: () => tapped = 'choice',
                ),
                ChipItem(
                  label: 'All categories',
                  semanticLabel: 'All categories',
                  variant: ChipVariant.dashed,
                  onPressed: () => tapped = 'dashed',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('6'), findsOneWidget);
    await tester.tap(find.text('Notifications'));
    expect(tapped, 'filter');
    await tester.tap(find.text('All categories'));
    expect(tapped, 'dashed');
  });

  testWidgets('the field shows a label and helper and accepts text',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        AppField(
          label: 'Where or what?',
          semanticLabel: 'Where or what',
          hint: 'For example Starbucks',
          helper: 'A shop or a short note',
          controller: controller,
        ),
      ),
    );

    expect(find.text('Where or what?'), findsOneWidget);
    expect(find.text('A shop or a short note'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Starbucks');
    expect(controller.text, 'Starbucks');
  });

  testWidgets('the amount input shows a filled and an empty state',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          children: <Widget>[
            AmountInput(
              value: ValueSpec.real(Money.fromMinor(2400, Currency.usd)),
              semanticLabel: 'Amount \$24.00',
              emptyText: '\$0.00',
              emptySemanticLabel: 'Amount, not filled yet',
            ),
            const AmountInput(
              value: null,
              semanticLabel: 'Amount \$0.00',
              emptyText: '\$0.00',
              emptySemanticLabel: 'Amount, not filled yet',
            ),
          ],
        ),
      ),
    );

    expect(find.text('\$0.00'), findsOneWidget);
    expect(find.bySemanticsLabel('Amount \$24.00'), findsOneWidget);
    expect(find.bySemanticsLabel('Amount, not filled yet'), findsOneWidget);
  });

  testWidgets('a pill picker opens its sheet', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: <Widget>[
            PillPicker(
              label: 'USD',
              semanticLabel: 'Currency: USD',
              onPressed: () => opened = true,
            ),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byType(PillPicker)).height, SizeTokens.touchMin);
    await tester.tap(find.byType(PillPicker));
    expect(opened, isTrue);
  });

  testWidgets('the split editor adds, edits and removes a part',
      (tester) async {
    var added = 0;
    var edited = 0;
    var removed = 0;
    await tester.pumpWidget(
      _wrap(
        SplitEditor(
          parts: <SplitPart>[
            SplitPart(
              name: 'Groceries',
              amountText: '\$84.12',
              removeLabel: 'Remove Groceries',
              onAmountTap: () => edited += 1,
              onRemove: () => removed += 1,
            ),
          ],
          addLabel: 'Add a part',
          onAdd: () => added += 1,
          leftLabel: 'Left to split',
          leftValue: MoneyText(
            ValueSpec.real(Money.fromMinor(0, Currency.usd)),
            style: AppText.numberXS,
          ),
        ),
      ),
    );

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Left to split'), findsOneWidget);
    await tester.tap(find.text('Add a part'));
    expect(added, 1);
    await tester.tap(find.text('\$84.12'));
    expect(edited, 1);
    await tester.tap(find.bySemanticsLabel('Remove Groceries'));
    expect(removed, 1);
  });

  testWidgets('the confirm bar uses its exact label and disables',
      (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: <Widget>[
            ConfirmBar(
              label: 'Confirm 8 ticked, \$412.36',
              onPressed: () => pressed += 1,
            ),
            const ConfirmBar(
              label: 'Confirm 0 ticked',
              onPressed: null,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Confirm 8 ticked, \$412.36'));
    expect(pressed, 1);
    await tester.tap(find.text('Confirm 0 ticked'));
    expect(pressed, 1);
  });

  testWidgets('the undo bar and the toast call Undo', (tester) async {
    var undo = 0;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: <Widget>[
            UndoBar(
              message: 'Payment deleted',
              undoLabel: 'Undo',
              onUndo: () => undo += 1,
              semanticLabel: 'Payment deleted. Undo',
            ),
            AppToast(
              message: 'Payment saved',
              undoLabel: 'Undo',
              onUndo: () => undo += 1,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Undo').first);
    expect(undo, 1);
    await tester.tap(find.text('Undo').last);
    expect(undo, 2);
  });

  testWidgets('the dialog shows a title and runs its actions', (tester) async {
    var primary = 0;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () => showAppDialog<void>(
                context,
                title: 'Delete this payment?',
                body: 'The payment is removed from every total.',
                primaryLabel: 'Delete payment',
                onPrimary: () => primary += 1,
                secondaryLabel: 'Cancel',
                onSecondary: () => Navigator.of(context).pop(),
                semanticLabel: 'Delete this payment?',
              ),
              child: const SizedBox(
                width: 120,
                height: 44,
                child: Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this payment?'), findsOneWidget);
    await tester.tap(find.text('Delete payment'));
    expect(primary, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this payment?'), findsNothing);
  });

  testWidgets('the sheet shows its title, content and footer', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () => showAppSheet<void>(
                context,
                title: 'Details',
                semanticLabel: 'Date, account, currency',
                footer: ConfirmBar(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                children: const <Widget>[
                  Text('Sheet content'),
                ],
              ),
              child: const SizedBox(
                width: 120,
                height: 44,
                child: Text('open sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Sheet content'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('the toast appears and dismisses after its window',
      (tester) async {
    var undo = 0;
    await tester.pumpWidget(_wrap(const SizedBox.expand()));
    final context = tester.element(find.byType(SizedBox).first);

    showAppToast(
      context,
      message: 'Payment saved',
      undoLabel: 'Undo',
      onUndo: () => undo += 1,
      duration: const Duration(milliseconds: 50),
    );
    await tester.pump();
    expect(find.text('Payment saved'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    expect(undo, 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Payment saved'), findsNothing);
  });

  testWidgets('the tab shell hides the bar while the keyboard is open',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        TabShell(
          tabBar: AppTabBar(
            items: _items,
            selected: Section.home,
            onSelect: (_) {},
            onAdd: () {},
            addSemanticLabel: 'Add',
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byType(AppTabBar), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(find.byType(AppTabBar), findsNothing);
  });

  testWidgets('a SelectTile reports its choice and its 44 pt target',
      (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SelectTile(
                    label: 'Dining',
                    semanticLabel: 'Dining, selected',
                    selected: true,
                    dotColor: ColorTokensDark.dataCategoryDining,
                    onPressed: () => pressed += 1,
                  ),
                ),
                const Expanded(
                  child: SelectTile(
                    label: 'Coffee',
                    semanticLabel: 'Coffee',
                    selected: false,
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dining'), findsOneWidget);
    expect(tester.getSize(find.byType(SelectTile).first).height, 80);
    await tester.tap(find.text('Dining'));
    expect(pressed, 1);
    await tester.tap(find.text('Coffee'), warnIfMissed: false);
    expect(pressed, 1, reason: 'a tile without a handler is inert');
  });

  testWidgets('a DayCell marks the chosen day, today and a future day',
      (tester) async {
    var chosen = 0;
    await tester.pumpWidget(
      _wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DayCell(
                    day: 13,
                    semanticLabel: '13 October, today',
                    selected: true,
                    enabled: true,
                    isToday: true,
                    onPressed: () => chosen += 1,
                  ),
                ),
                const Expanded(
                  child: DayCell(
                    day: 20,
                    semanticLabel: '20 October',
                    selected: false,
                    enabled: false,
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ),
        ),
        section: Section.spending,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('13'), findsOneWidget);
    expect(tester.getSize(find.byType(DayCell).first).height, greaterThan(0));
    await tester.tap(find.text('13'));
    expect(chosen, 1);
    await tester.tap(find.text('20'), warnIfMissed: false);
    expect(chosen, 1, reason: 'a future day is not selectable');
  });
}
