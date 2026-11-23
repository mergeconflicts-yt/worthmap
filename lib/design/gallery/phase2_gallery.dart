import 'package:contour/core/money.dart';
import 'package:flutter/widgets.dart';

import '../components/buttons/info_button.dart';
import '../components/controls/checkbox.dart';
import '../components/controls/chip_row.dart';
import '../components/controls/day_cell.dart';
import '../components/controls/segmented_control.dart';
import '../components/controls/select_tile.dart';
import '../components/feedback/app_dialog.dart';
import '../components/feedback/app_toast.dart';
import '../components/feedback/confirm_bar.dart';
import '../components/feedback/undo_bar.dart';
import '../components/forms/amount_input.dart';
import '../components/forms/app_field.dart';
import '../components/forms/keypad.dart';
import '../components/forms/pill_picker.dart';
import '../components/forms/split_editor.dart';
import '../components/navigation/app_tab_bar.dart';
import '../components/overlays/app_sheet.dart';
import '../format/money_text.dart';
import '../format/value_presentation.dart';
import '../icons/app_icons.dart';
import '../layout/tab_shell.dart';
import '../theme/app_theme.dart';
import '../theme/section.dart';
import '../tokens/space.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';

/// DESIGN 0.5, 10: the gallery entry for the P18 components and the tab shell.
/// Each variant appears here; a separate private build keeps one control row
/// per section.
class Phase2Gallery extends StatelessWidget {
  const Phase2Gallery({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.surfacePage,
      child: const SingleChildScrollView(
        padding: EdgeInsets.all(Space.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Heading('AppTabBar'),
            _TabBarDemo(),
            _Heading('SegmentedControl'),
            _TypeRowDemo(),
            _Heading('ChipRow · filter'),
            _FilterChipsDemo(),
            _Heading('ChipRow · choice and dashed'),
            _ChoiceChipsDemo(),
            _Heading('AppCheckbox'),
            _CheckboxDemo(),
            _Heading('SelectTile'),
            _SelectTileDemo(),
            _Heading('DayCell'),
            _DayCellDemo(),
            _Heading('AppField'),
            _FieldDemo(),
            _Heading('AmountInput'),
            _AmountDemo(),
            _Heading('Keypad'),
            _KeypadDemo(),
            _Heading('PillPicker'),
            _PillDemo(),
            _Heading('SplitEditor'),
            _SplitDemo(),
            _Heading('ConfirmBar'),
            _ConfirmDemo(),
            _Heading('AppToast'),
            _ToastDemo(),
            _Heading('UndoBar'),
            _UndoDemo(),
            _Heading('AppDialog'),
            _DialogDemo(),
            _Heading('AppSheet'),
            _SheetDemo(),
            _Heading('TabShell'),
            _ShellDemo(),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.l, bottom: Space.s),
      child: Text(
        text.toUpperCase(),
        style: AppText.labelCaps.copyWith(color: context.tokens.textSecondary),
        semanticsLabel: text,
      ),
    );
  }
}

class _TabBarDemo extends StatelessWidget {
  const _TabBarDemo();

  @override
  Widget build(BuildContext context) {
    return AppTabBar(
      items: const <AppTabItem>[
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
      ],
      selected: Section.home,
      onSelect: (_) {},
      onAdd: () {},
      addSemanticLabel: 'Add',
      onVoice: () {},
    );
  }
}

class _TypeRowDemo extends StatelessWidget {
  const _TypeRowDemo();

  @override
  Widget build(BuildContext context) {
    return SegmentedControl(
      segments: const <String>['Expense', 'Income', 'Transfer'],
      selectedIndex: 0,
      onChanged: (_) {},
      semanticLabel: 'Type',
    );
  }
}

class _FilterChipsDemo extends StatelessWidget {
  const _FilterChipsDemo();

  @override
  Widget build(BuildContext context) {
    return ChipRow(
      items: <ChipItem>[
        ChipItem(
          label: 'All',
          semanticLabel: 'All, 12',
          count: 12,
          variant: ChipVariant.filter,
          selected: true,
          onPressed: () {},
        ),
        ChipItem(
          label: 'Notifications',
          semanticLabel: 'Notifications, 6',
          count: 6,
          variant: ChipVariant.filter,
          onPressed: () {},
        ),
        ChipItem(
          label: 'Mail app',
          semanticLabel: 'Mail app, 5',
          count: 5,
          variant: ChipVariant.filter,
          onPressed: () {},
        ),
        ChipItem(
          label: 'Statement',
          semanticLabel: 'Statement, 1',
          count: 1,
          variant: ChipVariant.filter,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _ChoiceChipsDemo extends StatelessWidget {
  const _ChoiceChipsDemo();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ChipRow(
      items: <ChipItem>[
        ChipItem(
          label: 'Dining',
          semanticLabel: 'Dining',
          variant: ChipVariant.choice,
          dotColor: tokens.isDark
              ? ColorTokensDark.dataCategoryDining
              : ColorTokensLight.dataCategoryDining,
          selected: true,
          onPressed: () {},
        ),
        ChipItem(
          label: 'Groceries',
          semanticLabel: 'Groceries',
          variant: ChipVariant.choice,
          dotColor: tokens.isDark
              ? ColorTokensDark.dataCategoryGroceries
              : ColorTokensLight.dataCategoryGroceries,
          onPressed: () {},
        ),
        ChipItem(
          label: 'Transport',
          semanticLabel: 'Transport',
          variant: ChipVariant.choice,
          dotColor: tokens.isDark
              ? ColorTokensDark.dataCategoryTransport
              : ColorTokensLight.dataCategoryTransport,
          onPressed: () {},
        ),
        ChipItem(
          label: 'All categories',
          semanticLabel: 'All categories',
          variant: ChipVariant.dashed,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _CheckboxDemo extends StatelessWidget {
  const _CheckboxDemo();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(
      spacing: Space.xxl,
      runSpacing: Space.s,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppCheckbox(
              value: true,
              onChanged: (_) {},
              semanticLabel: 'PX Market',
            ),
            const HSpace(Space.m),
            Text(
              'PX Market',
              style: AppText.body.copyWith(color: tokens.textPrimary),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppCheckbox(
              value: false,
              onChanged: (_) {},
              semanticLabel: 'Coffee shop',
            ),
            const HSpace(Space.m),
            Text(
              'Coffee shop',
              style: AppText.body.copyWith(color: tokens.textPrimary),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectTileDemo extends StatelessWidget {
  const _SelectTileDemo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SelectTile(
            label: 'Dining',
            semanticLabel: 'Dining, selected',
            selected: true,
            dotColor: ColorTokensDark.dataCategoryDining,
            onPressed: () {},
          ),
        ),
        const HSpace(Space.s),
        Expanded(
          child: SelectTile(
            label: 'Groceries',
            semanticLabel: 'Groceries',
            selected: false,
            dotColor: ColorTokensDark.dataCategoryGroceries,
            onPressed: () {},
          ),
        ),
        const HSpace(Space.s),
        Expanded(
          child: SelectTile(
            label: 'Coffee',
            semanticLabel: 'Coffee',
            selected: false,
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

class _DayCellDemo extends StatelessWidget {
  const _DayCellDemo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: DayCell(
            day: 13,
            semanticLabel: '13 October, today',
            selected: true,
            enabled: true,
            isToday: true,
            onPressed: () {},
          ),
        ),
        const HSpace(Space.xs),
        Expanded(
          child: DayCell(
            day: 14,
            semanticLabel: '14 October',
            selected: false,
            enabled: true,
            onPressed: () {},
          ),
        ),
        const HSpace(Space.xs),
        Expanded(
          child: DayCell(
            day: 20,
            semanticLabel: '20 October',
            selected: false,
            enabled: false,
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

class _FieldDemo extends StatelessWidget {
  const _FieldDemo();

  @override
  Widget build(BuildContext context) {
    return const AppField(
      label: 'Where or what?',
      semanticLabel: 'Where or what, for example Starbucks',
      hint: 'For example Starbucks',
      helper: 'A shop or a short note',
      trailing: InfoButton(semanticLabel: 'About this field'),
    );
  }
}

class _AmountDemo extends StatelessWidget {
  const _AmountDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AmountInput(
          value: ValueSpec.real(Money.fromMinor(2400, Currency.usd)),
          semanticLabel: 'Amount \$24.00',
          emptyText: '\$0.00',
          emptySemanticLabel: 'Amount, not filled yet',
        ),
        const VSpace(Space.m),
        const AmountInput(
          value: null,
          semanticLabel: 'Amount \$0.00',
          emptyText: '\$0.00',
          emptySemanticLabel: 'Amount, not filled yet',
        ),
      ],
    );
  }
}

class _KeypadDemo extends StatelessWidget {
  const _KeypadDemo();

  @override
  Widget build(BuildContext context) {
    return Keypad(
      onDigit: (_) {},
      onDelete: () {},
      deleteLabel: 'Delete',
      decimalLabel: 'Decimal point',
    );
  }
}

class _PillDemo extends StatelessWidget {
  const _PillDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: <Widget>[
        PillPicker(
          label: 'USD',
          semanticLabel: 'Currency: USD. Opens details',
          onPressed: () {},
        ),
        PillPicker(
          label: 'Today',
          semanticLabel: 'Date: today. Opens details',
          onPressed: () {},
        ),
        PillPicker(
          label: 'Visa card',
          semanticLabel: 'Account: Visa card. Opens details',
          selected: true,
          onPressed: () {},
        ),
        PillPicker(
          label: 'Split',
          semanticLabel: 'Split this payment',
          onPressed: () {},
        ),
      ],
    );
  }
}

class _SplitDemo extends StatelessWidget {
  const _SplitDemo();

  @override
  Widget build(BuildContext context) {
    return SplitEditor(
      parts: <SplitPart>[
        SplitPart(
          name: 'Groceries',
          amountText: '\$84.12',
          removeLabel: 'Remove Groceries',
          dotColor: context.tokens.isDark
              ? ColorTokensDark.dataCategoryGroceries
              : ColorTokensLight.dataCategoryGroceries,
          onAmountTap: () {},
          onRemove: () {},
        ),
        SplitPart(
          name: 'Household',
          amountText: '\$25.00',
          removeLabel: 'Remove Household',
          dotColor: context.tokens.isDark
              ? ColorTokensDark.dataCategoryOther
              : ColorTokensLight.dataCategoryOther,
          onAmountTap: () {},
          onRemove: () {},
        ),
        SplitPart(
          name: 'Gifts',
          amountText: '\$12.18',
          removeLabel: 'Remove Gifts',
          dotColor: context.tokens.isDark
              ? ColorTokensDark.dataCategoryFun
              : ColorTokensLight.dataCategoryFun,
          onAmountTap: () {},
          onRemove: () {},
        ),
      ],
      addLabel: 'Add a part',
      onAdd: () {},
      leftLabel: 'Left to split',
      leftValue: MoneyText(
        ValueSpec.real(Money.fromMinor(0, Currency.usd)),
        style: AppText.numberXS.copyWith(color: context.tokens.textPrimary),
      ),
    );
  }
}

class _ConfirmDemo extends StatelessWidget {
  const _ConfirmDemo();

  @override
  Widget build(BuildContext context) {
    return ConfirmBar(
      label: 'Confirm 8 ticked, \$412.36',
      onPressed: () {},
    );
  }
}

class _ToastDemo extends StatelessWidget {
  const _ToastDemo();

  @override
  Widget build(BuildContext context) {
    return AppToast(
      message: 'Payment saved',
      undoLabel: 'Undo',
      onUndo: () {},
    );
  }
}

class _UndoDemo extends StatelessWidget {
  const _UndoDemo();

  @override
  Widget build(BuildContext context) {
    return UndoBar(
      message: 'Payment deleted',
      undoLabel: 'Undo',
      onUndo: () {},
      semanticLabel: 'Payment deleted. Undo',
    );
  }
}

class _DialogDemo extends StatelessWidget {
  const _DialogDemo();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceSheet,
        borderRadius: BorderRadius.circular(RadiusTokens.sheet),
        border: Border.all(color: tokens.surfaceGlassEdge),
      ),
      child: const AppDialog(
        title: 'Delete this payment?',
        body: 'The payment and its split are removed from every total.',
        primaryLabel: 'Delete payment',
        onPrimary: _noop,
        secondaryLabel: 'Cancel',
        onSecondary: _noop,
        semanticLabel: 'Delete this payment?',
      ),
    );
  }
}

class _SheetDemo extends StatelessWidget {
  const _SheetDemo();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      width: 360,
      height: 380,
      child: AppSheet(
        title: 'Details',
        semanticLabel: 'Date, account, currency',
        footer: const ConfirmBar(
          label: 'Done',
          onPressed: _noop,
        ),
        children: <Widget>[
          PillPicker(
            label: 'Today',
            semanticLabel: 'Date: today',
            onPressed: () {},
          ),
          Text(
            'A sheet fits its content up to 90% of the screen.',
            style: AppText.line.copyWith(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ShellDemo extends StatelessWidget {
  const _ShellDemo();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surfacePage,
            border: Border.all(color: tokens.borderChip),
            borderRadius: BorderRadius.circular(RadiusTokens.card),
          ),
          child: TabShell(
            tabBar: AppTabBar(
              items: const <AppTabItem>[
                AppTabItem(
                  section: Section.home,
                  label: 'Home',
                  semanticLabel: 'Home',
                  icon: AppIcons.house,
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
              ],
              selected: Section.home,
              onSelect: (_) {},
              onAdd: _noop,
              addSemanticLabel: 'Add',
            ),
            child: Center(
              child: Text(
                'Tab screen',
                style: AppText.body.copyWith(color: tokens.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _noop() {}
