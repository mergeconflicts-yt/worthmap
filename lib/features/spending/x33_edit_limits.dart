// P26 (SCREEN X33; flow F08 step 3; SPEC 4.4, 6.5): the limits editor.
//
// One SaveLimits command. It writes limits, ChangeLog and dirty ranges and
// changes no payment (F08-E). Money entry uses the keypad, never a text field.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'spending_controller.dart';
import 'spending_models.dart';

/// X33: the total limit and one row per expense category.
class X33EditLimits extends StatefulWidget {
  const X33EditLimits({
    required this.gateway,
    required this.onClose,
    this.onSaved,
    this.controller,
    super.key,
  });

  final SpendingGateway gateway;
  final VoidCallback onClose;
  final VoidCallback? onSaved;
  final LimitsController? controller;

  @override
  State<X33EditLimits> createState() => _X33EditLimitsState();
}

class _X33EditLimitsState extends State<X33EditLimits> {
  late final LimitsController _controller =
      widget.controller ?? LimitsController(gateway: widget.gateway);

  @override
  void initState() {
    super.initState();
    _controller.load();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final view = _controller.view;
        final currency = Currency.of(view?.currencyCode ?? 'USD');
        final total = _controller.totalMinor;
        return FormScreen(
          close: AppIconButton(
            icon: AppIcons.close,
            semanticLabel: l.spendingClose,
            onPressed: widget.onClose,
          ),
          save: AppButton(
            label: l.spendingSave,
            variant: AppButtonVariant.ghost,
            fullWidth: false,
            compact: true,
            onPressed: _controller.state == SpendingLoadState.ready &&
                    !_controller.saving
                ? _save
                : null,
          ),
          primaryAction: AppButton(
            label: l.spendingSave,
            onPressed: _controller.state == SpendingLoadState.ready &&
                    !_controller.saving
                ? _save
                : null,
          ),
          children: <Widget>[
            Text(
              l.spendingEditLimitsTitle,
              style: AppText.titleScreen,
            ),
            Text(
              l.spendingEditLimitsSubline,
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
            if (_controller.state == SpendingLoadState.failed)
              Text(l.spendingLoadFailed, style: AppText.bodyStrong)
            else if (view == null)
              Text(l.spendingLoading, style: AppText.caption)
            else ...<Widget>[
              ObHero(
                kicker: l.spendingTotalLimitKicker,
                value: total == null
                    ? ValueSpec.missing(l.spendingNoLimit)
                    : ValueSpec.real(Money.fromMinor(total, currency)),
                contextLine:
                    l.spendingTotalLimitLine(_controller.categoryCount),
              ),
              GlassCard(
                title: l.spendingLimitPerCategory,
                meta: '${_controller.categoryCount}',
                child: Column(
                  children: <Widget>[
                    for (final row in view.rows) ...<Widget>[
                      SelectRow(
                        name: row.name,
                        trailing: AppButton(
                          label: _controller.limitFor(row.categoryId) <= 0
                              ? l.spendingLimitUnset
                              : formatMoney(
                                  Money.fromMinor(
                                    _controller.limitFor(row.categoryId),
                                    currency,
                                  ),
                                ),
                          variant: AppButtonVariant.neutral,
                          fullWidth: false,
                          compact: true,
                          semanticLabel: l.spendingLimitSpoken(
                            row.name,
                            _controller.limitFor(row.categoryId) <= 0
                                ? l.spendingLimitUnset
                                : formatMoney(
                                    Money.fromMinor(
                                      _controller.limitFor(row.categoryId),
                                      currency,
                                    ),
                                  ),
                          ),
                          onPressed: () => _editLimit(row, currency),
                        ),
                        semanticLabel: row.name,
                      ),
                      const VSpace(Space.xxs),
                    ],
                  ],
                ),
              ),
              if (_controller.errorCode != null)
                Text(
                  _controller.errorCode == SpendingErrorCode.saveFailed
                      ? l.spendingSaveFailed
                      : l.spendingLoadFailed,
                  style: AppText.caption.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              Text(
                l.spendingEveryMonth,
                style: AppText.caption.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _editLimit(LimitView row, Currency currency) async {
    final value = await showLimitSheet(
      context,
      name: row.name,
      currentMinor: _controller.limitFor(row.categoryId),
      currency: currency,
    );
    if (value == null || !mounted) {
      return;
    }
    _controller.setLimit(row.categoryId, value);
  }

  Future<void> _save() async {
    final saved = await _controller.save();
    if (!mounted) {
      return;
    }
    if (!saved) {
      return;
    }
    widget.onSaved?.call();
  }
}

/// Opens the limit sheet and returns the entered minor units, or null.
Future<int?> showLimitSheet(
  BuildContext context, {
  required String name,
  required int currentMinor,
  required Currency currency,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<int>(
    context,
    title: l.spendingLimitSheetTitle(name),
    semanticLabel: l.spendingLimitSheetTitle(name),
    children: <Widget>[
      _LimitSheet(name: name, currentMinor: currentMinor, currency: currency),
    ],
  );
}

class _LimitSheet extends StatefulWidget {
  const _LimitSheet({
    required this.name,
    required this.currentMinor,
    required this.currency,
  });

  final String name;
  final int currentMinor;
  final Currency currency;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  String _text = '';

  @override
  void initState() {
    super.initState();
    final current = widget.currentMinor;
    if (current > 0) {
      _text = _plain(current);
    }
  }

  String _plain(int minor) {
    final digits =
        minor.toString().padLeft(widget.currency.minorUnits + 1, '0');
    if (widget.currency.minorUnits == 0) {
      return digits;
    }
    final cut = digits.length - widget.currency.minorUnits;
    return '${digits.substring(0, cut)}.${digits.substring(cut)}';
  }

  int? get _minor {
    if (_text.isEmpty || _text == '.') {
      return null;
    }
    try {
      return Money.fromDecimal(
        Decimal.parse(_text),
        widget.currency,
      ).minor;
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final minor = _minor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AmountInput(
          value: minor == null
              ? null
              : ValueSpec.real(Money.fromMinor(minor, widget.currency)),
          emptyText: formatMoney(Money.zero(widget.currency)),
          emptySemanticLabel: l.spendingAmountNotFilled,
        ),
        const VSpace(Space.l),
        Keypad(
          onDigit: _press,
          onDelete: _delete,
          deleteLabel: l.spendingDeleteKey,
          decimalLabel: l.spendingDecimal,
        ),
        const VSpace(Space.l),
        AppButton(
          label: l.spendingLimitUse,
          onPressed: minor == null || minor <= 0
              ? null
              : () => Navigator.of(context).pop(minor),
        ),
        const VSpace(Space.s),
        AppButton(
          label: l.spendingLimitRemove,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(0),
        ),
      ],
    );
  }
}
