// P26 (SCREEN X31; flow F08 step 5; SPEC 4.4): money in.
//
// The screen shows income only (transfers, refunds, loan money and sale
// proceeds are not income). The kept line is money in less money out. The
// invested split and the sources list wait for Phase 4 (P26-MONEY-IN-SPLIT).
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/percent.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'spending_controller.dart';
import 'spending_models.dart';

/// X31: the money-in hero, its chart and the kept line.
class X31MoneyIn extends StatefulWidget {
  const X31MoneyIn({
    required this.gateway,
    required this.onClose,
    this.controller,
    super.key,
  });

  final SpendingGateway gateway;
  final VoidCallback onClose;
  final MoneyInController? controller;

  @override
  State<X31MoneyIn> createState() => _X31MoneyInState();
}

class _X31MoneyInState extends State<X31MoneyIn> {
  late final MoneyInController _controller =
      widget.controller ?? MoneyInController(gateway: widget.gateway);

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
        final spending = _controller.spending;
        return DetailScreen(
          header: ScreenHeader(
            title: l.spendingMoneyInTitle,
            dateLine: view == null
                ? null
                : formatDateRange(view.rangeStart, view.rangeEnd),
            leading: AppIconButton(
              icon: AppIcons.back,
              semanticLabel: l.spendingBack,
              onPressed: widget.onClose,
            ),
          ),
          children: <Widget>[
            if (_controller.state == SpendingLoadState.failed) ...<Widget>[
              Text(l.spendingLoadFailed, style: AppText.bodyStrong),
              AppButton(
                label: l.spendingRetry,
                variant: AppButtonVariant.soft,
                onPressed: _controller.load,
              ),
            ] else if (view == null) ...<Widget>[
              Text(l.spendingLoading, style: AppText.caption),
            ] else ...<Widget>[
              _hero(l, view),
              _chips(l),
              _chart(l, view),
              if (spending != null) _kept(l, view, spending),
            ],
          ],
        );
      },
    );
  }

  Widget _hero(AppLocalizations l, MoneyInView view) {
    final amount = view.amountMinor;
    return ObHero(
      kicker: l.spendingMoneyInKicker,
      value: amount == null
          ? ValueSpec.noneRecorded(l.spendingMoneyInNothing)
          : ValueSpec.real(
              Money.fromMinor(amount, Currency.of(view.currencyCode)),
            ),
      contextLine: formatDateRange(view.rangeStart, view.rangeEnd),
    );
  }

  Widget _chips(AppLocalizations l) {
    const periods = <SpendingPeriod>[
      SpendingPeriod.month,
      SpendingPeriod.sixMonths,
      SpendingPeriod.year,
    ];
    return ChipRow(
      items: <ChipItem>[
        for (final period in periods)
          ChipItem(
            label: switch (period) {
              SpendingPeriod.month => l.spendingPeriodMonth,
              SpendingPeriod.sixMonths => l.spendingPeriodSixMonths,
              _ => l.spendingPeriodYear,
            },
            semanticLabel: switch (period) {
              SpendingPeriod.month => l.spendingPeriodMonthSpoken,
              SpendingPeriod.sixMonths => l.spendingPeriodSixMonthsSpoken,
              _ => l.spendingPeriodYearSpoken,
            },
            variant: ChipVariant.choice,
            selected: period == _controller.period,
            onPressed: () => _controller.selectPeriod(period),
          ),
      ],
    );
  }

  Widget _chart(AppLocalizations l, MoneyInView view) {
    final currency = Currency.of(view.currencyCode);
    return GlassCard(
      title: l.spendingMoneyInChartTitle,
      meta: formatDateRange(view.rangeStart, view.rangeEnd),
      child: PeriodBarChart(
        title: l.spendingMoneyInChartTitle,
        period: formatDateRange(view.rangeStart, view.rangeEnd),
        bars: <PeriodBar>[
          for (final bucket in view.buckets)
            PeriodBar(
              label: view.period == SpendingPeriod.month
                  ? bucket.firstDate.day.toString()
                  : formatMonthShort(bucket.firstDate),
              amount: Money.fromMinor(
                bucket.amountMinor ?? 0,
                currency,
              ),
              current: bucket.lastDate == view.rangeEnd,
            ),
        ],
        columns: <String>[
          view.period == SpendingPeriod.month
              ? l.spendingChartColumn
              : l.spendingChartMonthColumn,
          l.spendingChartAmountColumn,
        ],
        emptyLabel: l.spendingMoneyInNothing,
        mark: ChartMark.moneyIn,
      ),
    );
  }

  Widget _kept(
    AppLocalizations l,
    MoneyInView view,
    SpendingView spending,
  ) {
    final moneyIn = view.amountMinor;
    final moneyOut = spending.moneyOutMinor;
    if (moneyIn == null || moneyOut == null || moneyOut > moneyIn) {
      return const SizedBox.shrink();
    }
    final currency = Currency.of(view.currencyCode);
    final kept = moneyIn - moneyOut;
    final percent = Percent.fromFraction(
      (Decimal.fromInt(kept) / Decimal.fromInt(moneyIn))
          .toDecimal(scaleOnInfinitePrecision: 6),
    );
    return Text(
      l.spendingKeptLine(
        formatMoney(Money.fromMinor(kept, currency)),
        formatPercent(percent),
      ),
      style: AppText.caption.copyWith(
        color: context.tokens.textSecondary,
      ),
    );
  }
}
