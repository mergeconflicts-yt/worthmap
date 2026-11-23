// P27 (SCREEN X36; flow F08 step 2; SPEC 4.4): one category.
//
// The hero uses the month limit, the facts show used, month gone and the
// 12-month average, the chart shows each month, "Where" shows the merchant
// shares and the payment rows open X39. Refunds reduce the category net
// (SPEC 4.11).
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/money.dart';
import '../../core/percent.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'payments_controller.dart';
import 'payments_models.dart';

/// X36: category hero, facts, monthly chart, merchants and payments.
class X36CategoryDetail extends StatefulWidget {
  const X36CategoryDetail({
    required this.gateway,
    required this.categoryId,
    required this.onClose,
    required this.onOpenPayment,
    this.onAllPayments,
    this.controller,
    super.key,
  });

  final PaymentsReadGateway gateway;
  final String categoryId;
  final VoidCallback onClose;
  final Future<DeletedPayment?> Function(String) onOpenPayment;
  final ValueChanged<String>? onAllPayments;
  final CategoryDetailController? controller;

  @override
  State<X36CategoryDetail> createState() => _X36CategoryDetailState();
}

class _X36CategoryDetailState extends State<X36CategoryDetail> {
  late final CategoryDetailController _controller = widget.controller ??
      CategoryDetailController(
        gateway: widget.gateway,
        categoryId: widget.categoryId,
      );

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
        return DetailScreen(
          header: ScreenHeader(
            title: view?.name ?? '',
            dateLine: view == null
                ? null
                : formatDateRange(view.rangeStart, view.rangeEnd),
            leading: AppIconButton(
              icon: AppIcons.back,
              semanticLabel: l.paymentsBack,
              onPressed: widget.onClose,
            ),
            actions: const <Widget>[HideAmountsButton()],
          ),
          children: <Widget>[
            if (_controller.state == PaymentsViewState.loading)
              Text(l.spendingLoading, style: AppText.caption)
            else if (view == null) ...<Widget>[
              Text(l.spendingLoadFailed, style: AppText.bodyStrong),
            ] else ...<Widget>[
              _hero(l, view),
              _facts(l, view),
              if (view.months.isNotEmpty) _months(l, view),
              if (view.merchants.isNotEmpty) _where(l, view),
              _payments(l, view),
            ],
          ],
        );
      },
    );
  }

  Widget _hero(AppLocalizations l, CategoryDetailView view) {
    final currency = Currency.of(view.currencyCode);
    final spent = view.spentMinor;
    final limit = view.limitMinor;
    final left = spent == null || limit == null ? null : limit - spent;
    final hidden = HiddenAmountsScope.resolve(context, null);
    return ObHero(
      kicker: l.categoryKicker(
        view.name,
        formatMonthLong(view.rangeStart),
      ),
      value: spent == null
          ? ValueSpec.noneRecorded(l.categoryNothingRecorded)
          : ValueSpec.real(Money.fromMinor(spent, currency)),
      contextLine: hidden
          ? l.categoryLimitHidden
          : limit == null
              ? l.categoryNoLimit
              : l.categoryLimitLine(
                  left == null
                      ? l.categoryNoLimit
                      : formatMoney(Money.fromMinor(left, currency)),
                  formatMoney(Money.fromMinor(limit, currency)),
                ),
    );
  }

  Widget _facts(AppLocalizations l, CategoryDetailView view) {
    final used = view.spentMinor == null || view.limitMinor == null
        ? null
        : Percent.fromFraction(
            (Decimal.fromInt(view.spentMinor!) /
                    Decimal.fromInt(view.limitMinor!))
                .toDecimal(scaleOnInfinitePrecision: 6),
          );
    return GlassCard(
      child: Column(
        children: <Widget>[
          SelectRow(
            name: l.categoryUsed,
            value: used == null ? '—' : formatPercent(used, decimals: 0),
            chevron: false,
          ),
          SelectRow(
            name: l.categoryMonthGone,
            value: formatPercent(
              Percent.fromPoints(
                Decimal.fromInt(view.monthGonePercent),
              ),
              decimals: 0,
            ),
            chevron: false,
          ),
          SelectRow(
            name: l.categoryAverage,
            trailing: view.averageMinor == null
                ? Text(
                    l.categoryNothingRecorded,
                    style: AppText.body.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  )
                : MoneyText(
                    ValueSpec.real(
                      Money.fromMinor(
                        view.averageMinor!,
                        Currency.of(view.currencyCode),
                      ),
                    ),
                    style: AppText.body.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
            chevron: false,
          ),
        ],
      ),
    );
  }

  Widget _months(AppLocalizations l, CategoryDetailView view) {
    final currency = Currency.of(view.currencyCode);
    return GlassCard(
      title: l.categoryEachMonth,
      meta: '${formatMonthShort(view.months.first.month)}–'
          '${formatMonthShort(view.months.last.month)}',
      child: PeriodBarChart(
        title: l.categoryChartTitle,
        period: formatDateRange(view.rangeStart, view.rangeEnd),
        bars: <PeriodBar>[
          for (final month in view.months)
            PeriodBar(
              label: formatMonthShort(month.month),
              amount: Money.fromMinor(month.amountMinor, currency),
            ),
        ],
        columns: <String>[
          l.spendingChartMonthColumn,
          l.spendingChartAmountColumn,
        ],
        limit: view.limitMinor == null
            ? null
            : Money.fromMinor(view.limitMinor!, currency),
        average: view.averageMinor == null
            ? null
            : Money.fromMinor(view.averageMinor!, currency),
        limitLabel: l.categoryChartLimit,
        averageLabel: l.categoryChartAverage,
        emptyLabel: l.categoryNothingRecorded,
      ),
    );
  }

  Widget _where(AppLocalizations l, CategoryDetailView view) {
    final currency = Currency.of(view.currencyCode);
    return GlassCard(
      title: l.categoryWhere,
      child: SplitBar(
        title: l.categoryWhere,
        period: formatDateRange(view.rangeStart, view.rangeEnd),
        parts: <SplitBarPart>[
          for (final merchant in view.merchants)
            SplitBarPart(
              name: merchant.name ?? l.paymentsPaymentFallback,
              amount: Money.fromMinor(merchant.amountMinor, currency),
              mark: ChartMark.neutral,
            ),
        ],
        columns: <String>[
          l.paymentsPaymentFallback,
          l.spendingChartAmountColumn,
          l.paymentsSplitTitle,
        ],
        emptyLabel: l.categoryNothingRecorded,
      ),
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

  Widget _payments(AppLocalizations l, CategoryDetailView view) {
    final currency = Currency.of(view.currencyCode);
    return GlassCard(
      title: l.categoryPayments,
      meta: '${view.payments.length}',
      child: Column(
        children: <Widget>[
          for (final item in view.payments.take(4)) ...<Widget>[
            SelectRow(
              name: item.merchantName ?? l.paymentsPaymentFallback,
              line: formatDate(item.date, DateStyle.short),
              trailing: MoneyText(
                ValueSpec.real(
                  Money.fromMinor(item.amountMinor, currency),
                ),
                style: AppText.numberXS,
              ),
              onTap: () => _openPayment(item.id),
              semanticLabel: l.paymentsRowSpoken(
                item.merchantName ?? l.paymentsPaymentFallback,
                formatMoney(Money.fromMinor(item.amountMinor, currency)),
              ),
            ),
            const VSpace(Space.xxs),
          ],
          if (widget.onAllPayments != null)
            SelectRow(
              name: l.categoryAllPayments(view.payments.length),
              onTap: () => widget.onAllPayments!(view.id),
              semanticLabel: l.categoryAllPayments(view.payments.length),
            ),
        ],
      ),
    );
  }
}
