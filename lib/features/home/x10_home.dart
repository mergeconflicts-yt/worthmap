// Phase 4 first slice (SCREENS X10; SPEC 6.1): Home with data.
//
// One hero number (net worth), a quick look, this month and the latest
// payments. Every value is a read. Missing balances stay Missing. Amounts use
// MoneyText, so the hidden state masks them.
library;

import 'package:flutter/material.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'home_models.dart';

/// X10: Home with real records.
class X10Home extends StatefulWidget {
  const X10Home({
    required this.gateway,
    required this.onInbox,
    required this.onSettings,
    required this.onSpending,
    required this.onAllPayments,
    this.today,
    super.key,
  });

  final HomeGateway gateway;
  final VoidCallback onInbox;
  final VoidCallback onSettings;
  final VoidCallback onSpending;
  final VoidCallback onAllPayments;

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
          _quickLook(l, summary),
          _thisMonth(l, summary),
          _recent(l, summary),
          AppButton(
            label: l.x10OpenSpending,
            onPressed: widget.onSpending,
          ),
          AppButton(
            label: l.x10AllPayments,
            variant: AppButtonVariant.ghost,
            onPressed: widget.onAllPayments,
          ),
        ],
      ],
    );
  }

  Widget _hero(AppLocalizations l, HomeSummary summary) {
    final currency = Currency.of(summary.currencyCode);
    final netWorth = summary.netWorthMinor;
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
    );
  }

  Widget _quickLook(AppLocalizations l, HomeSummary summary) {
    final currency = Currency.of(summary.currencyCode);
    Widget? amount(int? minor, {String? prefix}) => minor == null
        ? Text('—', style: AppText.body)
        : MoneyText(
            ValueSpec.real(Money.fromMinor(minor, currency)),
            prefix: prefix,
            style: AppText.body,
          );
    return GlassCard(
      title: l.x10QuickLook,
      meta: l.x03Today,
      child: Column(
        children: <Widget>[
          SelectRow(
            name: l.x10Cash,
            trailing: amount(summary.cashMinor),
            chevron: false,
          ),
          SelectRow(
            name: l.x10CardBill,
            trailing: amount(summary.cardOwedMinor, prefix: l.x10Owes),
            chevron: false,
          ),
          SelectRow(
            name: l.x10Inbox,
            value: '${summary.inboxCount}',
            chevron: false,
          ),
          SelectRow(
            name: l.x10Repeating,
            value: '${summary.repeatingCount}',
            chevron: false,
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
    return GlassCard(
      title: l.x10ThisMonth,
      meta: l.x10DayOf(summary.monthDay, summary.monthDays),
      child: Column(
        children: <Widget>[
          SelectRow(
            name: l.x10MoneyIn,
            trailing: summary.moneyInMinor == null
                ? Text('—', style: AppText.body)
                : MoneyText(
                    ValueSpec.real(
                      Money.fromMinor(summary.moneyInMinor!, currency),
                    ),
                    style: AppText.body,
                  ),
            chevron: false,
          ),
          SelectRow(
            name: l.x10Spent,
            line: used == null || limit == null
                ? l.x10NoLimit
                : l.x10OfLimit(formatPercent(used, decimals: 0)),
            trailing: spent == null
                ? Text('—', style: AppText.body)
                : MoneyText(
                    ValueSpec.real(Money.fromMinor(spent, currency)),
                    style: AppText.body,
                  ),
            chevron: false,
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
        ],
      ),
    );
  }

  Widget _recent(AppLocalizations l, HomeSummary summary) {
    return GlassCard(
      title: l.x10Recent,
      meta: '${summary.recent.length}',
      child: Column(
        children: <Widget>[
          if (summary.recent.isEmpty)
            SelectRow(name: l.x10NoRecent, chevron: false)
          else
            for (final payment in summary.recent)
              SelectRow(
                name:
                    '${formatDate(payment.date, DateStyle.short)} · ${payment.merchantName ?? payment.categoryName ?? ''}',
                trailing: MoneyText(
                  ValueSpec.real(
                    Money.fromMinor(
                      payment.amountMinor,
                      Currency.of(payment.currencyCode),
                    ),
                  ),
                  sign: SignStyle.always,
                  style: AppText.body,
                ),
                chevron: false,
              ),
        ],
      ),
    );
  }
}

LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
