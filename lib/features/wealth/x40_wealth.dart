// X40 (SCREENS; SPEC 6.5, 13.12): Wealth, tab root.
//
// The hero carries the net worth, the change for the selected period and the
// target line. The chart shows net worth, investments and cash on one scale.
// The card splits what you own from what you owe. Missing is never zero.
library;

import 'package:flutter/widgets.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'wealth_models.dart';

/// X40: net worth, its change and the three series.
class X40Wealth extends StatefulWidget {
  const X40Wealth({
    required this.gateway,
    this.onSettings,
    super.key,
  });

  final WealthGateway gateway;

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
    return TabRootScreen(
      header: ScreenHeader(
        kicker: l.wealthKicker,
        actions: <Widget>[
          const HideAmountsButton(),
          if (widget.onSettings != null)
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
        ] else if (_view != null)
          ..._body(l, _view!),
      ],
    );
  }

  List<Widget> _body(AppLocalizations l, WealthView view) {
    final currency = Currency.of(view.currencyCode);
    final hidden = HiddenAmountsScope.resolve(context, null);
    final netWorth = view.netWorthMinor;
    final change = view.changeMinor;
    final share = view.changeShare;
    final target = view.target;

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
                sign: change > 0 ? SignStyle.always : SignStyle.negativeOnly,
                trimZeroFraction: true,
              );
    final shareText = share == null
        ? null
        : change != null && change > 0
            ? '+${formatPercent(share)}'
            : formatPercent(share);
    final sideFigure = HeroSideFigure(
      value: _sideText(
        l,
        changeText,
        shareText,
        gain: !hidden && change != null && change > 0,
        loss: !hidden && change != null && change < 0,
      ),
      period: _periodLabel(l, view.period),
    );

    return <Widget>[
      ObHero(
        variant: ObHeroVariant.period,
        kicker: l.wealthHeroKicker,
        value: netWorth == null
            ? ValueSpec.noneRecorded(l.wealthNoBalance)
            : ValueSpec.real(
                wholeMoney(Money.fromMinor(netWorth, currency)),
              ),
        sideFigures: <HeroSideFigure>[sideFigure],
      ),
      const VSpace(Space.m),
      ChipRow(
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
      ),
      if (target != null &&
          target.share != null &&
          netWorth != null) ...<Widget>[
        const VSpace(Space.s),
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
      const VSpace(Space.card),
      _chartCard(l, view, currency, hidden),
      const VSpace(Space.card),
      _ownOweCard(l, view, currency, hidden),
    ];
  }

  Widget _sideText(
    AppLocalizations l,
    String amount,
    String? percent, {
    required bool gain,
    required bool loss,
  }) {
    final tokens = context.tokens;
    final colour = gain
        ? tokens.stateGain
        : loss
            ? tokens.stateLoss
            : tokens.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          amount,
          style: AppText.numberS.copyWith(color: colour),
          textAlign: TextAlign.end,
        ),
        if (percent != null)
          Text(
            percent,
            style: AppText.caption.copyWith(color: colour),
            textAlign: TextAlign.end,
          ),
      ],
    );
  }

  Widget _chartCard(
    AppLocalizations l,
    WealthView view,
    Currency currency,
    bool hidden,
  ) {
    final points = view.points;
    final first = points.isEmpty ? null : points.first.date;
    final last = points.isEmpty ? null : points.last.date;
    final rows = <List<String>>[
      for (final point in points)
        <String>[
          formatDate(point.date, DateStyle.short),
          _chartAmount(l, point.netWorthMinor, currency, hidden),
          _chartAmount(l, point.investmentsMinor, currency, hidden),
          _chartAmount(l, point.cashMinor, currency, hidden),
        ],
    ];
    final lastPoint = points.isEmpty ? null : points.last;
    final label = first == null || last == null
        ? l.chartNoneRecorded
        : l.wealthChartSpoken(
            formatDate(first, DateStyle.short),
            formatDate(last, DateStyle.short),
            _chartAmount(l, lastPoint?.netWorthMinor, currency, hidden),
            _chartAmount(l, lastPoint?.investmentsMinor, currency, hidden),
            _chartAmount(l, lastPoint?.cashMinor, currency, hidden),
          );

    List<LinePoint> line(int? Function(WealthPoint) value) => <LinePoint>[
          for (final point in points)
            LinePoint(
              label: formatDate(point.date, DateStyle.short),
              amount: value(point) == null
                  ? null
                  : wholeMoney(Money.fromMinor(value(point)!, currency)),
            ),
        ];

    return GlassCard(
      title: l.wealthChartTitle,
      child: MultiLineChart(
        label: label,
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
      ),
    );
  }

  Widget _ownOweCard(
    AppLocalizations l,
    WealthView view,
    Currency currency,
    bool hidden,
  ) {
    return GlassCard(
      title: l.wealthOwnOweTitle,
      meta: l.wealthAccountsCount(view.accountCount),
      child: Column(
        children: <Widget>[
          _row(
            l,
            l.wealthOwn,
            null,
            view.ownMinor,
            currency,
            hidden,
            strong: true,
          ),
          for (final type in view.ownTypes)
            _row(
              l,
              _typeName(l, type.kind),
              l.wealthAccountsCount(type.count),
              type.amountMinor,
              currency,
              hidden,
            ),
          const VSpace(Space.s),
          _row(
            l,
            l.wealthOwe,
            null,
            view.oweMinor,
            currency,
            hidden,
            strong: true,
          ),
          for (final type in view.oweTypes)
            _row(
              l,
              _typeName(l, type.kind),
              l.wealthAccountsCount(type.count),
              type.amountMinor,
              currency,
              hidden,
            ),
        ],
      ),
    );
  }

  Widget _row(
    AppLocalizations l,
    String name,
    String? fact,
    int? minor,
    Currency currency,
    bool hidden, {
    bool strong = false,
  }) {
    final tokens = context.tokens;
    final value = minor == null
        ? Text(
            l.wealthMissing,
            style: (strong ? AppText.bodyStrong : AppText.bodyS).copyWith(
              color: tokens.textSecondary,
            ),
          )
        : MoneyText(
            ValueSpec.real(
              wholeMoney(Money.fromMinor(minor, currency)),
            ),
            trimZeroFraction: true,
            style: (strong ? AppText.bodyStrong : AppText.bodyS).copyWith(
              color: tokens.textPrimary,
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: (strong ? AppText.bodyStrong : AppText.body).copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
                if (fact != null)
                  Text(
                    fact,
                    style: AppText.caption.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const HSpace(Space.s),
          value,
        ],
      ),
    );
  }

  String _chartAmount(
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
        WealthPeriod.oneMonth => l.wealthPeriodOneMonth,
        WealthPeriod.oneYear => l.wealthPeriodOneYear,
        WealthPeriod.fiveYears => l.wealthPeriodFiveYears,
      };

  String _chipSpoken(AppLocalizations l, WealthPeriod period) =>
      switch (period) {
        WealthPeriod.oneMonth => l.wealthPeriodSpokenOneMonth,
        WealthPeriod.oneYear => l.wealthPeriodSpokenOneYear,
        WealthPeriod.fiveYears => l.wealthPeriodSpokenFiveYears,
      };

  String _periodLabel(AppLocalizations l, WealthPeriod period) =>
      _chipSpoken(l, period);

  String _typeName(AppLocalizations l, WealthTypeKind kind) => switch (kind) {
        WealthTypeKind.cash => l.wealthTypeCash,
        WealthTypeKind.investments => l.wealthTypeInvestments,
        WealthTypeKind.card => l.wealthTypeCard,
      };
}
