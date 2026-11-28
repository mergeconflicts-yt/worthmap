// Phase 4 (SCREENS X10): the Home composition.
//
// Reads come from the P14 balances, the P15 spending projection, the P26
// money-in read, the P17 Inbox count, the schedule list, upcoming occurrences
// and the holding count. The gateway writes nothing. Money is not formatted
// here (AGENTS 6.4).
library;

import '../core/dates.dart';
import '../core/money.dart';
import '../data/repositories/accounts.dart';
import '../data/repositories/categories.dart';
import '../data/repositories/inbox.dart';
import '../data/repositories/occurrences.dart';
import '../data/repositories/schedules.dart';
import '../domain/numbers/net_worth_target.dart';
import '../domain/periods/budget_month.dart';
import '../domain/periods/period_math.dart';
import '../features/home/home_models.dart';
import '../features/spending/spending_models.dart';

/// The existing feature ports and repositories behind [HomeGateway].
final class SqlHomeGateway implements HomeGateway {
  SqlHomeGateway({
    required this.accounts,
    required this.categories,
    required this.inbox,
    required this.schedules,
    required this.occurrences,
    required this.spending,
    required this.today,
    this.currencyCode = 'USD',
    this.netWorthTargetMinor,
    this.netWorthTargetDate,
    this.investmentsTodayMinor,
  });

  final AccountRepository accounts;
  final CategoryRepository categories;
  final InboxRepository inbox;
  final ScheduleRepository schedules;
  final OccurrenceRepository occurrences;
  final SpendingGateway spending;
  final LocalDate Function() today;
  final String currencyCode;

  /// The owner's target. Null in v1 until the goals record ships (G09).
  final int? netWorthTargetMinor;
  final LocalDate? netWorthTargetDate;

  /// The synthetic demo value for the investments "today" line. Null until
  /// the holdings and prices read lands (Phase 5), so the release path shows
  /// no line.
  final int? investmentsTodayMinor;

  @override
  Future<HomeSummary> load() async {
    final date = today();
    final month = BudgetMonth.containing(date);
    final spendingView = await spending.loadSpending(SpendingPeriod.month);
    final moneyInView = await spending.loadMoneyIn(SpendingPeriod.month);
    final inboxCount = await inbox.pendingCount();
    final schedulesList = await schedules.list();
    final accountRows = await accounts.list();

    var netWorth = 0;
    var netWorthMissing = false;
    var cash = 0;
    var cashMissing = false;
    var cardOwed = 0;
    var cardMissing = false;
    var cardCount = 0;
    String? cardName;
    var investments = 0;
    var investmentsMissing = false;
    for (final account in accountRows) {
      final balance = await accounts.balanceAt(
        accountId: account.id,
        asOf: date.toString(),
      );
      final minor = switch (balance) {
        KnownBalance(:final amount) => amount.minor,
        MissingBalance() => null,
      };
      if (account.includeInNetWorth) {
        if (minor == null) {
          netWorthMissing = true;
        } else {
          netWorth += minor;
        }
      }
      if (account.isLiquid) {
        if (minor == null) {
          cashMissing = true;
        } else {
          cash += minor;
        }
      }
      if (account.isLiability) {
        cardCount++;
        cardName = cardCount == 1 ? account.name : null;
        if (minor == null) {
          cardMissing = true;
        } else {
          cardOwed += -minor;
        }
      }
      if (!account.isLiquid &&
          !account.isLiability &&
          account.includeInNetWorth) {
        if (minor == null) {
          investmentsMissing = true;
        } else {
          investments += minor;
        }
      }
    }

    // The 12 month-end net worth points. A month before an anchor, or with a
    // missing account, is a gap.
    final series = <HomeSeriesPoint>[];
    final months = <LocalDate>[
      for (var i = 11; i >= 0; i--)
        BudgetMonth.containing(addMonths(month.start, -i)).start,
    ];
    for (final monthStart in months) {
      final cutOff = BudgetMonth.containing(monthStart).end;
      var sum = 0;
      var missing = false;
      for (final account in accountRows) {
        if (!account.includeInNetWorth) continue;
        final balance = await accounts.balanceAt(
          accountId: account.id,
          asOf: cutOff.toString(),
        );
        final minor = switch (balance) {
          KnownBalance(:final amount) => amount.minor,
          MissingBalance() => null,
        };
        if (minor == null) {
          missing = true;
        } else {
          sum += minor;
        }
      }
      series.add(
        HomeSeriesPoint(
          month: monthStart,
          amountMinor: missing ? null : sum,
        ),
      );
    }
    final first = series.isEmpty ? null : series.first.amountMinor;
    final last = series.isEmpty ? null : series.last.amountMinor;

    int? subscriptions;
    for (final schedule in schedulesList) {
      if (schedule.kind != 'subscription') continue;
      final rule = schedule.rrule ?? '';
      if (!rule.contains('FREQ=MONTHLY')) continue;
      final amount = schedule.amountMinor;
      if (amount == null) {
        subscriptions = null;
        break;
      }
      subscriptions = (subscriptions ?? 0) + amount;
    }

    final upcomingRows = await occurrences.upcomingBetween(
      from: date,
      to: addDays(date, 30),
    );

    final holdingRows = await accounts.holdingCount();
    final invested = holdingRows == 0 ? 0 : null;
    final moneyIn = moneyInView.amountMinor;
    final spent = spendingView.moneyOutMinor;

    final resolvedNetWorth = netWorthMissing ? null : netWorth;
    final targetMinor = netWorthTargetMinor;
    final targetDate = netWorthTargetDate;
    final target = targetMinor == null || targetDate == null
        ? null
        : HomeNetWorthTarget(
            amountMinor: targetMinor,
            date: targetDate,
            share: netWorthTargetShare(
              current: resolvedNetWorth == null
                  ? null
                  : Money.fromMinor(
                      resolvedNetWorth,
                      Currency.of(currencyCode),
                    ),
              target: Money.fromMinor(
                targetMinor,
                Currency.of(currencyCode),
              ),
            ),
          );

    var needs = 0;
    var wants = 0;
    var unclassified = 0;
    final tagged = <String, bool?>{
      for (final category in await categories.list(kind: 'expense'))
        category.id: category.isEssential,
    };
    for (final category in spendingView.categories) {
      final tag = tagged[category.id];
      if (tag == true) {
        needs += category.amountMinor;
      } else if (tag == false) {
        wants += category.amountMinor;
      } else {
        unclassified += category.amountMinor;
      }
    }

    return HomeSummary(
      currencyCode: currencyCode,
      month: month.start,
      netWorthMinor: resolvedNetWorth,
      netWorthChangeMinor: first == null || last == null ? null : last - first,
      netWorthTarget: target,
      netWorthSeries: series,
      cashMinor: cashMissing ? null : cash,
      cardOwedMinor: cardMissing ? null : cardOwed,
      cardName: cardMissing ? null : cardName,
      investmentsMinor: investmentsMissing ? null : investments,
      investmentsTodayMinor: investmentsMissing ? null : investmentsTodayMinor,
      subscriptionsMonthlyMinor: subscriptions,
      moneyInMinor: moneyIn,
      spentMinor: spent,
      limitMinor: spendingView.limitMinor,
      used: spendingView.used,
      monthGone: spendingView.monthGone,
      monthDay: month.dayNumber,
      monthDays: month.lengthInDays,
      inboxCount: inboxCount,
      repeatingCount: schedulesList.length,
      accountCount: accountRows.length,
      upcoming: <HomeUpcomingItem>[
        for (final row in upcomingRows)
          HomeUpcomingItem(
            date: LocalDate.tryParse(row.date) ?? date,
            name: row.name,
            amountMinor: row.amountMinor,
            currencyCode: row.currency,
            kind: row.kind,
          ),
      ],
      incomeSplit: moneyIn == null || spent == null || invested == null
          ? null
          : HomeIncomeSplit(
              moneyInMinor: moneyIn,
              needsMinor: needs,
              wantsMinor: wants,
              unclassifiedMinor: unclassified,
              investedMinor: invested,
              inCashMinor: moneyIn - spent,
              currencyCode: currencyCode,
            ),
    );
  }
}
