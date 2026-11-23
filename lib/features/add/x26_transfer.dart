// P23 (SCREENS X26; flow F05 steps 1–2; SPEC 4.2, 4.10, 6.3): the transfer
// form between two owned accounts.
//
// The screen is presentation only: it reads one controller, calls its setters
// and returns the saved transfer to the caller with Undo (SPEC 8.18). It writes
// nothing before Save and keeps every entry after a failure. The principal is
// neither spending nor income, and the caption states that fact (SPEC 2, 4.2).
//
// X26 has no fee field in Phase 2 (DECISIONS CLOSED-G13-TRANSFER-FEES): a
// charged fee enters from a captured or imported record. Cross-currency is
// X26b and stays v1.1.
library;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import '../accounts/account_date_sheet.dart';
import '../accounts/account_models.dart';
import '../accounts/account_picker_sheet.dart';
import 'payment_models.dart';
import 'transfer_draft.dart';
import 'transfer_form_controller.dart';
import 'transfer_models.dart';

/// X26: type switch (Transfer selected), amount, From/To/Date rows, caption,
/// keypad and "Save transfer".
class X26Transfer extends StatefulWidget {
  const X26Transfer({
    required this.gateway,
    required this.onClose,
    required this.onSaved,
    this.onSwitchType,
    this.today,
    this.controller,
    this.drafts,
    this.showToast = true,
    super.key,
  });

  final TransferGateway gateway;

  /// Close (X): keeps the draft, writes no transfer.
  final VoidCallback onClose;

  /// Save success: returns to the caller with the confirmed transfer.
  final ValueChanged<SavedTransfer> onSaved;

  /// The type switch returns to the expense or income form. Absent keeps the
  /// switch on Transfer only.
  final ValueChanged<PaymentKind>? onSwitchType;

  /// The local date for the default transfer date.
  final LocalDate? today;

  /// Test and golden seam: a prepared controller. The caller owns it.
  final TransferFormController? controller;

  /// The durable draft store. Null keeps the form in memory only.
  final TransferDraftStore? drafts;

  /// Shows the 5 s toast with Undo after a confirmed write.
  final bool showToast;

  @override
  State<X26Transfer> createState() => _X26TransferState();
}

class _X26TransferState extends State<X26Transfer> {
  late final LocalDate _today = widget.today ?? _localToday();
  late final TransferFormController _controller = widget.controller ??
      TransferFormController(
        gateway: widget.gateway,
        today: _today,
        drafts: widget.drafts,
      );

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
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
    final kicker =
        l.transferKicker(formatDate(_controller.date, DateStyle.short));

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final amount = _controller.enteredAmount;
        final segments = <String>[
          l.paymentTypeExpense,
          l.paymentTypeIncome,
          l.paymentTypeTransfer,
        ];
        return FormScreen(
          close: AppIconButton(
            icon: AppIcons.close,
            semanticLabel: l.transferClose,
            onPressed: widget.onClose,
          ),
          primaryAction: AppButton(
            label: amount == null
                ? l.transferSave
                : l.transferSaveWithAmount(
                    HiddenAmountsScope.resolve(context, null)
                        ? hiddenMask
                        : formatMoney(
                            Money.fromMinor(
                              amount.minor,
                              amount.currency,
                            ),
                          ),
                  ),
            onPressed: _controller.canSave ? _save : null,
          ),
          children: <Widget>[
            SegmentedControl(
              segments: segments,
              selectedIndex: 2,
              semanticLabel: l.paymentTypeLabel,
              onChanged: (index) {
                if (index == 2) {
                  return;
                }
                widget.onSwitchType?.call(
                  index == 0 ? PaymentKind.expense : PaymentKind.income,
                );
              },
            ),
            Text(
              kicker.toUpperCase(),
              style: AppText.labelCaps.copyWith(color: role.text),
              semanticsLabel: kicker,
            ),
            AmountInput(
              value: amount == null
                  ? null
                  : ValueSpec.real(
                      Money.fromMinor(amount.minor, amount.currency),
                    ),
              emptyText: formatMoney(Money.zero(_controller.currency)),
              emptySemanticLabel: l.transferAmountNotFilled,
            ),
            _accountsCard(context, l),
            Text(
              l.transferCaption,
              style: AppText.caption.copyWith(color: tokens.textSecondary),
            ),
            Keypad(
              onDigit: _controller.pressKey,
              onDelete: _controller.deleteKey,
              deleteLabel: l.paymentDelete,
              decimalLabel: l.paymentDecimal,
            ),
            _statusLine(l),
            if (_controller.hasDraft) ...<Widget>[
              const VSpace(Space.l),
              AppButton(
                label: l.transferDraftDiscard,
                variant: AppButtonVariant.ghost,
                onPressed: _discardDraft,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _accountsCard(BuildContext context, AppLocalizations l) {
    return GlassCard(
      child: Column(
        children: <Widget>[
          _accountRow(
            context,
            l,
            label: l.transferFrom,
            account: _controller.from,
            onTap: () => _pickAccount(from: true),
          ),
          _accountRow(
            context,
            l,
            label: l.transferTo,
            account: _controller.to,
            onTap: () => _pickAccount(from: false),
          ),
          SelectRow(
            name: l.transferDate,
            value: formatDate(_controller.date, DateStyle.short),
            onTap: _pickDate,
            semanticLabel: l.transferDateSpoken(
              formatDate(_controller.date, DateStyle.short),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow(
    BuildContext context,
    AppLocalizations l, {
    required String label,
    required AccountSummary? account,
    required VoidCallback onTap,
  }) {
    final money = account?.balance;
    final owes = account?.owes ?? false;
    // DESIGN reflow rule: at large text the 40 pt badge yields its width to
    // the name and the balance (the account picker keeps its meaning without
    // the decorative tile).
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return SelectRow(
      name: account?.name ?? l.transferChooseAccount,
      line: label,
      leading: account == null || largeText
          ? null
          : IconTile(
              icon: account.kind == AccountKind.card
                  ? AppIcons.card
                  : AppIcons.bank,
            ),
      trailing: money == null
          ? null
          : MoneyText(
              ValueSpec.real(owes ? -money : money),
              prefix: owes ? '${l.accountOwes} ' : null,
              style: AppText.numberXS.copyWith(
                color: context.tokens.textPrimary,
              ),
            ),
      onTap: onTap,
      semanticLabel: l.transferAccountSpoken(
        label,
        account?.name ?? l.transferChooseAccount,
      ),
    );
  }

  Widget _statusLine(AppLocalizations l) {
    final tokens = context.tokens;
    final style = AppText.caption.copyWith(color: tokens.textSecondary);
    if (_controller.draftUnsupported) {
      return Text(l.transferDraftUnsupported, style: style);
    }
    if (_controller.status == TransferFormStatus.failed) {
      final message = switch (_controller.errorCode) {
        TransferErrorCode.notWired => l.transferUnavailable,
        TransferErrorCode.invalidTransfer => l.transferInvalid,
        _ => l.transferSaveFailed,
      };
      return Text(message, style: style);
    }
    if (_controller.sameAccount) {
      return Text(l.transferSameAccount, style: style);
    }
    if (_controller.crossCurrency) {
      return Text(l.transferCrossCurrency, style: style);
    }
    if (_controller.loaded && _controller.accounts.isEmpty) {
      return Text(l.transferNoAccount, style: style);
    }
    return const SizedBox.shrink();
  }

  Future<void> _pickAccount({required bool from}) async {
    _controller.commitAmount();
    final account = await showAccountPicker(
      context,
      accounts: _controller.accounts,
    );
    if (account == null || !mounted) {
      return;
    }
    if (from) {
      _controller.selectFrom(account);
    } else {
      _controller.selectTo(account);
    }
  }

  Future<void> _pickDate() async {
    _controller.commitAmount();
    final date = await showAccountDateSheet(
      context,
      initial: _controller.date,
      title: AppLocalizations.of(context).transferDate,
    );
    if (date == null || !mounted) {
      return;
    }
    _controller.setDate(date);
  }

  Future<void> _discardDraft() async {
    await _controller.discardDraft();
    widget.onClose();
  }

  Future<void> _save() async {
    _controller.commitAmount();
    final saved = await _controller.save();
    if (saved == null || !mounted) {
      return;
    }
    if (widget.showToast) {
      final l = AppLocalizations.of(context);
      showAppToast(
        context,
        message: l.transferSavedToast,
        undoLabel: l.transferUndo,
        onUndo: () => _controller.undo(saved),
      );
    }
    widget.onSaved(saved);
  }
}

/// The local calendar date from the wall clock. The controller receives it.
LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
