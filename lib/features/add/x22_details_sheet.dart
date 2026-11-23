// P22 (SCREENS X22; flow F03 step 3; SPEC 8.16): the details sheet.
//
// The sheet edits a copy. Done returns every field to the X20 draft; Back or
// Close discards only this sheet's edits (shared contract 3). Nothing is
// written here.
library;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import '../accounts/account_models.dart';
import '../accounts/account_picker_sheet.dart';
import 'payment_models.dart';

/// The values X22 edits as a copy of the X20 draft.
final class PaymentDetails {
  const PaymentDetails({
    required this.date,
    required this.currencyCode,
    required this.account,
    required this.tagIds,
  });

  final LocalDate date;
  final String currencyCode;
  final AccountSummary? account;
  final List<String> tagIds;
}

/// The currencies the form offers. English v1 ships this small set (C01
/// precedent); the ISO table itself lives in `lib/core`.
const List<String> kPaymentCurrencies = <String>[
  'USD',
  'EUR',
  'GBP',
  'JPY',
  'INR',
  'TWD',
];

/// X22: date chips, the month grid, Paid with, Currency and Tags.
class X22DetailsSheet extends StatefulWidget {
  const X22DetailsSheet({
    required this.initial,
    required this.today,
    required this.accounts,
    required this.tags,
    required this.onDone,
    this.onAddAccount,
    super.key,
  });

  final PaymentDetails initial;

  /// The local today. A later day is not selectable.
  final LocalDate today;
  final List<AccountSummary> accounts;
  final List<TagSummary> tags;
  final ValueChanged<PaymentDetails> onDone;

  /// Opens C01 when the account editor is reachable. The created account is
  /// added to the list and selected.
  final Future<AccountSummary?> Function()? onAddAccount;

  @override
  State<X22DetailsSheet> createState() => _X22DetailsSheetState();
}

class _X22DetailsSheetState extends State<X22DetailsSheet> {
  late LocalDate _date = widget.initial.date;
  late String _currency = widget.initial.currencyCode;
  late AccountSummary? _account = widget.initial.account;
  late final Set<String> _tagIds = <String>{...widget.initial.tagIds};
  late final List<AccountSummary> _accounts = <AccountSummary>[
    ...widget.accounts,
  ];
  late LocalDate _month = LocalDate(_date.year, _date.month, 1);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ChipRow(
          items: <ChipItem>[
            _dayChip(l, l.paymentDateToday, widget.today),
            _dayChip(l, l.paymentDateYesterday, _shift(widget.today, -1)),
            _dayChip(l, l.paymentDateTwoDaysAgo, _shift(widget.today, -2)),
          ],
        ),
        const VSpace(Space.l),
        GlassCard(
          title: _monthTitle(l, _month),
          meta: l.paymentTodayMeta(
            formatDate(widget.today, DateStyle.short),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AppIconButton(
                    icon: AppIcons.back,
                    semanticLabel: l.paymentMonthPrevious,
                    onPressed: () => _stepMonth(-1),
                  ),
                  const Spacer(),
                  AppIconButton(
                    icon: AppIcons.chevronRight,
                    semanticLabel: l.paymentMonthNext,
                    onPressed: _canStepForward() ? () => _stepMonth(1) : null,
                  ),
                ],
              ),
              const VSpace(Space.xs),
              _monthGrid(l),
            ],
          ),
        ),
        const VSpace(Space.l),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SelectRow(
                name: l.paymentPaidWith,
                trailing: Text(
                  _account?.name ?? l.paymentChooseAccount,
                  style: AppText.bodyS.copyWith(color: tokens.textPrimary),
                ),
                semanticLabel: l.paymentPaidWithSpoken(
                  _account?.name ?? l.paymentChooseAccount,
                ),
                onTap: _chooseAccount,
              ),
              SelectRow(
                name: l.paymentCurrencyLabel,
                trailing: Text(
                  _currency,
                  style: AppText.bodyS.copyWith(color: tokens.textPrimary),
                ),
                semanticLabel: l.paymentCurrencySpoken(_currency),
                onTap: _chooseCurrency,
              ),
              SelectRow(
                name: l.paymentTagsLabel,
                trailing: Text(
                  _tagsText(l),
                  style: AppText.bodyS.copyWith(color: tokens.textPrimary),
                ),
                semanticLabel: l.paymentTagsSpoken(_tagsText(l)),
                onTap: _chooseTags,
              ),
            ],
          ),
        ),
        const VSpace(Space.xl),
        AppButton(label: l.paymentDone, onPressed: _done),
      ],
    );
  }

  ChipItem _dayChip(AppLocalizations l, String label, LocalDate day) {
    return ChipItem(
      label: label,
      semanticLabel: l.paymentDateChipSpoken(
        label,
        formatDate(day, DateStyle.monthYear),
      ),
      variant: ChipVariant.choice,
      selected: _date == day,
      onPressed: () => _setDate(day),
    );
  }

  Widget _monthGrid(AppLocalizations l) {
    final tokens = context.tokens;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final letters = <String>[
      l.paymentWeekdayMon,
      l.paymentWeekdayTue,
      l.paymentWeekdayWed,
      l.paymentWeekdayThu,
      l.paymentWeekdayFri,
      l.paymentWeekdaySat,
      l.paymentWeekdaySun,
    ];
    final days = LocalDate.daysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime.utc(_month.year, _month.month).weekday;
    final leading = firstWeekday - 1;
    final cells = <Widget>[
      for (final letter in letters)
        SizedBox(
          height: Space.l,
          child: Center(
            child: Text(
              letter,
              style: AppText.weekday.copyWith(color: tokens.textSecondary),
            ),
          ),
        ),
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= days; day++)
        _dayCell(
          l,
          LocalDate(_month.year, _month.month, day),
          compact: scale > 1.3,
        ),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Space.xs,
      crossAxisSpacing: Space.xs,
      childAspectRatio: scale > 1.3 ? 0.8 : 1,
      children: cells,
    );
  }

  Widget _dayCell(
    AppLocalizations l,
    LocalDate day, {
    required bool compact,
  }) {
    final future = day.compareTo(widget.today) > 0;
    final isToday = day == widget.today;
    final spoken = isToday
        ? l.paymentDayToday(formatDate(day, DateStyle.long))
        : l.paymentDaySpoken(formatDate(day, DateStyle.long));
    return DayCell(
      day: day.day,
      semanticLabel: spoken,
      selected: day == _date,
      enabled: !future,
      isToday: isToday,
      compact: compact,
      onPressed: () => _setDate(day),
    );
  }

  String _monthTitle(AppLocalizations l, LocalDate month) {
    final names = <String>[
      l.paymentMonthJanuary,
      l.paymentMonthFebruary,
      l.paymentMonthMarch,
      l.paymentMonthApril,
      l.paymentMonthMay,
      l.paymentMonthJune,
      l.paymentMonthJuly,
      l.paymentMonthAugust,
      l.paymentMonthSeptember,
      l.paymentMonthOctober,
      l.paymentMonthNovember,
      l.paymentMonthDecember,
    ];
    return '${names[month.month - 1]} ${month.year}';
  }

  String _tagsText(AppLocalizations l) {
    if (_tagIds.isEmpty) {
      return l.paymentTagsNone;
    }
    return l.paymentTagsCount(_tagIds.length);
  }

  void _setDate(LocalDate day) {
    setState(() {
      _date = day;
      _month = LocalDate(day.year, day.month, 1);
    });
  }

  bool _canStepForward() {
    final current = LocalDate(widget.today.year, widget.today.month, 1);
    return _month.compareTo(current) < 0;
  }

  void _stepMonth(int delta) {
    final month = DateTime.utc(_month.year, _month.month + delta);
    setState(() => _month = LocalDate(month.year, month.month, 1));
  }

  Future<void> _chooseAccount() async {
    final chosen = await showAccountPicker(
      context,
      accounts: _accounts,
      onAdd: widget.onAddAccount == null
          ? null
          : () async {
              final created = await widget.onAddAccount!.call();
              if (created != null && mounted) {
                setState(() {
                  if (!_accounts.any((row) => row.id == created.id)) {
                    _accounts.add(created);
                  }
                  _account = created;
                });
              }
            },
    );
    if (chosen != null && mounted) {
      setState(() => _account = chosen);
    }
  }

  Future<void> _chooseCurrency() async {
    final l = AppLocalizations.of(context);
    final chosen = await showAppSheet<String>(
      context,
      title: l.paymentCurrencyLabel,
      semanticLabel: l.paymentCurrencySheetSpoken,
      children: <Widget>[
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: <Widget>[
            for (final code in kPaymentCurrencies)
              PillPicker(
                label: code,
                semanticLabel: l.paymentCurrencySpoken(code),
                selected: code == _currency,
                onPressed: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      ],
    );
    if (chosen != null && mounted) {
      setState(() => _currency = chosen);
    }
  }

  Future<void> _chooseTags() async {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    if (widget.tags.isEmpty) {
      await showAppSheet<void>(
        context,
        title: l.paymentTagsLabel,
        semanticLabel: l.paymentTagsLabel,
        children: <Widget>[
          Text(
            l.paymentTagsEmpty,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          ),
        ],
      );
      return;
    }
    final chosen = await showAppSheet<Set<String>>(
      context,
      title: l.paymentTagsLabel,
      semanticLabel: l.paymentTagsLabel,
      children: <Widget>[
        _TagChooser(
          tags: widget.tags,
          selected: _tagIds,
        ),
      ],
    );
    if (chosen != null && mounted) {
      setState(() {
        _tagIds
          ..clear()
          ..addAll(chosen);
      });
    }
  }

  void _done() {
    widget.onDone(
      PaymentDetails(
        date: _date,
        currencyCode: _currency,
        account: _account,
        tagIds: _tagIds.toList(growable: false),
      ),
    );
  }
}

class _TagChooser extends StatefulWidget {
  const _TagChooser({required this.tags, required this.selected});

  final List<TagSummary> tags;
  final Set<String> selected;

  @override
  State<_TagChooser> createState() => _TagChooserState();
}

class _TagChooserState extends State<_TagChooser> {
  late final Set<String> _chosen = <String>{...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final tag in widget.tags)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  tag.name,
                  style: AppText.body.copyWith(color: tokens.textPrimary),
                ),
              ),
              AppCheckbox(
                value: _chosen.contains(tag.id),
                semanticLabel: tag.name,
                onChanged: (value) => setState(() {
                  if (value) {
                    _chosen.add(tag.id);
                  } else {
                    _chosen.remove(tag.id);
                  }
                }),
              ),
            ],
          ),
        const VSpace(Space.l),
        AppButton(
          label: l.paymentDone,
          onPressed: () => Navigator.of(context).pop(_chosen),
        ),
      ],
    );
  }
}

LocalDate _shift(LocalDate date, int days) {
  final shifted = DateTime.utc(date.year, date.month, date.day + days);
  return LocalDate(shifted.year, shifted.month, shifted.day);
}

/// Opens X22 and returns the edited details, or null when dismissed.
Future<PaymentDetails?> showDetailsSheet(
  BuildContext context, {
  required PaymentDetails initial,
  required LocalDate today,
  required List<AccountSummary> accounts,
  required List<TagSummary> tags,
  Future<AccountSummary?> Function()? onAddAccount,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<PaymentDetails>(
    context,
    title: l.paymentDetailsSheetTitle,
    semanticLabel: l.paymentDetailsSheetSpoken,
    children: <Widget>[
      X22DetailsSheet(
        initial: initial,
        today: today,
        accounts: accounts,
        tags: tags,
        onAddAccount: onAddAccount,
        onDone: (details) => Navigator.of(context).pop(details),
      ),
    ],
  );
}
