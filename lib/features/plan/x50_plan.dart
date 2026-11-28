// X50 (SCREENS; SPEC 6.10): Plan, the calendar tab.
//
// The screen shows the Expected occurrences from today to 45 days ahead, the
// day grid with one glyph per event, and the payments before and from the
// next income. A day with events opens the X51 sheet. Missing is never zero.
library;

import 'package:flutter/widgets.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'plan_models.dart';

/// X50: the calendar, the glyphs and the payment list.
class X50Plan extends StatefulWidget {
  const X50Plan({required this.gateway, super.key});

  final PlanGateway gateway;

  @override
  State<X50Plan> createState() => _X50PlanState();
}

class _X50PlanState extends State<X50Plan> {
  PlanView? _view;
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
      final view = await widget.gateway.load();
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TabRootScreen(
      header: ScreenHeader(
        kicker: l.planKicker,
        actions: const <Widget>[HideAmountsButton()],
      ),
      children: <Widget>[
        if (_loading)
          Text(l.spendingLoading, style: AppText.caption)
        else if (_failed) ...<Widget>[
          Text(l.planLoadFailed, style: AppText.bodyStrong),
          AppButton(
            label: l.planRetry,
            variant: AppButtonVariant.soft,
            onPressed: _load,
          ),
        ] else if (_view != null)
          ..._body(l, _view!),
      ],
    );
  }

  List<Widget> _body(AppLocalizations l, PlanView view) {
    return <Widget>[
      GlassCard(
        variant: GlassCardVariant.stage,
        title: formatMonthYear(view.today),
        meta: l.planMeta(formatDate(view.rangeEnd, DateStyle.short)),
        child: SymbolCalendar(
          first: view.rangeStart,
          last: view.rangeEnd,
          today: view.today,
          entries: <CalendarEntry>[
            for (final event in view.events)
              CalendarEntry(
                date: event.date,
                mark: switch (event.kind) {
                  PlanEventKind.income => CalendarMark.income,
                  PlanEventKind.investing => CalendarMark.investing,
                  PlanEventKind.spending => CalendarMark.spending,
                },
              ),
          ],
          onDay: (LocalDate date) => _openDay(l, view, date),
          spokenLabel: (LocalDate date, int count) => l.calendarSpoken(
            count,
            formatDate(date, DateStyle.monthYear),
          ),
        ),
      ),
      const VSpace(Space.card),
      if (view.events.isEmpty)
        Text(l.planNoEvents, style: AppText.caption)
      else ...<Widget>[
        GlassCard(
          title: view.nextIncomeDate == null
              ? l.planNextDays(_rangeDays(view))
              : l.planBeforeIncome,
          meta: _sumText(l, view, view.beforeIncome),
          child: Column(
            children: <Widget>[
              for (final event in view.beforeIncome)
                _row(l, event, view.currencyCode),
              if (view.fromIncome.isNotEmpty) ...<Widget>[
                const VSpace(Space.s),
                Text(
                  l.planFromIncome,
                  style: AppText.labelCaps.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                const VSpace(Space.xs),
                for (final event in view.fromIncome)
                  _row(l, event, view.currencyCode),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _row(AppLocalizations l, PlanEvent event, String currencyCode) {
    final tokens = context.tokens;
    final amount = event.amountMinor;
    final money = amount == null
        ? null
        : Money.fromMinor(
            event.kind == PlanEventKind.income ? amount : -amount,
            Currency.of(
              event.currencyCode.isEmpty ? currencyCode : event.currencyCode,
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
                  event.name,
                  style: AppText.body.copyWith(color: tokens.textPrimary),
                ),
                Text(
                  '${formatDate(event.date, DateStyle.short)} · '
                  '${_kindLabel(l, event.kind)}',
                  style: AppText.caption.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const HSpace(Space.s),
          if (money == null)
            Text(
              l.wealthMissing,
              style: AppText.bodyS.copyWith(color: tokens.textSecondary),
            )
          else
            MoneyText(
              ValueSpec.real(money),
              trimZeroFraction: true,
              sign: SignStyle.always,
              style: AppText.bodyS.copyWith(color: tokens.textPrimary),
            ),
        ],
      ),
    );
  }

  Future<void> _openDay(
    AppLocalizations l,
    PlanView view,
    LocalDate date,
  ) async {
    final events = <PlanEvent>[
      for (final event in view.events)
        if (event.date == date) event,
    ];
    await showAppSheet<void>(
      context,
      title: formatDate(date, DateStyle.long),
      semanticLabel: l.planDayTitle,
      children: <Widget>[
        for (final event in events) _row(l, event, view.currencyCode),
        const VSpace(Space.m),
        AppButton(
          label: l.planDayDone,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  String? _sumText(
    AppLocalizations l,
    PlanView view,
    List<PlanEvent> events,
  ) {
    if (events.isEmpty) {
      return null;
    }
    final currency = Currency.of(view.currencyCode);
    var sum = 0;
    for (final event in events) {
      final amount = event.amountMinor;
      if (amount == null) {
        return l.wealthMissing;
      }
      sum += event.kind == PlanEventKind.income ? amount : -amount;
    }
    return formatMoney(
      Money.fromMinor(sum, currency),
      sign: SignStyle.always,
      trimZeroFraction: true,
    );
  }

  /// The days of the window: 45 for the X50 reference ("Next 45 days").
  static int _rangeDays(PlanView view) {
    final start = DateTime(
      view.rangeStart.year,
      view.rangeStart.month,
      view.rangeStart.day,
    );
    final end = DateTime(
      view.rangeEnd.year,
      view.rangeEnd.month,
      view.rangeEnd.day,
    );
    return end.difference(start).inDays;
  }

  static String _kindLabel(AppLocalizations l, PlanEventKind kind) =>
      switch (kind) {
        PlanEventKind.income => l.planKindIncome,
        PlanEventKind.investing => l.planKindInvesting,
        PlanEventKind.spending => l.planKindSpending,
      };
}
