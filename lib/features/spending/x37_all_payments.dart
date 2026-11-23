// P27 (SCREEN X37; flow F08 step 3; SPEC 6.5): all payments, grouped by day.
//
// The list reads the applied filter only (F08-A). A row opens X39. The delete
// toast with Undo belongs to X39; this screen reloads when it returns.
library;

import 'package:flutter/material.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'payments_controller.dart';
import 'payments_models.dart';
import 'x38_filter_sheet.dart';

/// X37: header, applied filter chips and one card per day.
class X37AllPayments extends StatefulWidget {
  const X37AllPayments({
    required this.gateway,
    required this.onClose,
    required this.onOpenPayment,
    this.initialFilter,
    this.controller,
    super.key,
  });

  final PaymentsReadGateway gateway;
  final VoidCallback onClose;
  final Future<DeletedPayment?> Function(String) onOpenPayment;
  final PaymentFilter? initialFilter;

  /// Test and golden seam: a prepared controller. The caller owns it.
  final PaymentsListController? controller;

  @override
  State<X37AllPayments> createState() => _X37AllPaymentsState();
}

class _X37AllPaymentsState extends State<X37AllPayments> {
  late final PaymentsListController _controller = widget.controller ??
      PaymentsListController(
        gateway: widget.gateway,
        filter: widget.initialFilter ??
            const PaymentFilter(
              period: PaymentPeriod.thisMonth,
              show: PaymentShowFilter.moneyOut,
            ),
      );
  List<FilterOption> _accounts = const <FilterOption>[];
  List<FilterOption> _categories = const <FilterOption>[];

  @override
  void initState() {
    super.initState();
    _controller.load();
    _loadOptions();
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
      });
    } on Object {
      // The chips fall back to "All" labels.
    }
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
        final page = _controller.page;
        return DetailScreen(
          header: ScreenHeader(
            title: l.paymentsAllTitle,
            dateLine: page == null
                ? null
                : formatDateRange(page.rangeStart, page.rangeEnd),
            leading: AppIconButton(
              icon: AppIcons.back,
              semanticLabel: l.paymentsBack,
              onPressed: widget.onClose,
            ),
            actions: <Widget>[
              const HideAmountsButton(),
              AppIconButton(
                icon: AppIcons.filter,
                semanticLabel: l.paymentsFilter,
                onPressed: _openFilter,
              ),
            ],
          ),
          children: <Widget>[
            if (_controller.state == PaymentsViewState.loading)
              Text(l.spendingLoading, style: AppText.caption)
            else if (_controller.state == PaymentsViewState.failed) ...<Widget>[
              Text(l.spendingLoadFailed, style: AppText.bodyStrong),
              AppButton(
                label: l.spendingRetry,
                variant: AppButtonVariant.soft,
                onPressed: _controller.load,
              ),
            ] else if (page != null) ...<Widget>[
              _chips(l, page),
              ..._days(l, page),
            ],
          ],
        );
      },
    );
  }

  Widget _chips(AppLocalizations l, PaymentListPage page) {
    final filter = page.filter;
    return ChipRow(
      items: <ChipItem>[
        ChipItem(
          label: _periodLabel(l, filter.period),
          semanticLabel: _periodLabel(l, filter.period),
          onPressed: _openFilter,
        ),
        ChipItem(
          label: _nameOf(_accounts, filter.accountId) ??
              l.paymentsFilterAllAccounts,
          semanticLabel: l.paymentsFilterAllAccounts,
          onPressed: _openFilter,
        ),
        ChipItem(
          label: _nameOf(_categories, filter.categoryId) ??
              l.paymentsFilterAllCategories,
          semanticLabel: l.paymentsFilterAllCategories,
          onPressed: _openFilter,
        ),
      ],
    );
  }

  List<Widget> _days(AppLocalizations l, PaymentListPage page) {
    if (page.items.isEmpty) {
      return <Widget>[
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.paymentsNoPayments, style: AppText.bodyStrong),
              const VSpace(Space.xxs),
              Text(
                l.paymentsNoPaymentsBody,
                style: AppText.caption.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ];
    }
    final groups = <String, List<PaymentListItem>>{};
    for (final item in page.items) {
      groups
          .putIfAbsent(item.date.toString(), () => <PaymentListItem>[])
          .add(item);
    }
    return <Widget>[
      for (final entry in groups.entries)
        _dayCard(l, LocalDate.parse(entry.key), entry.value),
    ];
  }

  Widget _dayCard(
    AppLocalizations l,
    LocalDate date,
    List<PaymentListItem> items,
  ) {
    final currency = Currency.of(items.first.currencyCode);
    final total = items.fold<int>(0, (sum, item) => sum + item.amountMinor);
    return GlassCard(
      title: _dayLabel(l, date),
      meta: formatMoney(Money.fromMinor(total, currency)),
      child: Column(
        children: <Widget>[
          for (final item in items) ...<Widget>[
            _row(l, item),
            const VSpace(Space.xxs),
          ],
        ],
      ),
    );
  }

  Widget _row(AppLocalizations l, PaymentListItem item) {
    final currency = Currency.of(item.currencyCode);
    final amount = Money.fromMinor(item.amountMinor, currency);
    final name = item.merchantName ?? l.paymentsPaymentFallback;
    return SelectRow(
      name: name,
      line: l.paymentsRowLine(
        item.categoryName ?? l.paymentsFilterAllCategories,
        item.accountName,
      ),
      trailing: MoneyText(
        ValueSpec.real(amount),
        style: AppText.numberXS,
      ),
      onTap: () => _openPayment(item.id),
      semanticLabel: l.paymentsRowSpoken(name, formatMoney(amount)),
    );
  }

  Future<void> _openPayment(String id) async {
    final deleted = await widget.onOpenPayment(id);
    if (!mounted) {
      return;
    }
    await _controller.load();
    if (!mounted) {
      return;
    }
    if (deleted != null) {
      final l = AppLocalizations.of(context);
      showAppToast(
        context,
        message: l.paymentsDeletedToast,
        undoLabel: l.paymentsUndo,
        onUndo: () async {
          await widget.gateway.restorePayment(deleted);
          await _controller.load();
        },
      );
    }
  }

  String _dayLabel(AppLocalizations l, LocalDate date) {
    final now = DateTime.now();
    final today = LocalDate(now.year, now.month, now.day);
    if (date == today) {
      return '${l.paymentsToday} · ${formatDate(date, DateStyle.short)}';
    }
    final yesterday = DateTime.utc(today.year, today.month, today.day - 1);
    if (date == LocalDate(yesterday.year, yesterday.month, yesterday.day)) {
      return '${l.paymentsYesterday} · ${formatDate(date, DateStyle.short)}';
    }
    return '${formatWeekdayShort(date)} · ${formatDate(date, DateStyle.short)}';
  }

  Future<void> _openFilter() async {
    final chosen = await showPaymentFilterSheet(
      context,
      gateway: widget.gateway,
      initial: _controller.filter,
    );
    if (chosen == null || !mounted) {
      return;
    }
    await _controller.apply(chosen);
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
}
