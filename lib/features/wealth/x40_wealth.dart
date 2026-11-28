// X40 (SCREENS; SPEC 6.5, 13.12): Wealth, tab root.
//
// The top line is the NET WORTH kicker with the Home controls. The number
// carries the change and the target. The chart shows net worth, investments
// and cash on one scale, then the period chips. The card splits what you own
// from what you owe, with a tile per type. Missing is never zero.
library;

import 'package:flutter/widgets.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'wealth_models.dart';

/// X40: net worth, the three series and the own/owe split.
class X40Wealth extends StatefulWidget {
  const X40Wealth({
    required this.gateway,
    this.onInbox,
    this.onSettings,
    super.key,
  });

  final WealthGateway gateway;

  /// Opens X60. Null keeps no Inbox control.
  final VoidCallback? onInbox;

  /// Opens X80. Null keeps no Settings control.
  final VoidCallback? onSettings;

  @override
  State<X40Wealth> createState() => _X40WealthState();
}

class _X40WealthState extends State<X40Wealth> {
  WealthPeriod _period = WealthPeriod.oneYear;
  WealthView? _view;
  bool _loading = true;
  bool _failed = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final view = await widget.gateway.load(_period);
      if (!mounted) {
        return;
      }
      setState(() {
        _view = view;
        _loading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _select(WealthPeriod period) {
    if (period == _period) {
      return;
    }
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final view = _view;
    return TabRootScreen(
      header: ScreenHeader(
        kicker: l.wealthHeroKicker,
        actions: <Widget>[
          const HideAmountsButton(),
          AppIconButton(
            icon: AppIcons.inbox,
            badgeCount: view?.inboxCount ?? 0,
            semanticLabel: l.x10SpokenInbox(view?.inboxCount ?? 0),
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
        if (_loading)
          Text(l.spendingLoading, style: AppText.caption)
        else if (_failed) ...<Widget>[
          Text(l.wealthLoadFailed, style: AppText.bodyStrong),
          AppButton(
            label: l.wealthRetry,
            variant: AppButtonVariant.soft,
            onPressed: _load,
          ),
        ] else if (view != null)
          ..._body(l, view),
      ],
    );
  }

  List<Widget> _body(AppLocalizations l, WealthView view) {
    final currency = Currency.of(view.currencyCode);
    final target = view.target;
    return <Widget>[
      _top(l, view, currency),
      if (target != null && target.share != null) ...<Widget>[
        const VSpace(Space.xs),
        TargetProgressLine(
          share: target.share!,
          label: l.netWorthTargetLine(
            formatPercent(target.share!),
            formatMoney(
              wholeMoney(Money.fromMinor(target.amountMinor, currency)),
              trimZeroFraction: true,
            ),
            formatMonthYear(target.date),
          ),
        ),
      ],
      const VSpace(Space.m),
      _chart(l, view, currency),
      const VSpace(Space.m),
      _chips(l, view),
      const VSpace(Space.card),
      _ownOwe(l, view, currency),
      if (_notInNetWorth(l, view, currency) != null) ...<Widget>[
        const VSpace(Space.card),
        _notInNetWorth(l, view, currency)!,
      ],
    ];
  }

  /// Line 2: the number with the change and its share at the right, as X10.
  Widget _top(AppLocalizations l, WealthView view, Currency currency) {
    final tokens = context.tokens;
    final hidden = HiddenAmountsScope.resolve(context, null);
    final largeText = MediaQuery.textScalerOf(context).scale(13) >= 13 * 1.3;
    final netWorth = view.netWorthMinor;
    final change = view.changeMinor;
    final share = view.changeShare;
    final hero = ObHero(
      value: netWorth == null
          ? ValueSpec.missing(l.wealthNoBalance)
          : ValueSpec.real(
              wholeMoney(Money.fromMinor(netWorth, currency)),
            ),
      minFontSize: 28,
    );
    final colour = change == null
        ? tokens.textSecondary
        : change < 0
            ? tokens.stateLoss
            : tokens.stateGain;
    final changeText = change == null
        ? l.wealthMissing
        : hidden
            ? formatValueState(
                ValueSpec.real(
                  wholeMoney(Money.fromMinor(change, currency)),
                ),
                hidden: true,
              ).text
            : formatMoney(
                wholeMoney(Money.fromMinor(change, currency)),
                sign: SignStyle.always,
                trimZeroFraction: true,
              );
    final side = Column(
      crossAxisAlignment:
          largeText ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          changeText,
          style: AppText.bodyStrong.copyWith(color: colour),
        ),
        if (share != null)
          Text(
            change != null && change > 0
                ? '+${formatPercent(share)}'
                : formatPercent(share),
            style: AppText.caption.copyWith(color: colour),
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

  Widget _chart(AppLocalizations l, WealthView view, Currency currency) {
    final hidden = HiddenAmountsScope.resolve(context, null);
    final points = view.points;
    final monthly = view.period != WealthPeriod.oneDay &&
        view.period != WealthPeriod.oneWeek &&
        view.period != WealthPeriod.oneMonth;
    final lastPoint = points.isEmpty ? null : points.last;
    final rows = <List<String>>[
      for (final point in points)
        <String>[
          formatDate(point.date, DateStyle.short),
          _amount(l, point.netWorthMinor, currency, hidden),
          _amount(l, point.investmentsMinor, currency, hidden),
          _amount(l, point.cashMinor, currency, hidden),
        ],
    ];
    final label = points.isEmpty
        ? l.chartNoneRecorded
        : l.wealthChartSpoken(
            formatDate(points.first.date, DateStyle.short),
            formatDate(points.last.date, DateStyle.short),
            _amount(l, lastPoint?.netWorthMinor, currency, hidden),
            _amount(l, lastPoint?.investmentsMinor, currency, hidden),
            _amount(l, lastPoint?.cashMinor, currency, hidden),
          );

    List<LinePoint> line(int? Function(WealthPoint) value) => <LinePoint>[
          for (final point in points)
            LinePoint(
              label: _axisLabel(l, point.date, view, monthly),
              amount: value(point) == null
                  ? null
                  : wholeMoney(Money.fromMinor(value(point)!, currency)),
            ),
        ];

    return MultiLineChart(
      label: label,
      currencyCode: view.currencyCode,
      series: <MultiLineSeries>[
        MultiLineSeries(
          name: l.wealthSeriesNetWorth,
          mark: ChartMark.gain,
          points: line((WealthPoint point) => point.netWorthMinor),
        ),
        MultiLineSeries(
          name: l.wealthSeriesInvestments,
          mark: ChartMark.invested,
          points: line((WealthPoint point) => point.investmentsMinor),
        ),
        MultiLineSeries(
          name: l.wealthSeriesCash,
          mark: ChartMark.inCash,
          points: line((WealthPoint point) => point.cashMinor),
        ),
      ],
      table: ChartTable(
        columns: <String>[
          l.wealthTableDate,
          l.wealthSeriesNetWorth,
          l.wealthSeriesInvestments,
          l.wealthSeriesCash,
        ],
        rows: rows,
        emptyLabel: l.chartNoneRecorded,
      ),
      emptyLabel: l.chartNoneRecorded,
    );
  }

  String _axisLabel(
    AppLocalizations l,
    LocalDate date,
    WealthView view,
    bool monthly,
  ) {
    if (date == view.today) {
      return l.wealthToday;
    }
    if (monthly) {
      final month = formatMonthShort(date);
      final year = '${date.year}'.substring(2);
      return '$month $year';
    }
    return formatDate(date, DateStyle.short);
  }

  Widget _chips(AppLocalizations l, WealthView view) {
    return ChipRow(
      items: <ChipItem>[
        for (final period in WealthPeriod.values)
          ChipItem(
            label: _chipLabel(l, period),
            semanticLabel: _chipSpoken(l, period),
            variant: ChipVariant.choice,
            selected: period == view.period,
            onPressed: () => _select(period),
          ),
      ],
    );
  }

  Widget _ownOwe(AppLocalizations l, WealthView view, Currency currency) {
    final hidden = HiddenAmountsScope.resolve(context, null);
    final own = view.ownMinor;
    final owe = view.oweMinor;
    final ownText = _total(l, own, currency, hidden);
    final oweText = _total(l, owe, currency, hidden);
    final tabs = <AmountTab>[
      AmountTab(
        label: l.wealthOwn,
        value: ownText,
        mark: ChartMark.gain,
      ),
      AmountTab(
        label: l.wealthOwe,
        value: oweText,
        mark: ChartMark.invested,
      ),
    ];
    final ownParts = <SplitLinePart>[
      for (final type in view.ownTypes)
        if (type.amountMinor != null)
          SplitLinePart(
            name: _typeName(l, type.kind),
            amount: Money.fromMinor(type.amountMinor!, currency),
            mark: _typeMark(type.kind),
          ),
    ];
    final oweParts = <SplitLinePart>[
      for (final type in view.oweTypes)
        if (type.amountMinor != null)
          SplitLinePart(
            name: _typeName(l, type.kind),
            amount: Money.fromMinor(type.amountMinor!, currency),
            mark: _typeMark(type.kind),
          ),
    ];
    final tiles =
        _tab == 0 ? _ownTiles(l, view, currency) : _oweTiles(l, view, currency);
    return GlassCard(
      variant: GlassCardVariant.stage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AmountTabs(
            tabs: tabs,
            selectedIndex: _tab,
            onChanged: (int index) => setState(() => _tab = index),
            semanticLabel: l.wealthOwnOweTitle,
          ),
          const VSpace(Space.s),
          SplitLine(
            parts: <SplitLinePart>[...ownParts, ...oweParts],
            label: l.wealthOwnOweSpoken(ownText, oweText),
          ),
          const VSpace(Space.m),
          TypeTileGrid(tiles: tiles),
        ],
      ),
    );
  }

  List<TypeTile> _ownTiles(
    AppLocalizations l,
    WealthView view,
    Currency currency,
  ) {
    const order = <WealthTypeKind>[
      WealthTypeKind.investments,
      WealthTypeKind.retirement,
      WealthTypeKind.cash,
      WealthTypeKind.car,
      WealthTypeKind.deposits,
      WealthTypeKind.property,
      WealthTypeKind.gold,
      WealthTypeKind.bonds,
      WealthTypeKind.other,
    ];
    return <TypeTile>[
      for (final kind in order) _tile(l, view, currency, kind),
    ];
  }

  List<TypeTile> _oweTiles(
    AppLocalizations l,
    WealthView view,
    Currency currency,
  ) {
    const order = <WealthTypeKind>[
      WealthTypeKind.card,
      WealthTypeKind.car,
      WealthTypeKind.other,
    ];
    return <TypeTile>[
      for (final kind in order) _tile(l, view, currency, kind, owed: true),
    ];
  }

  TypeTile _tile(
    AppLocalizations l,
    WealthView view,
    Currency currency,
    WealthTypeKind kind, {
    bool owed = false,
  }) {
    WealthType? found;
    for (final type in <WealthType>[...view.ownTypes, ...view.oweTypes]) {
      if (type.kind == kind) {
        found = type;
        break;
      }
    }
    final value = found?.amountMinor;
    return TypeTile(
      name: _typeName(l, kind, owed: owed),
      icon: _typeIcon(kind),
      mark: _typeMark(kind),
      value: value == null
          ? null
          : ValueSpec.real(
              wholeMoney(Money.fromMinor(value, currency)),
            ),
      fact: found == null ? null : l.wealthAccountsCount(found.count),
      empty: found == null,
      emptyLabel: l.wealthTypeNone,
    );
  }

  Widget? _notInNetWorth(
    AppLocalizations l,
    WealthView view,
    Currency currency,
  ) {
    final rows = <(String, int?, String?)>[
      (l.wealthUnvestedShares, view.unvestedMinor, null),
      (l.wealthOwedToYou, view.owedToYouMinor, null),
      (l.wealthDividends, view.dividendsMinor, l.wealthEstimated),
    ];
    final shown = rows.where((row) => row.$2 != null).toList();
    if (shown.isEmpty) {
      return null;
    }
    return GlassCard(
      title: l.wealthNotInNetWorth,
      meta: l.wealthExpected,
      variant: GlassCardVariant.list,
      child: Column(
        children: <Widget>[
          for (final row in shown)
            SelectRow(
              name: row.$1,
              line: row.$3,
              chevron: false,
              trailing: MoneyText(
                ValueSpec.real(
                  wholeMoney(Money.fromMinor(row.$2!, currency)),
                ),
                trimZeroFraction: true,
                style: AppText.numberXS,
              ),
            ),
        ],
      ),
    );
  }

  String _total(
    AppLocalizations l,
    int? minor,
    Currency currency,
    bool hidden,
  ) =>
      minor == null
          ? l.wealthMissing
          : hidden
              ? formatValueState(
                  ValueSpec.real(wholeMoney(Money.fromMinor(minor, currency))),
                  hidden: true,
                ).text
              : formatMoney(
                  wholeMoney(Money.fromMinor(minor, currency)),
                  trimZeroFraction: true,
                );

  String _amount(
    AppLocalizations l,
    int? minor,
    Currency currency,
    bool hidden,
  ) =>
      minor == null
          ? l.wealthMissing
          : chartAmountText(
              wholeMoney(Money.fromMinor(minor, currency)),
              hidden: hidden,
            );

  String _chipLabel(AppLocalizations l, WealthPeriod period) =>
      switch (period) {
        WealthPeriod.oneDay => l.wealthPeriodOneDay,
        WealthPeriod.oneWeek => l.wealthPeriodOneWeek,
        WealthPeriod.oneMonth => l.wealthPeriodOneMonth,
        WealthPeriod.oneYear => l.wealthPeriodOneYear,
        WealthPeriod.fiveYears => l.wealthPeriodFiveYears,
        WealthPeriod.max => l.wealthPeriodMax,
      };

  String _chipSpoken(AppLocalizations l, WealthPeriod period) =>
      switch (period) {
        WealthPeriod.oneDay => l.wealthPeriodSpokenOneDay,
        WealthPeriod.oneWeek => l.wealthPeriodSpokenOneWeek,
        WealthPeriod.oneMonth => l.wealthPeriodSpokenOneMonth,
        WealthPeriod.oneYear => l.wealthPeriodSpokenOneYear,
        WealthPeriod.fiveYears => l.wealthPeriodSpokenFiveYears,
        WealthPeriod.max => l.wealthPeriodSpokenMax,
      };

  String _typeName(
    AppLocalizations l,
    WealthTypeKind kind, {
    bool owed = false,
  }) =>
      switch (kind) {
        WealthTypeKind.cash => l.wealthTypeCash,
        WealthTypeKind.investments => l.wealthTypeInvestments,
        WealthTypeKind.retirement => l.wealthTypeRetirement,
        WealthTypeKind.car => l.wealthTypeCar,
        WealthTypeKind.deposits => l.wealthTypeDeposits,
        WealthTypeKind.property => l.wealthTypeProperty,
        WealthTypeKind.gold => l.wealthTypeGold,
        WealthTypeKind.bonds => l.wealthTypeBonds,
        WealthTypeKind.other =>
          owed ? l.wealthTypeOtherOwed : l.wealthTypeOther,
        WealthTypeKind.card => l.wealthTypeCard,
      };

  AppIconData _typeIcon(WealthTypeKind kind) => switch (kind) {
        WealthTypeKind.cash => AppIcons.bank,
        WealthTypeKind.investments => AppIcons.chart,
        WealthTypeKind.retirement => AppIcons.shield,
        WealthTypeKind.car => AppIcons.car,
        WealthTypeKind.deposits => AppIcons.safe,
        WealthTypeKind.property => AppIcons.house,
        WealthTypeKind.gold => AppIcons.viewBubbles,
        WealthTypeKind.bonds => AppIcons.file,
        WealthTypeKind.other => AppIcons.more,
        WealthTypeKind.card => AppIcons.card,
      };

  ChartMark _typeMark(WealthTypeKind kind) => switch (kind) {
        WealthTypeKind.cash => ChartMark.inCash,
        WealthTypeKind.investments => ChartMark.gain,
        WealthTypeKind.retirement => ChartMark.invested,
        WealthTypeKind.car => ChartMark.transport,
        WealthTypeKind.deposits => ChartMark.needs,
        WealthTypeKind.property => ChartMark.subscriptions,
        WealthTypeKind.gold => ChartMark.other,
        WealthTypeKind.bonds => ChartMark.dining,
        WealthTypeKind.other => ChartMark.other,
        WealthTypeKind.card => ChartMark.spending,
      };
}
