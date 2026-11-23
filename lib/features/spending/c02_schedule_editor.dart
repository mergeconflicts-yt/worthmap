// P28 (SCREEN C02; flow F09 step 2; SPEC 8.17, 5.5): the schedule editor.
//
// Explicit repeating choice: name, amount, frequency, first payment and
// account. Save writes a schedule only; no occurrence and no payment
// (F09-A). A one-off future payment uses the X20 form with the Expected state.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import '../accounts/account_date_sheet.dart';
import 'repeating_models.dart';

/// C02: the schedule form.
class C02ScheduleEditor extends StatefulWidget {
  const C02ScheduleEditor({
    required this.gateway,
    required this.onClose,
    required this.onSaved,
    this.today,
    this.accounts,
    super.key,
  });

  final RepeatingGateway gateway;
  final VoidCallback onClose;
  final VoidCallback onSaved;
  final LocalDate? today;
  final List<NamedOption>? accounts;

  @override
  State<C02ScheduleEditor> createState() => _C02ScheduleEditorState();
}

class _C02ScheduleEditorState extends State<C02ScheduleEditor> {
  late final LocalDate _today = widget.today ?? _localToday();
  late final TextEditingController _name = TextEditingController();
  String _amountText = '';
  RepeatFrequency _frequency = RepeatFrequency.monthly;
  late LocalDate _start = _today;
  List<NamedOption> _accounts = const <NamedOption>[];
  NamedOption? _account;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final prepared = widget.accounts;
    if (prepared != null) {
      setState(() {
        _accounts = prepared;
        _account = prepared.isEmpty ? null : prepared.first;
      });
      return;
    }
    try {
      final options = await widget.gateway.accountOptions();
      if (mounted) {
        setState(() {
          _accounts = options;
          _account = options.isEmpty ? null : options.first;
        });
      }
    } on Object {
      // Save stays disabled without an account.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Money? get _amount {
    if (_amountText.isEmpty || _amountText == '.') {
      return null;
    }
    try {
      return Money.fromDecimal(Decimal.parse(_amountText), Currency.usd);
    } on Object {
      return null;
    }
  }

  bool get _canSave =>
      !_saving &&
      _name.text.trim().isNotEmpty &&
      (_amount?.minor ?? 0) > 0 &&
      _account != null;

  void _press(String key) {
    setState(() {
      if (key == '.') {
        if (_amountText.contains('.')) {
          return;
        }
        _amountText = _amountText.isEmpty ? '0.' : '$_amountText.';
        return;
      }
      if (!RegExp(r'^\d$').hasMatch(key)) {
        return;
      }
      final point = _amountText.indexOf('.');
      if (point >= 0 && _amountText.length - point - 1 >= 2) {
        return;
      }
      _amountText = _amountText == '0' ? key : '$_amountText$key';
    });
  }

  void _delete() {
    setState(() {
      if (_amountText.isNotEmpty) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) {
      setState(() => _failed = true);
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.gateway.saveSchedule(
        ScheduleDraft(
          name: _name.text.trim(),
          amountMinor: _amount!.minor,
          currencyCode: 'USD',
          frequency: _frequency,
          startDate: _start,
          accountId: _account!.id,
        ),
      );
      if (mounted) {
        widget.onSaved();
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    return FormScreen(
      close: AppIconButton(
        icon: AppIcons.close,
        semanticLabel: l.paymentsClose,
        onPressed: widget.onClose,
      ),
      primaryAction: AppButton(
        label: l.c02Save,
        onPressed: _save,
      ),
      children: <Widget>[
        Text(l.c02Title, style: AppText.titleScreen),
        AppField(
          label: l.c02Name,
          semanticLabel: l.c02Name,
          hint: l.c02NameHint,
          controller: _name,
          onChanged: (_) => setState(() {}),
        ),
        AmountInput(
          value: _amount == null ? null : ValueSpec.real(_amount!),
          emptyText: formatMoney(Money.zero(Currency.usd)),
          emptySemanticLabel: l.c02AmountNotFilled,
        ),
        Text(
          l.c02Frequency,
          style: AppText.labelCaps.copyWith(color: tokens.textSecondary),
        ),
        ChipRow(
          items: <ChipItem>[
            for (final frequency in RepeatFrequency.values)
              ChipItem(
                label: switch (frequency) {
                  RepeatFrequency.weekly => l.c02Weekly,
                  RepeatFrequency.monthly => l.c02Monthly,
                  RepeatFrequency.yearly => l.c02Yearly,
                },
                semanticLabel: switch (frequency) {
                  RepeatFrequency.weekly => l.c02Weekly,
                  RepeatFrequency.monthly => l.c02Monthly,
                  RepeatFrequency.yearly => l.c02Yearly,
                },
                variant: ChipVariant.choice,
                selected: _frequency == frequency,
                onPressed: () => setState(() => _frequency = frequency),
              ),
          ],
        ),
        Keypad(
          onDigit: _press,
          onDelete: _delete,
          deleteLabel: l.spendingDeleteKey,
          decimalLabel: l.spendingDecimal,
        ),
        GlassCard(
          child: Column(
            children: <Widget>[
              SelectRow(
                name: l.c02Start,
                value: formatDate(_start, DateStyle.monthYear),
                onTap: _pickDate,
                semanticLabel: l.c02Start,
              ),
              SelectRow(
                name: l.c02Account,
                value: _account?.name ?? l.c02ChooseAccount,
                onTap: _pickAccount,
                semanticLabel: l.c02Account,
              ),
            ],
          ),
        ),
        if (_failed)
          Text(
            l.c02Invalid,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final chosen = await showAccountDateSheet(
      context,
      initial: _start,
      title: AppLocalizations.of(context).c02Start,
    );
    if (chosen != null && mounted) {
      setState(() => _start = chosen);
    }
  }

  Future<void> _pickAccount() async {
    final l = AppLocalizations.of(context);
    final chosen = await showAppSheet<NamedOption>(
      context,
      title: l.c02Account,
      semanticLabel: l.c02Account,
      children: <Widget>[
        for (final account in _accounts)
          SelectRow(
            name: account.name,
            onTap: () => Navigator.of(context).pop(account),
            semanticLabel: account.name,
          ),
      ],
    );
    if (chosen != null && mounted) {
      setState(() => _account = chosen);
    }
  }
}

LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
