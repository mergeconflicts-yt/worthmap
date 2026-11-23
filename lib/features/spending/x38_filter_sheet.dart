// P27 (SCREEN X38; flow F08 step 3): the filter sheet.
//
// The sheet edits a draft. "Show" returns it; Back keeps the applied filter
// (F08-A). "Clear" resets the draft. The Show label reads the exact count of
// the draft from the gateway.
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'payments_models.dart';

/// Opens X38 and returns the applied filter, or null when dismissed.
Future<PaymentFilter?> showPaymentFilterSheet(
  BuildContext context, {
  required PaymentsReadGateway gateway,
  required PaymentFilter initial,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<PaymentFilter>(
    context,
    title: l.paymentsFilterTitle,
    semanticLabel: l.paymentsFilterTitle,
    children: <Widget>[
      X38FilterSheet(gateway: gateway, initial: initial),
    ],
  );
}

/// The filter content. It is public so a golden can render it directly.
class X38FilterSheet extends StatefulWidget {
  const X38FilterSheet({
    required this.gateway,
    required this.initial,
    super.key,
  });

  final PaymentsReadGateway gateway;
  final PaymentFilter initial;

  @override
  State<X38FilterSheet> createState() => _X38FilterSheetState();
}

class _X38FilterSheetState extends State<X38FilterSheet> {
  late PaymentFilter _draft = widget.initial;
  List<FilterOption> _accounts = const <FilterOption>[];
  List<FilterOption> _categories = const <FilterOption>[];
  int? _count;
  bool _loadedOptions = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _refreshCount();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await widget.gateway.filterOptions();
      if (!mounted) {
        return;
      }
      setState(() {
        _accounts = options.accounts;
        _categories = options.categories;
        _loadedOptions = true;
      });
    } on Object {
      if (mounted) {
        setState(() => _loadedOptions = true);
      }
    }
  }

  Future<void> _refreshCount() async {
    try {
      final count = await widget.gateway.countPayments(_draft);
      if (mounted) {
        setState(() => _count = count);
      }
    } on Object {
      if (mounted) {
        setState(() => _count = null);
      }
    }
  }

  void _change(PaymentFilter value) {
    setState(() => _draft = value);
    _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final labelStyle = AppText.labelCaps.copyWith(color: tokens.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l.paymentsFilterPeriod.toUpperCase(), style: labelStyle),
        const VSpace(Space.s),
        ChipRow(
          items: <ChipItem>[
            for (final period in PaymentPeriod.values)
              ChipItem(
                label: _periodLabel(l, period),
                semanticLabel: _periodLabel(l, period),
                variant: ChipVariant.choice,
                selected: _draft.period == period,
                onPressed: () => _change(_draft.copyWith(period: period)),
              ),
          ],
        ),
        const VSpace(Space.l),
        Text(l.paymentsFilterShow.toUpperCase(), style: labelStyle),
        const VSpace(Space.s),
        for (final show in PaymentShowFilter.values)
          SelectRow(
            name: _showLabel(l, show),
            chevron: false,
            trailing: _draft.show == show
                ? AppIcon(
                    data: AppIcons.check,
                    size: 18,
                    color: context.tokens.textPrimary,
                  )
                : null,
            onTap: () => _change(_draft.copyWith(show: show)),
            semanticLabel: _showLabel(l, show),
          ),
        const VSpace(Space.l),
        SelectRow(
          name: l.paymentsFilterAccounts,
          value: _nameOf(_accounts, _draft.accountId) ??
              l.paymentsFilterAllAccounts,
          onTap: _loadedOptions
              ? () async {
                  final chosen = await _pick(
                    context,
                    title: l.paymentsFilterAccounts,
                    allLabel: l.paymentsFilterAllAccounts,
                    options: _accounts,
                  );
                  if (chosen == null || !mounted) {
                    return;
                  }
                  _change(
                    chosen.id.isEmpty
                        ? _draft.copyWith(clearAccount: true)
                        : _draft.copyWith(accountId: chosen.id),
                  );
                }
              : null,
          semanticLabel: l.paymentsFilterAccounts,
        ),
        SelectRow(
          name: l.paymentsFilterCategories,
          value: _nameOf(_categories, _draft.categoryId) ??
              l.paymentsFilterAllCategories,
          onTap: _loadedOptions
              ? () async {
                  final chosen = await _pick(
                    context,
                    title: l.paymentsFilterCategories,
                    allLabel: l.paymentsFilterAllCategories,
                    options: _categories,
                  );
                  if (chosen == null || !mounted) {
                    return;
                  }
                  _change(
                    chosen.id.isEmpty
                        ? _draft.copyWith(clearCategory: true)
                        : _draft.copyWith(categoryId: chosen.id),
                  );
                }
              : null,
          semanticLabel: l.paymentsFilterCategories,
        ),
        const VSpace(Space.l),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppButton(
              label: l.paymentsFilterClear,
              variant: AppButtonVariant.ghost,
              fullWidth: false,
              compact: true,
              onPressed: () => _change(
                const PaymentFilter(
                  period: PaymentPeriod.thisMonth,
                  show: PaymentShowFilter.moneyOut,
                ),
              ),
            ),
          ],
        ),
        const VSpace(Space.s),
        AppButton(
          label: _count == null
              ? l.paymentsFilterTitle
              : l.paymentsFilterShowCount(_count!),
          onPressed:
              _count == null ? null : () => Navigator.of(context).pop(_draft),
        ),
      ],
    );
  }

  static String? _nameOf(List<FilterOption> options, String? id) {
    if (id == null) {
      return null;
    }
    for (final option in options) {
      if (option.id == id) {
        return option.name;
      }
    }
    return null;
  }

  static String _periodLabel(AppLocalizations l, PaymentPeriod period) =>
      switch (period) {
        PaymentPeriod.thisMonth => l.paymentsPeriodThisMonth,
        PaymentPeriod.lastMonth => l.paymentsPeriodLastMonth,
        PaymentPeriod.thisYear => l.paymentsPeriodThisYear,
      };

  static String _showLabel(AppLocalizations l, PaymentShowFilter show) =>
      switch (show) {
        PaymentShowFilter.moneyOut => l.paymentsShowMoneyOut,
        PaymentShowFilter.moneyIn => l.paymentsShowMoneyIn,
        PaymentShowFilter.transfers => l.paymentsShowTransfers,
        PaymentShowFilter.noCategory => l.paymentsShowNoCategory,
      };
}

/// One option sheet: "All" plus the list. An empty id means "All".
Future<FilterOption?> _pick(
  BuildContext context, {
  required String title,
  required String allLabel,
  required List<FilterOption> options,
}) {
  return showAppSheet<FilterOption>(
    context,
    title: title,
    semanticLabel: title,
    children: <Widget>[
      SelectRow(
        name: allLabel,
        onTap: () =>
            Navigator.of(context).pop(const FilterOption(id: '', name: '')),
        semanticLabel: allLabel,
      ),
      for (final option in options)
        SelectRow(
          name: option.name,
          onTap: () => Navigator.of(context).pop(option),
          semanticLabel: option.name,
        ),
    ],
  );
}
