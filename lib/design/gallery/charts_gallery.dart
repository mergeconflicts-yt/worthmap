import 'package:contour/core/money.dart';
import 'package:flutter/widgets.dart';

import '../charts/billing_strip.dart';
import '../charts/chart_frame.dart';
import '../charts/chart_tone.dart';
import '../charts/period_bar_chart.dart';
import '../charts/ring_meter.dart';
import '../charts/split_bar.dart';
import '../components/hero/ob_hero.dart';
import '../format/hidden_amounts.dart';
import '../format/money_format.dart';
import '../format/money_text.dart';
import '../format/value_presentation.dart';
import '../icons/app_icons.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../typography/app_text.dart';

/// P19/P20: the gallery entry for the Phase 2 charts, the period hero and the
/// hidden-amount state. Every chart variant, an empty data set and a hidden
/// state appear here (DESIGN 0.5, 7.1).
class ChartsGallery extends StatelessWidget {
  const ChartsGallery({super.key});

  static Money _usd(int major) => Money.fromMinor(major * 100, Currency.usd);

  static List<PeriodBar> _bars() => <PeriodBar>[
        for (var day = 1; day <= 13; day++)
          PeriodBar(
            label: day.toString(),
            amount: _usd(180 + day * 22),
            current: day == 13,
          ),
      ];

  static final List<RingMeter> _rings = <RingMeter>[
    RingMeter(
      name: 'Rent',
      value: _usd(1800),
      limit: _usd(1800),
      icon: AppIcons.house,
      fixed: true,
      paidLabel: 'Paid',
      leftLabel: 'left',
    ),
    RingMeter(
      name: 'Groceries',
      value: _usd(620),
      limit: _usd(1200),
      icon: AppIcons.chart,
      mark: ChartMark.groceries,
      todayShare: 0.42,
      paidLabel: 'Paid',
      leftLabel: 'left',
    ),
  ];

  static final List<SplitBarPart> _parts = <SplitBarPart>[
    SplitBarPart(
      name: 'Needs',
      amount: _usd(2890),
      mark: ChartMark.needs,
    ),
    SplitBarPart(
      name: 'Wants',
      amount: _usd(1050),
      mark: ChartMark.wants,
    ),
  ];

  static final List<BillingMark> _billing = <BillingMark>[
    BillingMark(day: 1, name: 'Rent', amount: _usd(1800), paid: true),
    BillingMark(day: 10, name: 'Spotify', amount: _usd(11), paid: true),
    BillingMark(day: 18, name: 'Netflix', amount: _usd(18)),
    BillingMark(day: 20, name: 'Phone', amount: _usd(45)),
  ];

  static Widget _periodBars({bool hidden = false, bool hero = false}) =>
      PeriodBarChart(
        title: 'Spent',
        period: '1–13 Oct 2026',
        average: _usd(303),
        limit: hero ? null : _usd(750),
        columns: const <String>['Date', 'Amount'],
        incompleteLabel: 'October is not closed yet',
        emptyLabel: 'None recorded',
        bars: <PeriodBar>[
          for (final bar in _bars())
            PeriodBar(
              label: bar.label,
              amount: bar.amount,
              current: bar.current,
              incomplete: bar.current,
            ),
        ],
        hidden: hidden,
        preview: hero,
        height: hero ? 136 : 160,
      );

  static Widget _emptyBars() => const PeriodBarChart(
        title: 'Spent',
        period: 'October',
        columns: <String>['Date', 'Amount'],
        emptyLabel: 'None recorded',
        bars: <PeriodBar>[],
      );

  static Widget _emptyRings() => const RingMeterGrid(
        title: 'Limits',
        period: 'October',
        columns: <String>['Category', 'Spent', 'Limit', 'Left'],
        emptyLabel: 'None recorded',
        meters: <RingMeter>[],
      );

  static Widget _emptySplit() => const SplitBar(
        title: 'Where it goes',
        period: 'October',
        columns: <String>['Part', 'Amount', 'Share'],
        emptyLabel: 'None recorded',
        parts: <SplitBarPart>[],
      );

  static Widget _emptyBilling() => const BillingStrip(
        title: 'Repeating',
        period: 'October',
        daysInMonth: 31,
        today: 13,
        paidLabel: 'Paid',
        dueLabel: 'Due',
        columns: <String>['Date', 'Payment', 'Amount', 'State'],
        emptyLabel: 'None recorded',
        marks: <BillingMark>[],
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.surfacePage,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Heading('PeriodBarChart · 1M'),
            _periodBars(),
            const VSpace(Space.xxl),
            const _Heading('PeriodBarChart · empty'),
            _emptyBars(),
            const VSpace(Space.xxl),
            const _Heading('RingMeterGrid'),
            RingMeterGrid(
              title: 'Limits',
              period: 'October',
              columns: const <String>['Category', 'Spent', 'Limit', 'Left'],
              paidLabel: 'Paid',
              leftLabel: 'left',
              meters: _rings,
            ),
            const VSpace(Space.xxl),
            const _Heading('RingMeterGrid · empty'),
            _emptyRings(),
            const VSpace(Space.xxl),
            const _Heading('SplitBar'),
            SplitBar(
              title: 'Needs and wants',
              period: 'October',
              columns: const <String>['Part', 'Amount', 'Share'],
              parts: _parts,
            ),
            const VSpace(Space.xxl),
            const _Heading('SplitBar · empty'),
            _emptySplit(),
            const VSpace(Space.xxl),
            const _Heading('BillingStrip'),
            BillingStrip(
              title: 'Repeating',
              period: 'October',
              daysInMonth: 31,
              today: 13,
              todayLabel: 'Today',
              paidLabel: 'Paid',
              dueLabel: 'Due',
              columns: const <String>['Date', 'Payment', 'Amount', 'State'],
              marks: _billing,
            ),
            const VSpace(Space.xxl),
            const _Heading('BillingStrip · empty'),
            _emptyBilling(),
            const VSpace(Space.xxl),
            const _Heading('0bHero · period'),
            ObHero(
              kicker: 'SPENT',
              value: ValueSpec.real(_usd(3940)),
              variant: ObHeroVariant.period,
              contextLine: '1–13 Oct 2026 · \$1,260 left of \$5,200',
              hiddenContextLine:
                  '1–13 Oct 2026 · \$$hiddenMask left of \$$hiddenMask',
              backgroundChart: _periodBars(hero: true),
            ),
            const VSpace(Space.xxl),
            const _Heading('Hidden amounts'),
            HiddenAmountsScope(
              hidden: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _periodBars(hidden: true),
                  const VSpace(Space.xxl),
                  RingMeterGrid(
                    title: 'Limits',
                    period: 'October',
                    columns: const <String>[
                      'Category',
                      'Spent',
                      'Limit',
                      'Left',
                    ],
                    paidLabel: 'Paid',
                    leftLabel: 'left',
                    hidden: true,
                    meters: _rings,
                  ),
                  const VSpace(Space.xxl),
                  SplitBar(
                    title: 'Needs and wants',
                    period: 'October',
                    columns: const <String>['Part', 'Amount', 'Share'],
                    hidden: true,
                    parts: _parts,
                  ),
                  const VSpace(Space.xxl),
                  BillingStrip(
                    title: 'Repeating',
                    period: 'October',
                    daysInMonth: 31,
                    today: 13,
                    todayLabel: 'Today',
                    paidLabel: 'Paid',
                    dueLabel: 'Due',
                    hidden: true,
                    columns: const <String>[
                      'Date',
                      'Payment',
                      'Amount',
                      'State',
                    ],
                    marks: _billing,
                  ),
                  const VSpace(Space.xxl),
                  ObHero(
                    kicker: 'SPENT',
                    value: ValueSpec.real(_usd(3940)),
                    variant: ObHeroVariant.period,
                    contextLine: '1–13 Oct 2026 · \$1,260 left of \$5,200',
                    hiddenContextLine:
                        '1–13 Oct 2026 · \$$hiddenMask left of \$$hiddenMask',
                    backgroundChart: _periodBars(hidden: true, hero: true),
                  ),
                  const VSpace(Space.xxl),
                  MoneyText(
                    ValueSpec.real(_usd(3940)),
                    style: AppText.numberM.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const VSpace(Space.xxl),
            const _Heading('ChartFrame · disclosure open'),
            const ChartFrame(
              label: 'Spent, October: \$3,940',
              showTable: true,
              initiallyOpen: true,
              chart: SizedBox(height: 64),
              table: ChartTable(
                columns: <String>['Date', 'Amount'],
                rows: <List<String>>[
                  <String>['1 Oct', r'$180'],
                  <String>['2 Oct', r'$202'],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.m),
        child: Text(
          text,
          style:
              AppText.titleSection.copyWith(color: context.tokens.textPrimary),
        ),
      );
}
