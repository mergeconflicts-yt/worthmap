// P28 (SCREEN X34; flow F09 step 2; SPEC 8.17): repeating payments.
//
// The list shows every live schedule with its next date and state. A row opens
// X35. There is no Add button here; adding uses the tab bar Add (SPEC 5.5),
// which is not mounted in this phase (P28-TABBAR-ADD).
library;

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'repeating_controller.dart';
import 'repeating_models.dart';

/// X34: hero, list of schedules.
class X34Repeating extends StatefulWidget {
  const X34Repeating({
    required this.gateway,
    required this.onClose,
    required this.onOpenSchedule,
    this.controller,
    super.key,
  });

  final RepeatingGateway gateway;
  final VoidCallback onClose;
  final ValueChanged<String> onOpenSchedule;
  final RepeatingController? controller;

  @override
  State<X34Repeating> createState() => _X34RepeatingState();
}

class _X34RepeatingState extends State<X34Repeating> {
  late final RepeatingController _controller =
      widget.controller ?? RepeatingController(gateway: widget.gateway);

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
        final currency = Currency.of(view?.currencyCode ?? 'USD');
        return DetailScreen(
          header: ScreenHeader(
            title: l.repeatingTitle,
            dateLine: l.rulesSubline == '' ? null : null,
            leading: AppIconButton(
              icon: AppIcons.back,
              semanticLabel: l.repeatingBack,
              onPressed: widget.onClose,
            ),
          ),
          children: <Widget>[
            if (_controller.state == RepeatingState.failed)
              Text(l.spendingLoadFailed, style: AppText.bodyStrong)
            else if (view == null)
              Text(l.spendingLoading, style: AppText.caption)
            else ...<Widget>[
              ObHero(
                kicker: l.repeatingKicker,
                value: ValueSpec.real(
                  Money.fromMinor(view.monthlyTotalMinor, currency),
                ),
                contextLine: l.repeatingLine(
                  formatMoney(
                    Money.fromMinor(view.monthlyTotalMinor, currency),
                  ),
                  formatMoney(
                    Money.fromMinor(view.yearlyTotalMinor, currency),
                  ),
                ),
              ),
              GlassCard(
                title: l.repeatingTitle,
                meta: '${view.items.length}',
                child: Column(
                  children: <Widget>[
                    if (view.items.isEmpty)
                      Text(
                        l.repeatingEmpty,
                        style: AppText.caption.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      )
                    else
                      for (final item in view.items) ...<Widget>[
                        _row(l, item),
                        const VSpace(Space.xxs),
                      ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _row(AppLocalizations l, RepeatingItem item) {
    final currency = Currency.of(item.currencyCode);
    final amount = item.amountMinor;
    final state = item.paidThisMonth ? l.repeatingPaid : l.repeatingExpected;
    final line = item.nextDate == null
        ? state
        : '${l.repeatingNext(formatDate(item.nextDate!, DateStyle.short))} · $state';
    return SelectRow(
      name: item.name,
      line: line,
      trailing: amount == null
          ? null
          : MoneyText(
              ValueSpec.real(Money.fromMinor(amount, currency)),
              style: AppText.numberXS,
            ),
      onTap: () => widget.onOpenSchedule(item.id),
      semanticLabel: '${item.name}, $line',
    );
  }
}
