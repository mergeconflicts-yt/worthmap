// P26 (SCREEN X32; flow F08 step 3; SPEC 4.4): the budget.
//
// One ring per category limit, most left first. The white tick is today's
// share of the month. Fixed bills draw a dashed ring; the fixed flag needs a
// category tag that Phase 2 does not store, so every ring is solid
// (P26-FIXED-RINGS).
library;

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/percent.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'spending_controller.dart';
import 'spending_models.dart';

/// X32: the month's budget rings.
class X32Budget extends StatefulWidget {
  const X32Budget({
    required this.gateway,
    required this.onClose,
    this.onEditLimits,
    this.controller,
    super.key,
  });

  final SpendingGateway gateway;
  final VoidCallback onClose;
  final VoidCallback? onEditLimits;
  final SpendingController? controller;

  @override
  State<X32Budget> createState() => _X32BudgetState();
}

class _X32BudgetState extends State<X32Budget> {
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
        return DetailScreen(
          header: ScreenHeader(
            title: l.spendingBudgetTitle,
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
              if (!_hasRings(view))
                GlassCard(
                  child: Text(
                    l.spendingNoLimits,
                    style: AppText.caption.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                )
              else
                _rings(l, view),
              if (widget.onEditLimits != null)
                AppButton(
                  label: l.spendingEditLimitsRow,
                  variant: AppButtonVariant.ghost,
                  onPressed: widget.onEditLimits,
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _hero(AppLocalizations l, SpendingView view) {
    final currency = Currency.of(view.currencyCode);
    final month = formatMonthLong(view.rangeStart);
    final left = view.leftMinor;
    final limit = view.limitMinor;
    final spent = view.moneyOutMinor;
    final line = limit == null || spent == null
        ? l.spendingBudgetNoLimit
        : l.spendingBudgetLine(
            formatMoney(Money.fromMinor(spent, currency)),
            formatMoney(Money.fromMinor(limit, currency)),
            view.monthDay,
            view.monthDays,
          );
    return ObHero(
      kicker: l.spendingBudgetKicker(month),
      value: left == null
          ? ValueSpec.missing(l.spendingNoLimit)
          : ValueSpec.real(Money.fromMinor(left, currency)),
      contextLine: line,
    );
  }

  bool _hasRings(SpendingView view) => view.categories.any(
        (row) => _controller.limitFor(row.id) > 0,
      );

  Widget _rings(AppLocalizations l, SpendingView view) {
    final currency = Currency.of(view.currencyCode);
    final entries = <({SpendingCategoryView row, int limit, int left})>[];
    for (final row in view.categories) {
      final limit = _controller.limitFor(row.id);
      if (limit <= 0) {
        continue;
      }
      entries.add((row: row, limit: limit, left: limit - row.amountMinor));
    }
    entries.sort((a, b) => b.left.compareTo(a.left));
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final percent = view.monthGone;
    return GlassCard(
      title: l.spendingLimitsTitle,
      meta: l.spendingLimitsMeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          RingMeterGrid(
            title: l.spendingLimitsTitle,
            period: formatDateRange(view.rangeStart, view.rangeEnd),
            meters: <RingMeter>[
              for (final entry in entries)
                RingMeter(
                  name: entry.row.name.isEmpty
                      ? l.spendingUncategorised
                      : entry.row.name,
                  value: Money.fromMinor(entry.row.amountMinor, currency),
                  limit: Money.fromMinor(entry.limit, currency),
                  todayShare: percent == null ? null : _fraction(percent),
                  leftLabel: l.spendingLeftLabel,
                  paidLabel: l.spendingPaid,
                ),
            ],
            columns: <String>[
              l.spendingLimitsTitle,
              l.spendingSpentKicker,
              l.spendingLimitLabel,
              l.spendingLeftLabel,
            ],
            paidLabel: l.spendingPaid,
            leftLabel: l.spendingLeftLabel,
            emptyLabel: l.spendingNothingRecorded,
          ),
          if (percent != null) ...<Widget>[
            const VSpace(Space.m),
            Text(
              l.spendingLimitsCaption(
                formatPercent(percent, decimals: 0),
              ),
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static double _fraction(Percent percent) => percent.value.toDouble() / 100;
}
