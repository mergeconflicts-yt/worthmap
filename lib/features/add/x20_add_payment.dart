// P22 (SCREENS X20; flow F03 steps 1–6; SPEC 3.1, 3.2, 8.3): the amount-first
// expense and income form.
//
// The screen is presentation only: it reads one controller, calls its setters
// and returns the saved payment to the caller with Undo (SPEC 8.18). It writes
// nothing before Save (F03-C) and keeps every entry after a failure.
//
// The four capture buttons of the reference (Speak, Scan QR, Receipt photo,
// Import a file) appear only when the caller supplies their handler. An
// unreleased capture source is absent from navigation (SPEC 5.5); P24 passes
// the Speak handler.
library;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import '../accounts/account_models.dart';
import 'payment_category_style.dart';
import 'payment_draft.dart';
import 'payment_form_controller.dart';
import 'payment_models.dart';
import 'x21_category_sheet.dart';
import 'x22_details_sheet.dart';
import 'x23_split_screen.dart';

/// X20: type switch, amount, pills, merchant, category chips, keypad, Save.
class X20AddPayment extends StatefulWidget {
  const X20AddPayment({
    required this.gateway,
    required this.onClose,
    required this.onSaved,
    this.today,
    this.controller,
    this.drafts,
    this.editing,
    this.initialKind = PaymentKind.expense,
    this.onAddAccount,
    this.onSpeak,
    this.onScanQr,
    this.onReceiptPhoto,
    this.onImportFile,
    this.onTransfer,
    this.showToast = true,
    super.key,
  });

  final PaymentsGateway gateway;

  /// Close (X): keeps the draft, writes no payment.
  final VoidCallback onClose;

  /// Save success: returns to the caller with the confirmed payment.
  final ValueChanged<SavedPayment> onSaved;

  /// The local date for the default payment date.
  final LocalDate? today;

  /// Test and golden seam: a prepared controller. The caller owns it.
  final PaymentFormController? controller;

  /// The durable draft store. Null keeps the form in memory only.
  final PaymentDraftStore? drafts;

  /// F03 step 1: the record an edit changes. Null is a create.
  final PaymentEdit? editing;

  /// The type the form opens with. The transfer form returns here on a type
  /// switch (SPEC 5.5).
  final PaymentKind initialKind;

  /// Opens C01 (P21). The created account is added and selected; null means
  /// the person closed the editor without a save.
  final Future<AccountSummary?> Function()? onAddAccount;

  /// P24: opens the voice listening state (X24). It returns the transcript
  /// when the person continues in this form, and null after a save or close.
  final Future<String?> Function()? onSpeak;

  /// Phase 3: opens X27, X28 and X63 when they are released.
  final VoidCallback? onScanQr;
  final VoidCallback? onReceiptPhoto;
  final VoidCallback? onImportFile;

  /// P23: switches the form to X26. Absent until the transfer form ships, so
  /// an unreleased type is not a dead control (SPEC 5.5).
  final VoidCallback? onTransfer;

  /// Shows the 5 s toast with Undo after a confirmed write.
  final bool showToast;

  @override
  State<X20AddPayment> createState() => _X20AddPaymentState();
}

class _X20AddPaymentState extends State<X20AddPayment> {
  late final LocalDate _today = widget.today ?? _localToday();
  late final PaymentFormController _controller = widget.controller ??
      PaymentFormController(
        gateway: widget.gateway,
        today: _today,
        drafts: widget.drafts,
        editing: widget.editing,
        kind: widget.initialKind,
      );
  late final TextEditingController _merchantField =
      TextEditingController(text: _controller.merchantText);

  static const int _chipCount = 5;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _merchantField.text = _controller.merchantText;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _merchantField.dispose();
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
        final amount = _controller.enteredAmount;
        final kind = _controller.kind;
        final segments = <String>[
          l.paymentTypeExpense,
          l.paymentTypeIncome,
          if (widget.onTransfer != null) l.paymentTypeTransfer,
        ];
        return FormScreen(
          close: AppIconButton(
            icon: AppIcons.close,
            semanticLabel: l.paymentClose,
            onPressed: widget.onClose,
          ),
          save: _sourceActions(l),
          primaryAction: AppButton(
            label: amount == null
                ? l.paymentSave
                : l.paymentSaveWithAmount(
                    HiddenAmountsScope.resolve(context, null)
                        ? hiddenMask
                        : formatMoney(
                            Money.fromMinor(
                              amount.minor.abs(),
                              amount.currency,
                            ),
                          ),
                  ),
            onPressed: _controller.canSave ? _save : null,
          ),
          children: <Widget>[
            SegmentedControl(
              segments: segments,
              selectedIndex: kind == PaymentKind.expense ? 0 : 1,
              semanticLabel: l.paymentTypeLabel,
              onChanged: (index) {
                if (index == 2) {
                  widget.onTransfer?.call();
                  return;
                }
                _controller.setKind(
                  index == 0 ? PaymentKind.expense : PaymentKind.income,
                );
              },
            ),
            Text(
              (kind == PaymentKind.expense
                      ? l.paymentKickerExpense(_controller.currencyCode)
                      : l.paymentKickerIncome(_controller.currencyCode))
                  .toUpperCase(),
              style: AppText.labelCaps.copyWith(color: role.text),
              semanticsLabel: kind == PaymentKind.expense
                  ? l.paymentKickerExpense(_controller.currencyCode)
                  : l.paymentKickerIncome(_controller.currencyCode),
            ),
            AmountInput(
              value: amount == null
                  ? null
                  : ValueSpec.real(
                      Money.fromMinor(amount.minor.abs(), amount.currency),
                    ),
              emptyText: formatMoney(Money.zero(_controller.currency)),
              emptySemanticLabel: l.paymentAmountNotFilled,
            ),
            _pills(context, l, amount),
            AppField(
              label: l.paymentMerchantLabel,
              semanticLabel: l.paymentMerchantLabel,
              hint: l.paymentMerchantHint,
              controller: _merchantField,
              textInputAction: TextInputAction.done,
              onChanged: _controller.setMerchant,
              onSubmitted: _fillFromSentence,
            ),
            _categoryChips(context, l),
            Keypad(
              onDigit: _controller.pressKey,
              onDelete: _controller.deleteKey,
              deleteLabel: l.paymentDelete,
              decimalLabel: l.paymentDecimal,
            ),
            if (_controller.splits.isNotEmpty && !_controller.splitIsExact)
              Text(
                _splitLine(l),
                style: AppText.caption.copyWith(color: tokens.textSecondary),
              ),
            _statusLine(l),
            if (_controller.hasDraft) ...<Widget>[
              const VSpace(Space.l),
              AppButton(
                label: l.paymentDraftDiscard,
                variant: AppButtonVariant.ghost,
                onPressed: _discardDraft,
              ),
            ],
          ],
        );
      },
    );
  }

  /// X20 puts the released capture sources on the right of the top line.
  /// `FormScreen` sizes that slot to its content, so the buttons stay right
  /// aligned without a nested flex (DESIGN 5, 14.2).
  Widget? _sourceActions(AppLocalizations l) {
    final actions = <Widget>[
      if (widget.onSpeak != null)
        AppIconButton(
          icon: AppIcons.mic,
          semanticLabel: l.paymentSpeak,
          onPressed: _speak,
        ),
      if (widget.onScanQr != null)
        AppIconButton(
          icon: AppIcons.scanQr,
          semanticLabel: l.paymentScanQr,
          onPressed: widget.onScanQr,
        ),
      if (widget.onReceiptPhoto != null)
        AppIconButton(
          icon: AppIcons.receipt,
          semanticLabel: l.paymentReceiptPhoto,
          onPressed: widget.onReceiptPhoto,
        ),
      if (widget.onImportFile != null)
        AppIconButton(
          icon: AppIcons.import,
          semanticLabel: l.paymentImportFile,
          onPressed: widget.onImportFile,
        ),
    ];
    if (actions.isEmpty) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final action in actions) ...<Widget>[
          const HSpace(Space.xs),
          action,
        ],
      ],
    );
  }

  Widget _pills(BuildContext context, AppLocalizations l, Money? amount) {
    final account = _controller.account;
    final splitLabel = _controller.splits.isEmpty
        ? l.paymentSplitPill
        : l.paymentSplitPillCount(_controller.splits.length);
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: <Widget>[
        PillPicker(
          label: _controller.currencyCode,
          semanticLabel: l.paymentCurrencySpoken(_controller.currencyCode),
          onPressed: _openDetails,
        ),
        PillPicker(
          label: _datePill(l),
          semanticLabel: l.paymentDateSpoken(_datePill(l)),
          onPressed: _openDetails,
        ),
        PillPicker(
          label: account?.name ?? l.paymentChooseAccount,
          semanticLabel: l.paymentAccountPillSpoken(
            account?.name ?? l.paymentChooseAccount,
          ),
          onPressed: _openDetails,
        ),
        PillPicker(
          label: splitLabel,
          semanticLabel: l.paymentSplitSpoken(splitLabel),
          onPressed: amount == null ? null : _openSplit,
        ),
      ],
    );
  }

  Widget _categoryChips(BuildContext context, AppLocalizations l) {
    final categories = _controller.categories;
    final chips = <ChipItem>[];
    final shown = <String>{};
    for (final category in categories) {
      if (chips.length >= _chipCount &&
          category.id != _controller.category?.id) {
        continue;
      }
      shown.add(category.id);
      chips.add(
        ChipItem(
          label: category.name,
          semanticLabel: l.paymentCategoryChipSpoken(category.name),
          variant: ChipVariant.choice,
          selected: category.id == _controller.category?.id,
          dotColor: categoryDotTint(context, category.name),
          onPressed: () => _controller.selectCategory(
            category.id == _controller.category?.id ? null : category,
          ),
        ),
      );
    }
    return ChipRow(
      items: <ChipItem>[
        ...chips,
        ChipItem(
          label: l.paymentAllCategories,
          semanticLabel: l.paymentAllCategoriesSpoken,
          variant: ChipVariant.dashed,
          onPressed: _openCategories,
        ),
      ],
    );
  }

  Widget _statusLine(AppLocalizations l) {
    final tokens = context.tokens;
    final style = AppText.caption.copyWith(color: tokens.textSecondary);
    if (_controller.draftUnsupported) {
      return Text(l.paymentDraftUnsupported, style: style);
    }
    if (_controller.status == PaymentFormStatus.failed) {
      final message = switch (_controller.errorCode) {
        PaymentsErrorCode.notWired => l.paymentUnavailable,
        PaymentsErrorCode.invalidPayment => l.paymentInvalid,
        PaymentsErrorCode.undoFailed => l.paymentSaveFailed,
        _ => l.paymentSaveFailed,
      };
      return Text(message, style: style);
    }
    if (_controller.loaded && _controller.accounts.isEmpty) {
      return Text(l.paymentNoAccount, style: style);
    }
    return const SizedBox.shrink();
  }

  String _datePill(AppLocalizations l) {
    final date = _controller.date;
    if (date == _today) {
      return l.paymentDateToday;
    }
    final yesterday = DateTime.utc(_today.year, _today.month, _today.day - 1);
    if (date == LocalDate(yesterday.year, yesterday.month, yesterday.day)) {
      return l.paymentDateYesterday;
    }
    return formatDate(date, DateStyle.short);
  }

  String _splitLine(AppLocalizations l) {
    final remainder = _controller.splitRemainder;
    final count = _controller.splits.length;
    if (remainder == null) {
      return l.paymentSplitPartsCount(count);
    }
    return l.paymentSplitLeftLine(
      count,
      formatMoney(
        Money.fromMinor(remainder.minor.abs(), remainder.currency),
      ),
    );
  }

  /// P24: X24 -> X25. A saved voice draft closes this form; a transcript
  /// returned by "Continue in the form" fills the fields here.
  Future<void> _speak() async {
    final text = await widget.onSpeak?.call();
    if (!mounted || text == null || text.trim().isEmpty) {
      return;
    }
    await _fillFromSentence(text);
  }

  Future<void> _fillFromSentence(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _controller.parseSentence(trimmed);
    if (!mounted) {
      return;
    }
    final merchant = _controller.merchantText;
    if (merchant != trimmed) {
      _merchantField.text = merchant;
    }
  }

  Future<void> _openDetails() async {
    _controller.commitAmount();
    final details = await showDetailsSheet(
      context,
      initial: PaymentDetails(
        date: _controller.date,
        currencyCode: _controller.currencyCode,
        account: _controller.account,
        tagIds: _controller.selectedTagIds.toList(growable: false),
      ),
      today: _today,
      accounts: _controller.accounts,
      tags: _controller.tags,
      onAddAccount: widget.onAddAccount,
    );
    if (details == null || !mounted) {
      return;
    }
    _controller
      ..setDate(details.date)
      ..setCurrency(details.currencyCode)
      ..setTags(details.tagIds);
    final account = details.account;
    if (account != null) {
      _controller.addAccount(account);
    }
  }

  Future<void> _openCategories() async {
    _controller.commitAmount();
    final chosen = await showCategorySheet(
      context,
      categories: _controller.categories,
      selectedId: _controller.category?.id,
    );
    if (!mounted) {
      return;
    }
    _controller.selectCategory(chosen);
  }

  Future<void> _openSplit() async {
    _controller.commitAmount();
    final amount = _controller.enteredAmount;
    if (amount == null) {
      return;
    }
    final section = context.section;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SectionScope(
          section: section,
          child: X23SplitScreen(
            total: Money.fromMinor(amount.minor.abs(), amount.currency),
            merchantName: _controller.merchantText,
            date: _controller.date,
            categories: _controller.categories,
            initialParts: _controller.splits,
            onSave: (parts) {
              _controller.setSplitParts(parts);
              Navigator.of(context).pop();
            },
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
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
        message: saved.edit ? l.paymentEditedToast : l.paymentSavedToast,
        undoLabel: l.paymentUndo,
        onUndo: () => _undo(saved),
      );
    }
    widget.onSaved(saved);
  }

  /// SPEC 8.18: one compensating command for the confirmed creation.
  Future<void> _undo(SavedPayment saved) async {
    try {
      await widget.gateway.undoPayment(saved);
    } on Object {
      // The record stays; the caller refreshes to its current state.
    }
  }
}

/// The local calendar date from the wall clock. The controller receives it, so
/// the domain and the tests never read a clock directly (AGENTS 6.3).
LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
