// P22 (SCREENS X23; flow F03 step 4; SPEC 4.1, 8.16): the split editor.
//
// The screen edits a copy of the split parts. Save returns them to the X20
// draft only when nothing is left to split (largest remainder stays in
// `Percent.split`; the parts are exact minor units). No ledger write happens
// here.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'payment_category_style.dart';
import 'payment_draft.dart';
import 'payment_models.dart';
import 'x21_category_sheet.dart';

/// X23: the split parts, the remainder and Save.
class X23SplitScreen extends StatefulWidget {
  const X23SplitScreen({
    required this.total,
    required this.merchantName,
    required this.date,
    required this.categories,
    required this.initialParts,
    required this.onSave,
    required this.onClose,
    this.onAddCategory,
    super.key,
  });

  /// The whole payment amount as a magnitude.
  final Money total;
  final String? merchantName;
  final LocalDate date;
  final List<CategorySummary> categories;
  final List<PaymentDraftSplit> initialParts;
  final ValueChanged<List<PaymentDraftSplit>> onSave;
  final VoidCallback onClose;
  final VoidCallback? onAddCategory;

  @override
  State<X23SplitScreen> createState() => _X23SplitScreenState();
}

class _X23SplitScreenState extends State<X23SplitScreen> {
  late final List<PaymentDraftSplit> _parts = <PaymentDraftSplit>[
    ...widget.initialParts,
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final remainder = _remainder;
    final exact = _parts.length >= 2 && remainder != null && remainder.isZero;
    final hidden = HiddenAmountsScope.resolve(context, null);
    return DetailScreen(
      header: ScreenHeader(
        title: l.paymentSplitTitle,
        dateLine: _subLine(l),
        leading: AppIconButton(
          icon: AppIcons.close,
          semanticLabel: l.paymentClose,
          onPressed: widget.onClose,
        ),
      ),
      children: <Widget>[
        ObHero(
          kicker: l.paymentSplitKicker,
          value: ValueSpec.real(widget.total),
          contextLine: _contextLine(l),
        ),
        GlassCard(
          child: SplitBar(
            title: l.paymentSplitBarTitle,
            period: _contextLine(l),
            parts: <SplitBarPart>[
              for (final part in _parts)
                SplitBarPart(
                  name: part.name,
                  amount:
                      _partAmount(part) ?? Money.zero(widget.total.currency),
                  mark: categoryMarkOrOther(part.name),
                ),
            ],
            columns: <String>[
              l.paymentSplitColumnPart,
              l.paymentSplitColumnAmount,
              l.paymentSplitColumnShare,
            ],
            emptyLabel: l.paymentSplitEmpty,
          ),
        ),
        GlassCard(
          title: l.paymentSplitPartsTitle,
          meta: l.paymentSplitPartsMeta(_parts.length),
          child: SplitEditor(
            parts: <SplitPart>[
              for (final part in _parts)
                SplitPart(
                  name: part.name,
                  amountText: hidden
                      ? hiddenMask
                      : formatMoney(
                          _partAmount(part) ??
                              Money.zero(widget.total.currency),
                          showSymbol: true,
                        ),
                  dotColor: categoryDotTint(context, part.name),
                  removeLabel: l.paymentSplitRemove(part.name),
                  onAmountTap: () => _editAmount(part),
                  onRemove: () => _remove(part),
                ),
            ],
            addLabel: l.paymentSplitAdd,
            onAdd: _addPart,
            leftLabel: l.paymentSplitLeft,
            leftValue: remainder == null
                ? MoneyText(
                    ValueSpec.noneRecorded(l.paymentSplitEmpty),
                    style: AppText.numberXS.copyWith(
                      color: tokens.textSecondary,
                    ),
                  )
                : MoneyText(
                    ValueSpec.real(remainder),
                    style: AppText.numberXS.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
          ),
        ),
        if (exact)
          Text(
            l.paymentSplitAllInParts(
              hidden ? hiddenMask : formatMoney(widget.total),
            ),
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          ),
        AppButton(
          label: l.paymentSplitSave,
          onPressed: exact ? _save : null,
        ),
        Text(
          l.paymentSplitSaveNote,
          style: AppText.caption.copyWith(color: tokens.textSecondary),
        ),
      ],
    );
  }

  /// X23 header sub-line: the merchant and the date, without the count.
  String _subLine(AppLocalizations l) {
    final name = widget.merchantName?.trim();
    return l.paymentSplitSubline(
      name == null || name.isEmpty ? l.paymentSplitNoMerchant : name,
      formatDate(widget.date, DateStyle.short),
    );
  }

  String _contextLine(AppLocalizations l) {
    final name = widget.merchantName?.trim();
    final date = formatDate(widget.date, DateStyle.short);
    return l.paymentSplitContext(
      name == null || name.isEmpty ? l.paymentSplitNoMerchant : name,
      date,
      _parts.length,
    );
  }

  Money? get _remainder {
    var total = 0;
    for (final part in _parts) {
      final amount = _partAmount(part);
      if (amount == null) {
        return null;
      }
      total += amount.minor;
    }
    return Money.fromMinor(widget.total.minor - total, widget.total.currency);
  }

  Money? _partAmount(PaymentDraftSplit part) {
    if (part.amountText.isEmpty || part.amountText == '.') {
      return Money.zero(widget.total.currency);
    }
    try {
      return Money.fromDecimal(
        Decimal.parse(part.amountText),
        widget.total.currency,
      );
    } on Object {
      return null;
    }
  }

  String _plain(Money amount) {
    final digits = BigInt.from(amount.minor).abs().toString().padLeft(
          amount.currency.minorUnits + 1,
          '0',
        );
    if (amount.currency.minorUnits == 0) {
      return digits;
    }
    final whole = digits.substring(
      0,
      digits.length - amount.currency.minorUnits,
    );
    final fraction =
        digits.substring(digits.length - amount.currency.minorUnits);
    return '$whole.$fraction';
  }

  Future<void> _addPart() async {
    final chosen = await showCategorySheet(
      context,
      categories: widget.categories,
      selectedId: null,
      onNewCategory: widget.onAddCategory,
    );
    if (chosen == null || !mounted) {
      return;
    }
    final left = _remainder ?? Money.zero(widget.total.currency);
    setState(() {
      _parts.add(
        PaymentDraftSplit(
          categoryId: chosen.id,
          name: chosen.name,
          amountText:
              _plain(left.isNegative ? Money.zero(left.currency) : left),
        ),
      );
    });
  }

  Future<void> _editAmount(PaymentDraftSplit part) async {
    final value = await showAppSheet<String>(
      context,
      title: part.name,
      semanticLabel: AppLocalizations.of(context).paymentSplitAmountSpoken(
        part.name,
      ),
      children: <Widget>[
        _PartAmountEditor(
          currency: widget.total.currency,
          initialText: part.amountText,
        ),
      ],
    );
    if (value == null || !mounted) {
      return;
    }
    setState(() {
      final index = _parts.indexOf(part);
      if (index >= 0) {
        _parts[index] = PaymentDraftSplit(
          categoryId: part.categoryId,
          name: part.name,
          amountText: value,
        );
      }
    });
  }

  void _remove(PaymentDraftSplit part) {
    setState(() => _parts.remove(part));
  }

  void _save() {
    widget.onSave(List<PaymentDraftSplit>.unmodifiable(_parts));
  }
}

class _PartAmountEditor extends StatefulWidget {
  const _PartAmountEditor({
    required this.currency,
    required this.initialText,
  });

  final Currency currency;
  final String initialText;

  @override
  State<_PartAmountEditor> createState() => _PartAmountEditorState();
}

class _PartAmountEditorState extends State<_PartAmountEditor> {
  late String _text = widget.initialText;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final value = _amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AmountInput(
          value: value == null ? null : ValueSpec.real(value),
          emptyText: formatMoney(Money.zero(widget.currency)),
          emptySemanticLabel: l.paymentAmountNotFilled,
        ),
        const VSpace(Space.l),
        Keypad(
          onDigit: _press,
          onDelete: _delete,
          deleteLabel: l.paymentDelete,
          decimalLabel: l.paymentDecimal,
        ),
        const VSpace(Space.l),
        AppButton(
          label: l.paymentDone,
          onPressed:
              value == null ? null : () => Navigator.of(context).pop(_text),
        ),
      ],
    );
  }

  Money? get _amount {
    if (_text.isEmpty || _text == '.') {
      return null;
    }
    try {
      return Money.fromDecimal(Decimal.parse(_text), widget.currency);
    } on Object {
      return null;
    }
  }

  void _press(String key) {
    setState(() {
      if (key == '.') {
        if (_text.contains('.') || widget.currency.minorUnits == 0) {
          return;
        }
        _text = _text.isEmpty ? '0.' : '$_text.';
        return;
      }
      if (!RegExp(r'^\d$').hasMatch(key)) {
        return;
      }
      final point = _text.indexOf('.');
      if (point >= 0 &&
          _text.length - point - 1 >= widget.currency.minorUnits) {
        return;
      }
      if (point < 0 && _text.length >= 12) {
        return;
      }
      _text = _text == '0' ? key : '$_text$key';
    });
  }

  void _delete() {
    setState(() {
      if (_text.isNotEmpty) {
        _text = _text.substring(0, _text.length - 1);
      }
    });
  }
}
