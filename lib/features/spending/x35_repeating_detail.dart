// P28 (SCREEN X35; flow F09 steps 2–3; SPEC 8.17): one repeating payment.
//
// The hero shows the next amount and the year cost, the history shows the last
// six occurrences, and Stop ends generation while confirmed history stays
// (F09-C). The cancellation address and the automatic Inbox toggle are not in
// this phase (P28-CANCEL-ADDRESS, P28-AUTOCREATE).
library;

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'repeating_controller.dart';
import 'repeating_models.dart';

/// X35: hero, history, facts and Stop.
class X35RepeatingDetail extends StatefulWidget {
  const X35RepeatingDetail({
    required this.gateway,
    required this.scheduleId,
    required this.onClose,
    this.controller,
    super.key,
  });

  final RepeatingGateway gateway;
  final String scheduleId;
  final VoidCallback onClose;
  final RepeatingDetailController? controller;

  @override
  State<X35RepeatingDetail> createState() => _X35RepeatingDetailState();
}

class _X35RepeatingDetailState extends State<X35RepeatingDetail> {
  late final RepeatingDetailController _controller = widget.controller ??
      RepeatingDetailController(
        gateway: widget.gateway,
        scheduleId: widget.scheduleId,
      );

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
            title: view?.name ?? '',
            dateLine: l.repeatingDetailSubline,
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
              _hero(l, view),
              if (view.occurrences.isNotEmpty) _history(l, view),
              _facts(l, view),
              if (_controller.errorCode == RepeatingErrorCode.stopFailed)
                Text(
                  l.repeatingStopFailed,
                  style: AppText.caption.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              if (view.isLive)
                AppButton(
                  label: l.repeatingStop,
                  variant: AppButtonVariant.ghost,
                  icon: AppIcons.trash,
                  onPressed: () => _stop(l),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _hero(AppLocalizations l, RepeatingDetailView view) {
    final currency = Currency.of(view.currencyCode);
    final amount = view.amountMinor;
    final frequencyLabel = switch (view.frequency) {
      RepeatFrequency.weekly => l.c02Weekly,
      RepeatFrequency.monthly => l.c02Monthly,
      RepeatFrequency.yearly => l.c02Yearly,
    };
    return ObHero(
      kicker: l.repeatingHeroKicker(view.name, frequencyLabel),
      value: amount == null
          ? ValueSpec.missing(l.repeatingNothingRecorded)
          : ValueSpec.real(Money.fromMinor(amount, currency)),
      contextLine: amount == null
          ? null
          : l.repeatingYearly(
              formatMoney(Money.fromMinor(amount * 12, currency)),
            ),
    );
  }

  Widget _history(AppLocalizations l, RepeatingDetailView view) {
    final currency = Currency.of(view.currencyCode);
    return GlassCard(
      title: l.repeatingHistory,
      meta: '${view.occurrences.length}',
      child: Column(
        children: <Widget>[
          for (final occurrence in view.occurrences) ...<Widget>[
            SelectRow(
              name: formatDate(occurrence.date, DateStyle.monthYear),
              value: occurrence.amountMinor == null
                  ? l.repeatingNothingRecorded
                  : formatMoney(
                      Money.fromMinor(occurrence.amountMinor!, currency),
                    ),
              line: occurrence.state == 'actual'
                  ? l.repeatingPaid
                  : l.repeatingExpected,
              chevron: false,
            ),
            const VSpace(Space.xxs),
          ],
        ],
      ),
    );
  }

  Widget _facts(AppLocalizations l, RepeatingDetailView view) {
    final currency = Currency.of(view.currencyCode);
    final next = view.nextDate;
    final amount = view.amountMinor;
    return GlassCard(
      child: Column(
        children: <Widget>[
          SelectRow(
            name: l.repeatingPaidWith,
            value: view.accountName ?? l.c02ChooseAccount,
            chevron: false,
          ),
          SelectRow(
            name: l.repeatingNextPayment,
            value: next == null
                ? l.repeatingNothingRecorded
                : '${formatDate(next, DateStyle.short)} · '
                    '${amount == null ? l.repeatingExpected : formatMoney(Money.fromMinor(amount, currency))}',
            chevron: false,
          ),
          SelectRow(
            name: l.repeatingCategory,
            value: view.kind.isEmpty
                ? l.repeatingNothingRecorded
                : '${view.kind[0].toUpperCase()}${view.kind.substring(1)}',
            chevron: false,
          ),
        ],
      ),
    );
  }

  Future<void> _stop(AppLocalizations l) async {
    final confirmed = await showAppDialog<bool>(
      context,
      leading: const IconTile(icon: AppIcons.trash),
      title: l.repeatingStopTitle,
      body: l.repeatingStopBody,
      primaryLabel: l.repeatingStop,
      primaryVariant: AppButtonVariant.destructive,
      secondaryLabel: l.repeatingStopKeep,
      semanticLabel: l.repeatingStopTitle,
      onPrimary: () => Navigator.of(context).pop(true),
      onSecondary: () => Navigator.of(context).pop(false),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final stopped = await _controller.stop();
    if (stopped && mounted) {
      widget.onClose();
    }
  }
}
