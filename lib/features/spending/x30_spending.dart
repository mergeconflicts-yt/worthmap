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
import '../../design/design.dart';
import '../../domain/periods/period_math.dart';
import '../../l10n/generated/app_localizations.dart';
import 'category_style.dart';
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
            kicker: l.spendingSpentKicker,
            actions: <Widget>[
              const HideAmountsButton(),
              if (widget.onEditLimits != null)
                AppIconButton(
                  icon: AppIcons.settings,
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
              _chart(l, view),
              _chips(l),
              _sameDays(l, view),
              _byCategory(l, view),
              ..._rowCards(l, view),
            ],
          ],
        );
      },
    );
  }

  Widget _hero(AppLocalizations l, SpendingView view) {
    final currency = Currency.of(view.currencyCode);
    final hidden = HiddenAmountsScope.resolve(context, null);
    final limit = view.limitMinor;
    final spent = view.moneyOutMinor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ObHero(
          value: spent == null
              ? ValueSpec.noneRecorded(l.spendingNothingRecorded)
              : ValueSpec.real(
                  wholeMoney(Money.fromMinor(spent, currency)),
                ),
          numberSuffix: limit == null
              ? l.spendingNoLimit
              : l.spendingHeroOfLimit(
                  _amount(limit, currency, hidden: false),
                ),
          hiddenNumberSuffix: limit == null
              ? l.spendingNoLimit
              : l.spendingHeroOfLimit(
                  _amount(limit, currency, hidden: true),
                ),
        ),
        const VSpace(Space.xs),
        Text(
          l.spendingRangeStatus(
            formatDateRange(view.rangeStart, view.rangeEnd),
            _limitStatus(l, view, currency, hidden: hidden),
          ),
          style: AppText.caption.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
      ],
    );
  }

  /// SCREENS X30: the current period shows what is left; a closed period says
  /// "within the limit" or how far it is over.
  String _limitStatus(
    AppLocalizations l,
    SpendingView view,
    Currency currency, {
    required bool hidden,
  }) {
    final limit = view.limitMinor;
    if (limit == null) {
      return l.spendingNoLimit;
    }
    final spent = view.moneyOutMinor;
    if (spent == null) {
      return l.spendingNothingRecorded;
    }
    final difference = limit - spent;
    if (difference < 0) {
      return l.spendingOverLimit(
        _amount(-difference, currency, hidden: hidden),
      );
    }
    if (view.partial) {
      return l.spendingLeftAmount(
        _amount(difference, currency, hidden: hidden),
      );
    }
    return l.spendingWithinLimit;
  }

  static String _amount(
    int minor,
    Currency currency, {
    required bool hidden,
  }) {
    final money = wholeMoney(Money.fromMinor(minor, currency));
    if (hidden) {
      return formatValueState(ValueSpec.real(money), hidden: true).text;
    }
    return formatMoney(money, trimZeroFraction: true);
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
    final currency = Currency.of(view.currencyCode);
    final bars = <PeriodBar>[
      for (final bucket in view.buckets)
        PeriodBar(
          label: _bucketLabel(view, bucket),
          amount: wholeMoney(
            Money.fromMinor(bucket.amountMinor ?? 0, currency),
          ),
          current: bucket.lastDate == view.rangeEnd,
          incomplete: view.partial && bucket.lastDate == view.rangeEnd,
        ),
    ];
    final moneyOut = view.moneyOutMinor;
    final average = moneyOut == null || bars.isEmpty
        ? null
        : wholeMoney(Money.fromMinor(moneyOut ~/ bars.length, currency));
    return GlassCard(
      title: l.spendingChartTitle,
      meta: formatDateRange(view.rangeStart, view.rangeEnd),
      child: PeriodBarChart(
        title: l.spendingSpentKicker,
        period: formatDateRange(view.rangeStart, view.rangeEnd),
        bars: bars,
        columns: <String>[l.spendingChartColumn, l.spendingChartAmountColumn],
        average: average,
        averageLabel: l.spendingAverageShort,
        incompleteLabel: view.partial ? l.spendingIncomplete : null,
        emptyLabel: l.spendingNothingRecorded,
      ),
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
                  wholeMoney(Money.fromMinor(-difference, currency)),
                  trimZeroFraction: true,
                ),
              )
            : l.spendingHigherBy(
                formatMoney(
                  wholeMoney(Money.fromMinor(difference, currency)),
                  trimZeroFraction: true,
                ),
              );
    return Text(
      l.spendingSameDaysLine(
        formatMonthShort(previousMonth),
        formatMoney(
          wholeMoney(Money.fromMinor(previous, currency)),
          trimZeroFraction: true,
        ),
        comparison,
      ),
      style: AppText.caption.copyWith(color: context.tokens.textSecondary),
    );
  }

  Widget _byCategory(AppLocalizations l, SpendingView view) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final limits = _controller.limits;
    final currency = Currency.of(view.currencyCode);
    final range = formatDateRange(view.rangeStart, view.rangeEnd);
    final meters = <RingMeter>[];
    for (var i = 0; i < view.categories.length; i += 1) {
      final row = view.categories[i];
      final limit = _controller.limitFor(row.id);
      if (limit <= 0) {
        continue;
      }
      final style = categoryStyleFor(name: row.name, index: i);
      meters.add(
        RingMeter(
          name: row.name.isEmpty ? l.spendingUncategorised : row.name,
          value: wholeMoney(Money.fromMinor(row.amountMinor, currency)),
          limit: wholeMoney(Money.fromMinor(limit, currency)),
          icon: style.icon,
          mark: style.mark,
          iconUsesMark: true,
          variant: RingMeterVariant.card,
          size: 44,
          leftLabel: l.spendingLeftLabel,
          paidLabel: l.spendingPaid,
        ),
      );
    }
    final parts = _needsWants(l, view, currency);
    final empty = Text(
      limits == null || limits.rows.isEmpty
          ? l.spendingNoLimits
          : l.spendingCategoriesWithoutLimit,
      style: AppText.caption.copyWith(
        color: context.tokens.textSecondary,
      ),
    );
    return GlassCard(
      title: l.spendingByCategoryTitle,
      meta: largeText ? null : range,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (parts.isNotEmpty)
            SplitStrip(
              title: l.spendingNeedsWants,
              period: range,
              parts: parts,
              shareDecimals: 1,
              columns: <String>[
                l.homeSplitPart,
                l.homeSplitAmount,
                l.homeSplitShare,
              ],
            ),
          if (parts.isNotEmpty && meters.isNotEmpty) const VSpace(Space.l),
          if (meters.isNotEmpty)
            RingMeterGrid(
              title: l.spendingByCategoryTitle,
              period: range,
              meters: meters,
              maxColumns: 3,
              columns: <String>[
                l.spendingChartColumn,
                l.spendingSpentKicker,
                l.spendingLimitLabel,
                l.spendingLeftLabel,
              ],
              paidLabel: l.spendingPaid,
              leftLabel: l.spendingLeftLabel,
              emptyLabel: l.spendingNothingRecorded,
            )
          else ...<Widget>[
            empty,
            if (widget.onEditLimits != null) ...<Widget>[
              const VSpace(Space.s),
              AppButton(
                label: l.spendingAddLimit,
                variant: AppButtonVariant.ghost,
                onPressed: widget.onEditLimits,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// SPEC 4.4: Needs and Wants are the user's tags; untagged spending keeps an
  /// honest third part so the strip is the whole of the period.
  List<SplitStripPart> _needsWants(
    AppLocalizations l,
    SpendingView view,
    Currency currency,
  ) {
    var needs = 0;
    var wants = 0;
    var unclassified = 0;
    for (final row in view.categories) {
      if (row.isEssential == true) {
        needs += row.amountMinor;
      } else if (row.isEssential == false) {
        wants += row.amountMinor;
      } else {
        unclassified += row.amountMinor;
      }
    }
    return <SplitStripPart>[
      if (needs > 0)
        SplitStripPart(
          name: l.homeSplitNeeds,
          amount: wholeMoney(Money.fromMinor(needs, currency)),
          mark: ChartMark.needs,
        ),
      if (wants > 0)
        SplitStripPart(
          name: l.homeSplitWants,
          amount: wholeMoney(Money.fromMinor(wants, currency)),
          mark: ChartMark.wants,
        ),
      if (unclassified > 0)
        SplitStripPart(
          name: l.homeSplitUnclassified,
          amount: wholeMoney(Money.fromMinor(unclassified, currency)),
          mark: ChartMark.other,
        ),
    ];
  }

  /// X30 rows, in the three groups of the reference: Repeating and Money in,
  /// Where it goes and Budget, All payments and Edit limits.
  List<Widget> _rowCards(AppLocalizations l, SpendingView view) {
    final rows = _controller.rows;
    final month = rows?.month ?? view.month;
    final monthName = formatMonthLong(month);
    final currency = Currency.of(view.currencyCode);
    final hidden = HiddenAmountsScope.resolve(context, null);
    final cards = <Widget>[];

    final first = <Widget>[
      if (widget.onRepeating != null)
        SelectRow(
          name: l.spendingRepeatingRow,
          line: rows == null
              ? null
              : rows.repeatingCount == 0
                  ? l.repeatingEmpty
                  : l.spendingRepeatingRowLine(
                      rows.repeatingCount,
                      rows.repeatingChanges,
                    ),
          trailing: rows == null || rows.repeatingCount == 0
              ? null
              : _perMonthTrailing(l, rows.repeatingMonthlyMinor, currency),
          onTap: widget.onRepeating,
          semanticLabel: l.spendingRepeatingRow,
          stackValue: true,
        ),
      if (widget.onMoneyIn != null)
        SelectRow(
          name: l.spendingMoneyInRow,
          line: rows?.moneyInAverageMinor == null
              ? monthName
              : l.spendingMoneyInRowLine(
                  monthName,
                  _averageText(rows!.moneyInAverageMinor!, currency, hidden),
                ),
          trailing: _moneyTrailing(rows?.moneyInMinor, currency),
          onTap: widget.onMoneyIn,
          semanticLabel: l.spendingMoneyInRow,
          stackValue: true,
        ),
    ];
    if (first.isNotEmpty) {
      cards.add(
        GlassCard(
          variant: GlassCardVariant.list,
          child: Column(children: first),
        ),
      );
    }

    final second = <Widget>[
      if (widget.onWhereItGoes != null)
        SelectRow(
          name: l.spendingWhereItGoes,
          line: l.spendingWhereRowLine(monthName),
          trailing: Text(
            '${rows?.whereCount ?? view.categories.length}',
            style: _rowValueStyle,
          ),
          onTap: widget.onWhereItGoes,
          semanticLabel: l.spendingWhereItGoes,
          stackValue: true,
        ),
      if (widget.onBudget != null)
        SelectRow(
          name: l.spendingBudgetRow,
          line: l.spendingBudgetRowLine(monthName),
          trailing: _moneyTrailing(rows?.leftMinor, currency),
          onTap: widget.onBudget,
          semanticLabel: l.spendingBudgetRow,
          stackValue: true,
        ),
    ];
    if (second.isNotEmpty) {
      cards.add(
        GlassCard(
          variant: GlassCardVariant.list,
          child: Column(children: second),
        ),
      );
    }

    final third = <Widget>[
      if (widget.onAllPayments != null)
        SelectRow(
          name: l.spendingAllPaymentsRow,
          line: monthName,
          trailing: rows?.paymentsCount == null
              ? null
              : Text('${rows!.paymentsCount}', style: _rowValueStyle),
          onTap: widget.onAllPayments,
          semanticLabel: l.spendingAllPaymentsRow,
          stackValue: true,
        ),
      if (widget.onEditLimits != null)
        SelectRow(
          name: l.spendingEditLimitsRow,
          line: l.spendingCategoriesLine(
            _controller.limits?.categoryCount ?? 0,
          ),
          trailing: _moneyTrailing(rows?.limitMinor, currency),
          onTap: widget.onEditLimits,
          semanticLabel: l.spendingEditLimitsRow,
          stackValue: true,
        ),
    ];
    if (third.isNotEmpty) {
      cards.add(
        GlassCard(
          variant: GlassCardVariant.list,
          child: Column(children: third),
        ),
      );
    }
    return cards;
  }

  TextStyle get _rowValueStyle => AppText.bodyStrong.copyWith(
        color: context.tokens.textPrimary,
      );

  Widget? _moneyTrailing(int? minor, Currency currency) {
    if (minor == null) {
      return null;
    }
    return MoneyText(
      ValueSpec.real(wholeMoney(Money.fromMinor(minor, currency))),
      trimZeroFraction: true,
      style: _rowValueStyle,
    );
  }

  Widget? _perMonthTrailing(
    AppLocalizations l,
    int? minor,
    Currency currency,
  ) {
    final amount = _moneyTrailing(minor, currency);
    if (amount == null) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        amount,
        Text(' ${l.spendingPerMonth}', style: _rowValueStyle),
      ],
    );
  }

  String _averageText(int minor, Currency currency, bool hidden) {
    final money = wholeMoney(Money.fromMinor(minor, currency));
    if (hidden) {
      return formatValueState(ValueSpec.real(money), hidden: true).text;
    }
    return formatMoney(money, trimZeroFraction: true);
  }

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
