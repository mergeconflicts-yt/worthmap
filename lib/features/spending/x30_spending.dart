// P26 (SCREEN X30; flow F08 steps 1–2; SPEC 4.4, 6.5): the Spending root.
//
// The screen reads one controller. The period chips change the numbers; the
// chart, the rings and the table use the same period. The Search control is
// absent until X15 ships (P2-SEARCH-ENTRY) and "Next income" is absent until
// Phase 4 (P2-SPEND-NEXT-INCOME).
library;

import 'package:flutter/material.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/percent.dart';
import '../../design/design.dart';
import '../../domain/periods/period_math.dart';
import '../../l10n/generated/app_localizations.dart';
import 'spending_controller.dart';
import 'spending_models.dart';

/// X30: period hero, chips, chart, category rings and detail rows.
class X30Spending extends StatefulWidget {
  const X30Spending({
    required this.gateway,
    this.onWhereItGoes,
    this.onAllPayments,
    this.onRepeating,
    this.onMoneyIn,
    this.onBudget,
    this.onEditLimits,
    this.controller,
    super.key,
  });

  final SpendingGateway gateway;
  final VoidCallback? onWhereItGoes;
  final VoidCallback? onAllPayments;
  final VoidCallback? onRepeating;
  final VoidCallback? onMoneyIn;
  final VoidCallback? onBudget;
  final VoidCallback? onEditLimits;

  /// Test and golden seam: a prepared controller. The caller owns it.
  final SpendingController? controller;

  @override
  State<X30Spending> createState() => _X30SpendingState();
}

class _X30SpendingState extends State<X30Spending> {
  late final SpendingController _controller =
      widget.controller ?? SpendingController(gateway: widget.gateway);

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
        return TabRootScreen(
          header: ScreenHeader(
            title: l.spendingTitle,
            dateLine: view == null
                ? null
                : formatDateRange(view.rangeStart, view.rangeEnd),
            actions: <Widget>[
              const HideAmountsButton(),
              if (widget.onEditLimits != null)
                AppIconButton(
                  icon: AppIcons.filter,
                  variant: AppIconButtonVariant.onPage,
                  semanticLabel: l.spendingEditLimitsRow,
                  onPressed: widget.onEditLimits,
                ),
            ],
          ),
          children: <Widget>[
            if (_controller.state == SpendingLoadState.loading)
              Text(l.spendingLoading, style: AppText.caption)
            else if (_controller.state == SpendingLoadState.failed) ...<Widget>[
              Text(l.spendingLoadFailed, style: AppText.bodyStrong),
              AppButton(
                label: l.spendingRetry,
                variant: AppButtonVariant.soft,
                onPressed: _controller.load,
              ),
            ] else if (view != null) ...<Widget>[
              _hero(l, view),
              _chips(l),
              _chart(l, view),
              _sameDays(l, view),
              _byCategory(l, view),
              _rows(l, view),
            ],
          ],
        );
      },
    );
  }

  Widget _hero(AppLocalizations l, SpendingView view) {
    final money = view.moneyOutMinor;
    final limit = view.limitMinor;
    final left = view.leftMinor;
    final line = <String>[
      formatDateRange(view.rangeStart, view.rangeEnd),
      if (limit != null && left != null && left >= 0)
        l.spendingHeroLimitLine(
          formatMoney(
            Money.fromMinor(left, Currency.of(view.currencyCode)),
          ),
          formatMoney(
            Money.fromMinor(limit, Currency.of(view.currencyCode)),
          ),
        )
      else if (limit != null)
        l.spendingHeroLimitLine(
          formatMoney(Money.fromMinor(0, Currency.of(view.currencyCode))),
          formatMoney(
            Money.fromMinor(limit, Currency.of(view.currencyCode)),
          ),
        )
      else
        l.spendingNoLimit,
    ].join(' · ');
    return ObHero(
      kicker: l.spendingSpentKicker,
      value: money == null
          ? ValueSpec.noneRecorded(l.spendingNothingRecorded)
          : ValueSpec.real(
              Money.fromMinor(money, Currency.of(view.currencyCode)),
            ),
      contextLine: line,
      backgroundChart: _chartWidget(l, view, preview: true, height: 120),
    );
  }

  Widget _chips(AppLocalizations l) {
    const periods = <SpendingPeriod>[
      SpendingPeriod.week,
      SpendingPeriod.month,
      SpendingPeriod.sixMonths,
      SpendingPeriod.year,
    ];
    return ChipRow(
      items: <ChipItem>[
        for (final period in periods)
          ChipItem(
            label: _chipLabel(l, period),
            semanticLabel: _chipSpoken(l, period),
            variant: ChipVariant.choice,
            selected: period == _controller.period,
            onPressed: () => _controller.selectPeriod(period),
          ),
      ],
    );
  }

  Widget _chart(AppLocalizations l, SpendingView view) {
    return GlassCard(
      title: l.spendingChartTitle,
      meta: formatDateRange(view.rangeStart, view.rangeEnd),
      child: _chartWidget(l, view),
    );
  }

  Widget _chartWidget(
    AppLocalizations l,
    SpendingView view, {
    bool preview = false,
    double height = 160,
  }) {
    final currency = Currency.of(view.currencyCode);
    final bars = <PeriodBar>[
      for (final bucket in view.buckets)
        PeriodBar(
          label: _bucketLabel(view, bucket),
          amount: Money.fromMinor(bucket.amountMinor ?? 0, currency),
          current: bucket.lastDate == view.rangeEnd,
          incomplete: view.partial && bucket.lastDate == view.rangeEnd,
        ),
    ];
    final moneyOut = view.moneyOutMinor;
    final average = moneyOut == null || bars.isEmpty
        ? null
        : Money.fromMinor(moneyOut ~/ bars.length, currency);
    return PeriodBarChart(
      title: l.spendingSpentKicker,
      period: formatDateRange(view.rangeStart, view.rangeEnd),
      bars: bars,
      columns: <String>[l.spendingChartColumn, l.spendingChartAmountColumn],
      average: average,
      averageLabel: l.spendingAverageShort,
      incompleteLabel: view.partial ? l.spendingIncomplete : null,
      emptyLabel: l.spendingNothingRecorded,
      preview: preview,
      height: height,
    );
  }

  Widget _sameDays(AppLocalizations l, SpendingView view) {
    if (HiddenAmountsScope.resolve(context, null)) {
      return Text(
        l.spendingSameDaysHidden,
        style: AppText.caption.copyWith(color: context.tokens.textSecondary),
      );
    }
    final previous = view.sameDaysPreviousMinor;
    final spent = view.moneyOutMinor;
    if (previous == null || spent == null) {
      return const SizedBox.shrink();
    }
    final currency = Currency.of(view.currencyCode);
    final previousMonth = addMonths(
      LocalDate(view.rangeStart.year, view.rangeStart.month, 1),
      -1,
    );
    final difference = spent - previous;
    final comparison = difference == 0
        ? l.spendingSameAmount
        : difference < 0
            ? l.spendingLowerBy(
                formatMoney(
                  Money.fromMinor(-difference, currency),
                ),
              )
            : l.spendingHigherBy(
                formatMoney(
                  Money.fromMinor(difference, currency),
                ),
              );
    return Text(
      l.spendingSameDaysLine(
        formatMonthShort(previousMonth),
        formatMoney(Money.fromMinor(previous, currency)),
        comparison,
      ),
      style: AppText.caption.copyWith(color: context.tokens.textSecondary),
    );
  }

  Widget _byCategory(AppLocalizations l, SpendingView view) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final limits = _controller.limits;
    final currency = Currency.of(view.currencyCode);
    final meters = <RingMeter>[];
    for (final row in view.categories) {
      final limit = _controller.limitFor(row.id);
      if (limit <= 0) {
        continue;
      }
      meters.add(
        RingMeter(
          name: row.name.isEmpty ? l.spendingUncategorised : row.name,
          value: Money.fromMinor(row.amountMinor, currency),
          limit: Money.fromMinor(limit, currency),
          todayShare:
              view.monthGone == null ? null : _fraction(view.monthGone!),
          leftLabel: l.spendingLeftLabel,
          paidLabel: l.spendingPaid,
        ),
      );
    }
    if (meters.isEmpty) {
      return GlassCard(
        title: l.spendingByCategoryTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              limits == null || limits.rows.isEmpty
                  ? l.spendingNoLimits
                  : l.spendingCategoriesWithoutLimit,
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
            if (widget.onEditLimits != null) ...<Widget>[
              const VSpace(Space.s),
              AppButton(
                label: l.spendingAddLimit,
                variant: AppButtonVariant.ghost,
                onPressed: widget.onEditLimits,
              ),
            ],
          ],
        ),
      );
    }
    return GlassCard(
      title: l.spendingByCategoryTitle,
      meta: largeText ? null : formatDateRange(view.rangeStart, view.rangeEnd),
      child: RingMeterGrid(
        title: l.spendingByCategoryTitle,
        period: formatDateRange(view.rangeStart, view.rangeEnd),
        meters: meters,
        columns: <String>[
          l.spendingChartColumn,
          l.spendingSpentKicker,
          l.spendingLimitLabel,
          l.spendingLeftLabel,
        ],
        paidLabel: l.spendingPaid,
        leftLabel: l.spendingLeftLabel,
        emptyLabel: l.spendingNothingRecorded,
      ),
    );
  }

  Widget _rows(AppLocalizations l, SpendingView view) {
    final currency = Currency.of(view.currencyCode);
    return GlassCard(
      child: Column(
        children: <Widget>[
          if (widget.onWhereItGoes != null)
            SelectRow(
              name: l.spendingWhereItGoes,
              line: formatDateRange(view.rangeStart, view.rangeEnd),
              onTap: widget.onWhereItGoes,
              semanticLabel: l.spendingWhereItGoes,
            ),
          if (widget.onBudget != null)
            SelectRow(
              name: l.spendingBudgetRow,
              trailing: view.leftMinor == null
                  ? null
                  : MoneyText(
                      ValueSpec.real(
                        Money.fromMinor(view.leftMinor!, currency),
                      ),
                      style: AppText.body.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
              onTap: widget.onBudget,
              semanticLabel: l.spendingBudgetRow,
            ),
          if (widget.onMoneyIn != null)
            SelectRow(
              name: l.spendingMoneyInRow,
              onTap: widget.onMoneyIn,
              semanticLabel: l.spendingMoneyInRow,
            ),
          if (widget.onAllPayments != null)
            SelectRow(
              name: l.spendingAllPaymentsRow,
              line: formatDateRange(view.rangeStart, view.rangeEnd),
              onTap: widget.onAllPayments,
              semanticLabel: l.spendingAllPaymentsRow,
            ),
          if (widget.onRepeating != null)
            SelectRow(
              name: l.spendingRepeatingRow,
              onTap: widget.onRepeating,
              semanticLabel: l.spendingRepeatingRow,
            ),
          if (widget.onEditLimits != null)
            SelectRow(
              name: l.spendingEditLimitsRow,
              trailing: view.limitMinor == null
                  ? null
                  : MoneyText(
                      ValueSpec.real(
                        Money.fromMinor(view.limitMinor!, currency),
                      ),
                      style: AppText.body.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
              onTap: widget.onEditLimits,
              semanticLabel: l.spendingEditLimitsRow,
            ),
        ],
      ),
    );
  }

  static double _fraction(Percent percent) => percent.value.toDouble() / 100;

  static String _chipLabel(AppLocalizations l, SpendingPeriod period) =>
      switch (period) {
        SpendingPeriod.week => l.spendingPeriodWeek,
        SpendingPeriod.month => l.spendingPeriodMonth,
        SpendingPeriod.sixMonths => l.spendingPeriodSixMonths,
        SpendingPeriod.year => l.spendingPeriodYear,
      };

  static String _chipSpoken(AppLocalizations l, SpendingPeriod period) =>
      switch (period) {
        SpendingPeriod.week => l.spendingPeriodWeekSpoken,
        SpendingPeriod.month => l.spendingPeriodMonthSpoken,
        SpendingPeriod.sixMonths => l.spendingPeriodSixMonthsSpoken,
        SpendingPeriod.year => l.spendingPeriodYearSpoken,
      };

  static String _bucketLabel(SpendingView view, SpendingBucketView bucket) {
    if (view.period == SpendingPeriod.sixMonths ||
        view.period == SpendingPeriod.year) {
      return formatMonthShort(bucket.firstDate);
    }
    return bucket.firstDate.day.toString();
  }
}
