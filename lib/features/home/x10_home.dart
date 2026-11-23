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
        title: l.x03Today,
        dateLine: l.x03DateLine(
          formatDate(today, DateStyle.long),
          summary?.currencyCode ?? 'USD',
        ),
        actions: <Widget>[
          AppIconButton(
            icon: AppIcons.inbox,
            semanticLabel: l.x10SpokenInbox(summary?.inboxCount ?? 0),
            onPressed: widget.onInbox,
          ),
          const HideAmountsButton(),
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
          _hero(l, summary),
          _netWorthLine(l, summary),
          _quickLook(l, summary),
          _upcoming(l, summary, today),
          _thisMonth(l, summary),
          AppButton(
            label: l.x10OpenSpending,
            variant: AppButtonVariant.ghost,
            onPressed: widget.onSpending,
          ),
          Text(
            l.homeFooter,
            textAlign: TextAlign.center,
            style:
                AppText.caption.copyWith(color: context.tokens.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _hero(AppLocalizations l, HomeSummary summary) {
    final currency = Currency.of(summary.currencyCode);
    final netWorth = summary.netWorthMinor;
    final change = summary.netWorthChangeMinor;
    final moneyIn = summary.moneyInMinor;
    final spent = summary.spentMinor;
    final context = moneyIn == null || spent == null
        ? null
        : l.x10MonthLine(
            formatMoney(Money.fromMinor(moneyIn, currency)),
            formatMoney(Money.fromMinor(spent, currency)),
          );
    return ObHero(
      kicker: l.x10Kicker,
      value: netWorth == null
          ? ValueSpec.missing(l.x10NoBalance)
          : ValueSpec.real(Money.fromMinor(netWorth, currency)),
      contextLine: context,
      hiddenContextLine: l.x10MonthLineHidden,
      sideFigures: change == null
          ? const <HeroSideFigure>[]
          : <HeroSideFigure>[
              HeroSideFigure(
                value: MoneyText(
                  ValueSpec.real(Money.fromMinor(change, currency)),
                  sign: SignStyle.always,
                ),
                period: l.homeTwelveMonths,
              ),
            ],
    );
  }

  Widget _netWorthLine(AppLocalizations l, HomeSummary summary) {
    final currency = Currency.of(summary.currencyCode);
    return AreaLineChart(
      title: l.homeNetWorthChart,
      points: <LinePoint>[
        for (final point in summary.netWorthSeries)
          LinePoint(
            label: formatMonthShort(point.month),
            amount: point.amountMinor == null
                ? null
                : Money.fromMinor(point.amountMinor!, currency),
          ),
      ],
    );
  }

  Widget _quickLook(AppLocalizations l, HomeSummary summary) {
    final currency = Currency.of(summary.currencyCode);
    final hidden = HiddenAmountsScope.resolve(context, null);
    Widget amount(int? minor, {String? prefix}) => minor == null
        ? Text('—', style: AppText.body)
        : MoneyText(
            ValueSpec.real(Money.fromMinor(minor, currency)),
            prefix: prefix,
            style: AppText.bodyStrong,
          );
    String spoken(String label, int? minor) {
      if (hidden) return label;
      if (minor == null) return '$label, —';
      return l.homeTileSpoken(
        label,
        formatMoney(Money.fromMinor(minor, currency)),
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
            value: amount(summary.cardOwedMinor, prefix: l.x10Owes),
          ),
          HomeTile(
            icon: AppIcons.chart,
            label: l.x10Investments,
            value: amount(summary.investmentsMinor),
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
        emptyLabel: l.homeTimelineEmpty,
        items: <TimelineItem>[
          for (final item in summary.upcoming)
            TimelineItem(
              dayIndex: _daysBetween(today, item.date),
              dateLabel: formatDate(item.date, DateStyle.short),
              name: item.name,
              amount: item.amountMinor == null
                  ? null
                  : Money.fromMinor(
                      item.amountMinor!,
                      Currency.of(item.currencyCode),
                    ),
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
    return GlassCard(
      title: l.x10ThisMonth,
      meta: l.x10DayOf(summary.monthDay, summary.monthDays),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HomeTileGrid(
            spokenLabels: <String>[
              l.x10MoneyIn,
              used == null
                  ? l.x10Spent
                  : l.homeTileSpoken(
                      l.x10Spent,
                      formatPercent(used, decimals: 0),
                    ),
            ],
            tiles: <HomeTile>[
              HomeTile(
                icon: AppIcons.bank,
                label: l.x10MoneyIn,
                value: summary.moneyInMinor == null
                    ? const Text('—')
                    : MoneyText(
                        ValueSpec.real(
                          Money.fromMinor(summary.moneyInMinor!, currency),
                        ),
                        style: AppText.bodyStrong,
                      ),
              ),
              HomeTile(
                icon: AppIcons.receipt,
                label: l.x10Spent,
                value: spent == null
                    ? const Text('—')
                    : MoneyText(
                        ValueSpec.real(Money.fromMinor(spent, currency)),
                        style: AppText.bodyStrong,
                      ),
                line: used == null || limit == null
                    ? l.x10NoLimit
                    : l.x10OfLimit(formatPercent(used, decimals: 0)),
              ),
            ],
          ),
          if (spent != null && limit != null && limit > 0) ...<Widget>[
            const VSpace(Space.s),
            CapsuleMeter(
              value: spent,
              limit: limit,
              spokenLabel: used == null
                  ? l.x10NoLimit
                  : l.x10OfLimit(formatPercent(used, decimals: 0)),
            ),
          ],
          if (split != null) ...<Widget>[
            const VSpace(Space.l),
            SplitStrip(
              title: l.homeIncomeSplit,
              period: formatMonthShort(summary.month),
              parts: <SplitStripPart>[
                SplitStripPart(
                  name: l.homeSplitInvested,
                  amount: Money.fromMinor(
                    split.investedMinor,
                    Currency.of(split.currencyCode),
                  ),
                  mark: ChartMark.invested,
                ),
                SplitStripPart(
                  name: l.homeSplitInCash,
                  amount: Money.fromMinor(
                    split.inCashMinor,
                    Currency.of(split.currencyCode),
                  ),
                  mark: ChartMark.inCash,
                ),
              ],
              columns: <String>[
                l.homeSplitInvested,
                l.homeSplitInCash,
                l.homeSplitShare,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

int _daysBetween(LocalDate from, LocalDate to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
