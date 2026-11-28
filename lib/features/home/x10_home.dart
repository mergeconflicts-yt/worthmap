// Phase 4 (SCREENS X10; SPEC 6.1): Home with data.
//
// One hero number (net worth), its 12-month line, Quick look tiles, the next
// 30 days, this month and the footer facts. Every value is a read. Missing
// balances stay Missing. Amounts use MoneyText, so the hidden state masks
// them.
library;

import 'package:flutter/material.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/dates.dart';
import '../../core/decimal.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../domain/periods/period_math.dart';
import '../../l10n/generated/app_localizations.dart';
import 'home_models.dart';

/// X10: Home with real records.
class X10Home extends StatefulWidget {
  const X10Home({
    required this.gateway,
    required this.onInbox,
    required this.onSettings,
    required this.onSpending,
    this.today,
    super.key,
  });

  final HomeGateway gateway;
  final VoidCallback onInbox;
  final VoidCallback onSettings;
  final VoidCallback onSpending;

  /// The date line date. Null reads the local clock at the app boundary.
  final LocalDate? today;

  @override
  State<X10Home> createState() => _X10HomeState();
}

class _X10HomeState extends State<X10Home> {
  HomeSummary? _summary;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await widget.gateway.load();
      if (!mounted) return;
      setState(() => _summary = summary);
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final summary = _summary;
    final today = widget.today ?? _localToday();
    return TabRootScreen(
      header: ScreenHeader(
        kicker: l.x10Kicker,
        actions: <Widget>[
          const HideAmountsButton(),
          AppIconButton(
            icon: AppIcons.inbox,
            badgeCount: summary?.inboxCount ?? 0,
            semanticLabel: l.x10SpokenInbox(summary?.inboxCount ?? 0),
            onPressed: widget.onInbox,
          ),
          AppIconButton(
            icon: AppIcons.settings,
            semanticLabel: l.x03SettingsAction,
            onPressed: widget.onSettings,
          ),
        ],
      ),
      children: <Widget>[
        if (summary == null)
          GlassCard(
            child: Text(
              _failed ? l.spendingLoadFailed : l.spendingLoading,
              style: AppText.body,
            ),
          )
        else ...<Widget>[
          _topSection(l, summary),
          _quickLook(l, summary),
          _upcoming(l, summary, today),
          _thisMonth(l, summary),
          AppButton(
            label: l.x10OpenSpending,
            variant: AppButtonVariant.ghost,
            onPressed: widget.onSpending,
          ),
          Text(
            l.homeFooterAccounts(summary.accountCount),
            textAlign: TextAlign.center,
            style:
                AppText.caption.copyWith(color: context.tokens.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _topSection(AppLocalizations l, HomeSummary summary) {
    final target = _targetLine(l, summary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _hero(l, summary),
        if (target != null) ...<Widget>[
          const VSpace(Space.xs),
          target,
        ],
        const VSpace(Space.s),
        _netWorthLine(l, summary),
      ],
    );
  }

  Widget _hero(AppLocalizations l, HomeSummary summary) {
    final currency = Currency.of(summary.currencyCode);
    final netWorth = summary.netWorthMinor;
    final change = summary.netWorthChangeMinor;
    final tokens = context.tokens;
    final largeText = MediaQuery.textScalerOf(context).scale(13) >= 13 * 1.3;
    final hero = ObHero(
      value: netWorth == null
          ? ValueSpec.missing(l.x10NoBalance)
          : ValueSpec.real(_whole(Money.fromMinor(netWorth, currency))),
      minFontSize: 28,
    );
    if (change == null) return hero;
    final changeColour = change < 0 ? tokens.stateLoss : tokens.stateGain;
    final side = Column(
      crossAxisAlignment:
          largeText ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: <Widget>[
        MoneyText(
          ValueSpec.real(_whole(Money.fromMinor(change, currency))),
          sign: SignStyle.always,
          // SCREENS X10: "+$16,900 · 12 months"; cents only when real.
          trimZeroFraction: true,
          style: AppText.bodyStrong.copyWith(color: changeColour),
        ),
        Text(
          l.homeTwelveMonths,
          style: AppText.caption.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          hero,
          const VSpace(Space.s),
          side,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: hero),
        const HSpace(Space.s),
        side,
      ],
    );
  }

  /// SCREENS X10: the target line appears only when a target exists and net
  /// worth is known. It opens Goals when that screen ships (v1.1).
  Widget? _targetLine(AppLocalizations l, HomeSummary summary) {
    final target = summary.netWorthTarget;
    final share = target?.share;
    if (target == null || share == null) return null;
    final currency = Currency.of(summary.currencyCode);
    final hidden = HiddenAmountsScope.resolve(context, null);
    final targetMoney = _whole(Money.fromMinor(target.amountMinor, currency));
    final date = formatMonthYear(target.date);
    final percent = formatPercent(share, decimals: 0);
    final targetText = hidden
        ? formatValueState(ValueSpec.real(targetMoney), hidden: true).text
        : formatMoney(targetMoney, trimZeroFraction: true);
    return TargetProgressLine(
      share: share,
      label: l.netWorthTargetLine(percent, targetText, date),
      semanticLabel: hidden
          ? l.netWorthTargetLine(percent, amountHiddenLabel, date)
          : null,
    );
  }

  Widget _netWorthLine(AppLocalizations l, HomeSummary summary) {
    final currency = Currency.of(summary.currencyCode);
    return AreaLineChart(
      title: l.homeNetWorthChart,
      variant: LineChartVariant.line,
      // Decreased from the 96 default (owner's mockup).
      height: 72,
      points: <LinePoint>[
        for (final point in summary.netWorthSeries)
          LinePoint(
            label: formatMonthShort(point.month),
            amount: point.amountMinor == null
                ? null
                : _whole(Money.fromMinor(point.amountMinor!, currency)),
          ),
      ],
    );
  }

  Widget _quickLook(AppLocalizations l, HomeSummary summary) {
    final currency = Currency.of(summary.currencyCode);
    final hidden = HiddenAmountsScope.resolve(context, null);
    final tokens = context.tokens;
    final investmentsToday = summary.investmentsTodayMinor;
    final investmentsTodayMoney = investmentsToday == null
        ? null
        : _whole(Money.fromMinor(investmentsToday, currency));
    final investmentsLine = investmentsTodayMoney == null
        ? null
        : hidden
            ? l.homeInvestmentsToday(
                formatValueState(
                  ValueSpec.real(investmentsTodayMoney),
                  hidden: true,
                ).text,
              )
            : l.homeInvestmentsToday(
                formatMoney(
                  investmentsTodayMoney,
                  sign: investmentsToday! > 0
                      ? SignStyle.always
                      : SignStyle.negativeOnly,
                  trimZeroFraction: true,
                ),
              );
    final investmentsLineColour =
        investmentsToday == null || investmentsToday == 0
            ? tokens.textSecondary
            : investmentsToday > 0
                ? tokens.stateGain
                : tokens.stateLoss;
    Widget amount(int? minor) => minor == null
        ? const Text('—')
        : MoneyText(
            ValueSpec.real(_whole(Money.fromMinor(minor, currency))),
            trimZeroFraction: true,
          );
    String spoken(String label, int? minor) {
      if (hidden) return label;
      if (minor == null) return '$label, —';
      return l.homeTileSpoken(
        label,
        formatMoney(
          _whole(Money.fromMinor(minor, currency)),
          trimZeroFraction: true,
        ),
      );
    }

    return GlassCard(
      title: l.x10QuickLook,
      meta: l.homeQuickLookMeta,
      child: HomeTileGrid(
        spokenLabels: <String>[
          spoken(l.x10Cash, summary.cashMinor),
          spoken(l.x10CardBill, summary.cardOwedMinor),
          spoken(l.x10Investments, summary.investmentsMinor),
          spoken(l.x10Subscriptions, summary.subscriptionsMonthlyMinor),
        ],
        tiles: <HomeTile>[
          HomeTile(
            icon: AppIcons.bank,
            label: l.x10Cash,
            value: amount(summary.cashMinor),
            line: l.homeCashLine,
          ),
          HomeTile(
            icon: AppIcons.card,
            label: l.x10CardBill,
            value: amount(summary.cardOwedMinor),
            line: summary.cardName,
          ),
          HomeTile(
            icon: AppIcons.chart,
            label: l.x10Investments,
            value: amount(summary.investmentsMinor),
            line: investmentsLine,
            lineColor: investmentsLineColour,
          ),
          HomeTile(
            icon: AppIcons.repeat,
            label: l.x10Subscriptions,
            value: amount(summary.subscriptionsMonthlyMinor),
            line: l.homeSubscriptionsLine,
          ),
        ],
      ),
    );
  }

  Widget _upcoming(
    AppLocalizations l,
    HomeSummary summary,
    LocalDate today,
  ) {
    final end = LocalDate(
      today.year,
      today.month,
      today.day,
    );
    return GlassCard(
      title: l.homeTimelineTitle,
      meta: l.homeDueBefore(
        formatDate(addDays(end, 30), DateStyle.short),
      ),
      child: GlyphTimeline(
        title: l.homeTimelineTitle,
        windowLabel: formatDateRange(today, addDays(end, 30)),
        start: today,
        // The next-income day is not in the read model yet; the track stays
        // solid until the model carries it.
        incomeDayIndex: null,
        emptyLabel: l.homeTimelineEmpty,
        items: <TimelineItem>[
          for (final item in summary.upcoming)
            TimelineItem(
              dayIndex: _daysBetween(today, item.date),
              dateLabel: formatDate(item.date, DateStyle.short),
              name: item.name,
              amount: item.amountMinor == null
                  ? null
                  : _whole(
                      Money.fromMinor(
                        item.amountMinor!,
                        Currency.of(item.currencyCode),
                      ),
                    ),
              mark: _markOf(item.kind),
            ),
        ],
      ),
    );
  }

  Widget _thisMonth(AppLocalizations l, HomeSummary summary) {
    final currency = Currency.of(summary.currencyCode);
    final spent = summary.spentMinor;
    final limit = summary.limitMinor;
    final used = summary.used;
    final split = summary.incomeSplit;
    final hidden = HiddenAmountsScope.resolve(context, null);
    final percent = used == null ? null : formatPercent(used, decimals: 0);
    final spentLine = limit == null || percent == null
        ? l.x10NoLimit
        : l.x10SpentOfLimit(
            hidden
                ? amountHiddenLabel
                : formatMoney(
                    _whole(Money.fromMinor(limit, currency)),
                    trimZeroFraction: true,
                  ),
            percent,
          );
    final moneyIn = summary.moneyInMinor;
    final spentSpoken = hidden
        ? l.x10Spent
        : spent == null
            ? '$l.x10Spent, —'
            : '${l.homeTileSpoken(
                l.x10Spent,
                formatMoney(
                  _whole(Money.fromMinor(spent, currency)),
                  trimZeroFraction: true,
                ),
              )}. $spentLine';
    return GlassCard(
      title: l.x10ThisMonth,
      meta: l.x10DayOf(summary.monthDay, summary.monthDays),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HomeTileGrid(
            spokenLabels: <String>[
              moneyIn == null
                  ? '$l.x10MoneyIn, —'
                  : hidden
                      ? l.x10MoneyIn
                      : l.homeTileSpoken(
                          l.x10MoneyIn,
                          formatMoney(
                            _whole(Money.fromMinor(moneyIn, currency)),
                            trimZeroFraction: true,
                          ),
                        ),
              spentSpoken,
            ],
            tiles: <HomeTile>[
              HomeTile(
                label: l.x10MoneyIn,
                openBottom: true,
                value: moneyIn == null
                    ? const Text('—')
                    : MoneyText(
                        ValueSpec.real(
                          _whole(Money.fromMinor(moneyIn, currency)),
                        ),
                        trimZeroFraction: true,
                      ),
                valueStyle: AppText.numberL,
              ),
              HomeTile(
                label: l.x10Spent,
                openBottom: true,
                value: spent == null
                    ? const Text('—')
                    : MoneyText(
                        ValueSpec.real(
                          _whole(Money.fromMinor(spent, currency)),
                        ),
                        trimZeroFraction: true,
                      ),
                line: spent == null ? null : spentLine,
                footer: spent == null || limit == null || limit <= 0
                    ? null
                    : CapsuleMeter(
                        value: spent,
                        limit: limit,
                        today: summary.monthGone,
                        spokenLabel: spentLine,
                      ),
                valueStyle: AppText.numberL,
              ),
            ],
          ),
          if (split != null) ...<Widget>[
            const VSpace(Space.l),
            SplitStrip(
              title: l.homeIncomeSplit,
              period: formatMonthShort(summary.month),
              shareDecimals: 0,
              parts: <SplitStripPart>[
                if (split.needsMinor > 0)
                  SplitStripPart(
                    name: l.homeSplitNeeds,
                    amount: _whole(
                      Money.fromMinor(
                        split.needsMinor,
                        Currency.of(split.currencyCode),
                      ),
                    ),
                    mark: ChartMark.needs,
                  ),
                if (split.wantsMinor > 0)
                  SplitStripPart(
                    name: l.homeSplitWants,
                    amount: _whole(
                      Money.fromMinor(
                        split.wantsMinor,
                        Currency.of(split.currencyCode),
                      ),
                    ),
                    mark: ChartMark.wants,
                  ),
                if (split.unclassifiedMinor > 0)
                  SplitStripPart(
                    name: l.homeSplitUnclassified,
                    amount: _whole(
                      Money.fromMinor(
                        split.unclassifiedMinor,
                        Currency.of(split.currencyCode),
                      ),
                    ),
                    mark: ChartMark.other,
                  ),
                if (split.investedMinor > 0)
                  SplitStripPart(
                    name: l.homeSplitInvested,
                    amount: _whole(
                      Money.fromMinor(
                        split.investedMinor,
                        Currency.of(split.currencyCode),
                      ),
                    ),
                    mark: ChartMark.invested,
                  ),
                if (split.inCashMinor > 0)
                  SplitStripPart(
                    name: l.homeSplitInCash,
                    amount: _whole(
                      Money.fromMinor(
                        split.inCashMinor,
                        Currency.of(split.currencyCode),
                      ),
                    ),
                    mark: ChartMark.inCash,
                  ),
              ],
              columns: <String>[
                l.homeSplitPart,
                l.homeSplitAmount,
                l.homeSplitShare,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// X10 shows whole currency units (owner request, 23 Nov 2026; DECISIONS
/// P4-HOME-MONTH). One half-up rounding feeds the pixels and the spoken
/// amount, so no number shows a decimal.
Money _whole(Money money) => Money.fromDecimal(
      roundToScale(money.toDecimal(), 0, RoundingMode.halfUp),
      money.currency,
      mode: RoundingMode.halfUp,
    );

int _daysBetween(LocalDate from, LocalDate to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

/// DESIGN 7.2: the flow role of an upcoming item. Spending covers bills,
/// subscriptions and card charges; income and investing carry their own
/// glyphs.
ChartMark _markOf(String kind) => switch (kind) {
      'income' => ChartMark.moneyIn,
      'investment' => ChartMark.investing,
      _ => ChartMark.spending,
    };

LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
