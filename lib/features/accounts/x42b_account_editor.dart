// P21 (SPEC 6.6; flow C01; SCREENS X42b reference): the minimal account
// editor for a bank account, cash or credit card with an inclusive opening
// balance.
//
// The screen is presentation only: it reads one controller, calls its
// setters, and returns the saved account to the caller. It writes nothing
// before Save and keeps every entry after a failure (SPEC 8.16).
library;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'account_date_sheet.dart';
import 'account_draft.dart';
import 'account_models.dart';
import 'account_setup_controller.dart';

/// SPEC 6.6, flow C01: the account editor. Amount first, then one required
/// type choice, the name and the flags.
class X42bAccountEditor extends StatefulWidget {
  const X42bAccountEditor({
    required this.gateway,
    required this.onClose,
    required this.onSaved,
    this.today,
    this.controller,
    this.drafts,
    this.kind,
    super.key,
  });

  final AccountsGateway gateway;

  /// Close (X): writes nothing.
  final VoidCallback onClose;

  /// Save success: returns the new account to the caller, selected.
  final ValueChanged<AccountSummary> onSaved;

  /// The local date for the default inclusive anchor.
  final LocalDate? today;

  /// Test and golden seam: a prepared draft. The caller owns it.
  final AccountSetupController? controller;

  /// The durable draft store. Null keeps the form in memory only.
  final AccountDraftStore? drafts;

  /// X42: a type chosen on the previous step. Null shows the three choices.
  final AccountKind? kind;

  @override
  State<X42bAccountEditor> createState() => _X42bAccountEditorState();
}

class _X42bAccountEditorState extends State<X42bAccountEditor> {
  late final LocalDate _today = widget.today ?? _localToday();
  late final AccountSetupController _controller = widget.controller ??
      AccountSetupController(
        gateway: widget.gateway,
        today: _today,
        drafts: widget.drafts,
      );
  late final TextEditingController _nameField =
      TextEditingController(text: _controller.name);

  static const List<String> _currencies = <String>[
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'INR',
    'TWD',
  ];

  @override
  void initState() {
    super.initState();
    final fixed = widget.kind;
    if (fixed != null && _controller.kind == null) {
      _controller.setKind(fixed);
    }
    if (_controller.drafts != null) {
      _controller.loadDraft().then((_) {
        if (!mounted) {
          return;
        }
        _nameField.text = _controller.name;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _nameField.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final role = tokens.role(context.section);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final amount = _controller.openingAmount;
        final kind = widget.kind ?? _controller.kind;
        final isCard = kind == AccountKind.card;
        return FormScreen(
          close: AppIconButton(
            icon: AppIcons.close,
            variant: AppIconButtonVariant.onPage,
            semanticLabel: l.accountClose,
            onPressed: widget.onClose,
          ),
          primaryAction: AppButton(
            label: l.accountSave,
            onPressed: _controller.canSave ? _save : null,
          ),
          children: <Widget>[
            Text(
              l.accountKicker.toUpperCase(),
              style: AppText.labelCaps.copyWith(color: role.text),
              semanticsLabel: l.accountKicker,
            ),
            Text(l.accountTitle, style: AppText.titleScreen),
            _amountBlock(context, l, amount, isCard),
            _detailsBlock(context, l, kind),
            if (isCard)
              Text(
                l.accountCardLimitUnavailable,
                style: AppText.caption.copyWith(color: tokens.textSecondary),
              ),
            _dateBlock(context, l),
            if (_controller.status == AccountSetupStatus.failed)
              Text(
                _controller.errorCode == AccountsErrorCode.notWired
                    ? l.accountUnavailable
                    : l.accountSaveFailed,
                style: AppText.caption.copyWith(color: tokens.textSecondary),
              ),
            if (_controller.draftUnsupported) ...<Widget>[
              const VSpace(Space.s),
              Text(
                l.accountDraftUnsupported,
                style: AppText.caption.copyWith(color: tokens.textSecondary),
              ),
            ],
            if (_controller.hasDraft) ...<Widget>[
              const VSpace(Space.l),
              AppButton(
                label: l.accountDraftDiscard,
                variant: AppButtonVariant.ghost,
                onPressed: _discardDraft,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _amountBlock(
    BuildContext context,
    AppLocalizations l,
    Money? amount,
    bool isCard,
  ) {
    final tokens = context.tokens;
    return GlassCard(
      title: l.accountBalanceLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AmountInput(
            value: amount == null ? null : ValueSpec.real(amount),
            emptyText: l.accountBalanceMissing,
            emptySemanticLabel: l.accountBalanceMissingSpoken,
          ),
          if (isCard && amount != null) ...<Widget>[
            const VSpace(Space.xs),
            MoneyText(
              ValueSpec.real(amount),
              prefix: '${l.accountOwes} ',
              style: AppText.numberM.copyWith(color: tokens.textPrimary),
            ),
          ],
          const VSpace(Space.s),
          Keypad(
            onDigit: _controller.pressKey,
            onDelete: _controller.deleteKey,
            deleteLabel: l.accountDelete,
            decimalLabel: l.accountDecimal,
          ),
        ],
      ),
    );
  }

  Widget _detailsBlock(
    BuildContext context,
    AppLocalizations l,
    AccountKind? kind,
  ) {
    return GlassCard(
      title: l.accountCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppField(
            label: l.accountNameLabel,
            semanticLabel: l.accountNameSemantic,
            hint: l.accountNameHint,
            controller: _nameField,
            textInputAction: TextInputAction.next,
            onChanged: _controller.setName,
          ),
          if (widget.kind == null) ...<Widget>[
            const VSpace(Space.l),
            Text(
              l.accountTypeLabel,
              style: AppText.captionStrong.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
            const VSpace(Space.xs),
            ChipRow(
              items: <ChipItem>[
                _typeChip(l, l.accountTypeBank, AccountKind.bank, kind),
                _typeChip(l, l.accountTypeCash, AccountKind.cash, kind),
                _typeChip(l, l.accountTypeCard, AccountKind.card, kind),
              ],
            ),
          ],
          const VSpace(Space.l),
          Align(
            alignment: Alignment.centerLeft,
            child: PillPicker(
              label: _controller.currencyCode,
              semanticLabel: l.accountCurrencySemantic(
                _controller.currencyCode,
              ),
              onPressed: () => _chooseCurrency(context),
            ),
          ),
          ToggleRow(
            name: l.accountCashToggle,
            description:
                _controller.countsAsCash ? l.accountCashOn : l.accountCashOff,
            value: _controller.countsAsCash,
            semanticLabel: l.accountCashToggle,
            onChanged: _controller.setCountsAsCash,
          ),
          ToggleRow(
            name: l.accountNetWorthToggle,
            description: _controller.includeInNetWorth
                ? l.accountNetWorthOn
                : l.accountNetWorthOff,
            value: _controller.includeInNetWorth,
            semanticLabel: l.accountNetWorthToggle,
            onChanged: _controller.setIncludeInNetWorth,
          ),
        ],
      ),
    );
  }

  ChipItem _typeChip(
    AppLocalizations l,
    String label,
    AccountKind kind,
    AccountKind? selected,
  ) {
    return ChipItem(
      label: label,
      semanticLabel: l.accountTypeSemantic(label),
      variant: ChipVariant.choice,
      selected: selected == kind,
      onPressed: () => _controller.setKind(kind),
    );
  }

  Widget _dateBlock(BuildContext context, AppLocalizations l) {
    final tokens = context.tokens;
    return SelectRow(
      name: l.accountDateLabel,
      line: l.accountDateHelper,
      semanticLabel: l.accountDateLabel,
      trailing: DateText(
        _controller.openingDate,
        style: DateStyle.monthYear,
        styleText: AppText.numberXS.copyWith(color: tokens.textPrimary),
      ),
      onTap: () async {
        final selected = await showAccountDateSheet(
          context,
          initial: _controller.openingDate,
        );
        if (selected != null) {
          _controller.setDate(selected);
        }
      },
    );
  }

  Future<void> _chooseCurrency(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final selected = await showAppSheet<String>(
      context,
      title: l.accountCurrencyTitle,
      semanticLabel: l.accountCurrencySpoken,
      children: <Widget>[
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: <Widget>[
            for (final code in _currencies)
              PillPicker(
                label: code,
                semanticLabel: l.accountCurrencySemantic(code),
                selected: code == _controller.currencyCode,
                onPressed: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      ],
    );
    if (selected != null) {
      _controller.setCurrency(selected);
    }
  }

  Future<void> _discardDraft() async {
    await _controller.discardDraft();
    widget.onClose();
  }

  Future<void> _save() async {
    final account = await _controller.save();
    if (account != null) {
      widget.onSaved(account);
    }
  }
}

/// The local calendar date from the wall clock. The controller receives it,
/// so the domain and the tests never read a clock directly (AGENTS 6.3).
LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
