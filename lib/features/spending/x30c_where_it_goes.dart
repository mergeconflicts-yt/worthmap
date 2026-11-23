// P26 (SCREEN X30c; flow F08 step 2; SPEC 4.4): where the money goes.
//
// The screen shows the category shares of the selected month on one scale. The
// second denominator is money in. Transfers and card repayments never enter
// the numerator or the denominator (SPEC 4.2).
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/percent.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'spending_controller.dart';
import 'spending_models.dart';

/// X30c: the category breakdown, as a share of spending or of money in.
class X30cWhereItGoes extends StatefulWidget {
  const X30cWhereItGoes({
    required this.gateway,
    required this.onClose,
    this.onCategory,
    this.period = SpendingPeriod.month,
    this.controller,
    super.key,
  });

  final SpendingGateway gateway;
  final VoidCallback onClose;
  final ValueChanged<String>? onCategory;
  final SpendingPeriod period;
  final MoneyInController? controller;

  @override
  State<X30cWhereItGoes> createState() => _X30cWhereItGoesState();
}

class _X30cWhereItGoesState extends State<X30cWhereItGoes> {
  late final MoneyInController _controller = widget.controller ??
      MoneyInController(gateway: widget.gateway, period: widget.period);
  bool _ofMoneyIn = false;

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
        final spending = _controller.spending;
        final moneyIn = _controller.view;
        if (spending == null) {
          return DetailScreen(
            header: ScreenHeader(
              title: l.spendingWhereItGoesTitle,
              leading: _back(l),
            ),
            children: <Widget>[
              Text(
                _controller.state == SpendingLoadState.failed
                    ? l.spendingLoadFailed
                    : l.spendingLoading,
                style: AppText.bodyStrong,
              ),
            ],
          );
        }
        final currency = Currency.of(spending.currencyCode);
        final spent = Money.fromMinor(
          spending.moneyOutMinor ?? 0,
          currency,
        );
        final moneyInMinor = moneyIn?.amountMinor;
        final denominator = _ofMoneyIn ? moneyInMinor : spending.moneyOutMinor;
        final month = formatDateRange(spending.rangeStart, spending.rangeEnd);
        return DetailScreen(
          header: ScreenHeader(
            title: l.spendingWhereItGoesTitle,
            dateLine: month,
            leading: _back(l),
          ),
          children: <Widget>[
            ObHero(
              kicker: l.spendingWhereKicker(month),
              value: spending.moneyOutMinor == null
                  ? ValueSpec.noneRecorded(l.spendingNothingRecorded)
                  : ValueSpec.real(spent),
              contextLine: moneyInMinor == null
                  ? null
                  : l.spendingWhereLine(
                      formatMoney(
                        Money.fromMinor(moneyInMinor, currency),
                      ),
                      _share(spending.moneyOutMinor ?? 0, moneyInMinor),
                      _share(
                        moneyInMinor - (spending.moneyOutMinor ?? 0),
                        moneyInMinor,
                      ),
                    ),
              hiddenContextLine: null,
            ),
            SegmentedControl(
              segments: <String>[
                l.spendingPercentOfSpending,
                l.spendingPercentOfMoneyIn,
              ],
              selectedIndex: _ofMoneyIn ? 1 : 0,
              semanticLabel: l.spendingPercentOfSpending,
              onChanged: (index) {
                setState(() => _ofMoneyIn = index == 1);
              },
            ),
            GlassCard(
              title: l.spendingWhereItGoesTitle,
              meta: month,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final row in spending.categories) ...<Widget>[
                    SelectRow(
                      name:
                          row.name.isEmpty ? l.spendingUncategorised : row.name,
                      value: l.spendingShareValue(
                        denominator == null || denominator <= 0
                            ? '—'
                            : _share(row.amountMinor, denominator),
                        formatMoney(
                          Money.fromMinor(row.amountMinor, currency),
                        ),
                      ),
                      chevron: false,
                    ),
                    const VSpace(Space.xxs),
                  ],
                  if (spending.categories.isEmpty)
                    Text(
                      l.spendingNothingRecorded,
                      style: AppText.caption.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              l.spendingWhereCaption,
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _back(AppLocalizations l) => AppIconButton(
        icon: AppIcons.back,
        semanticLabel: l.spendingBack,
        onPressed: widget.onClose,
      );

  String _share(int part, int whole) {
    if (whole <= 0) {
      return '—';
    }
    final percent = Percent.fromFraction(
      (Decimal.fromInt(part) / Decimal.fromInt(whole))
          .toDecimal(scaleOnInfinitePrecision: 6),
    );
    return formatPercent(percent);
  }
}
