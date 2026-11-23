// Phase 4 first slice (SCREENS X10): the Home composition.
//
// Reads come from the existing P14 balances, P15 spending projection, P26
// money-in read, P27 payment list, P17 Inbox count and the schedule list. The
// gateway writes nothing. Money is not formatted here (AGENTS 6.4).
library;

import '../core/dates.dart';
import '../data/repositories/accounts.dart';
import '../data/repositories/inbox.dart';
import '../data/repositories/schedules.dart';
import '../domain/periods/budget_month.dart';
import '../features/home/home_models.dart';
import '../features/spending/payments_models.dart';
import '../features/spending/spending_models.dart';

/// The existing feature ports and repositories behind [HomeGateway].
final class SqlHomeGateway implements HomeGateway {
  SqlHomeGateway({
    required this.accounts,
    required this.inbox,
    required this.schedules,
    required this.spending,
    required this.payments,
    required this.today,
    this.currencyCode = 'USD',
  });

  final AccountRepository accounts;
  final InboxRepository inbox;
  final ScheduleRepository schedules;
  final SpendingGateway spending;
  final PaymentsReadGateway payments;
  final LocalDate Function() today;
  final String currencyCode;

  @override
  Future<HomeSummary> load() async {
    final date = today();
    final month = BudgetMonth.containing(date);
    final spendingView = await spending.loadSpending(SpendingPeriod.month);
    final moneyInView = await spending.loadMoneyIn(SpendingPeriod.month);
    final paymentPage = await payments.loadPayments(
      const PaymentFilter(
        period: PaymentPeriod.thisMonth,
        show: PaymentShowFilter.moneyOut,
      ),
    );
    final inboxCount = await inbox.pendingCount();
    final schedulesList = await schedules.list();

    var netWorth = 0;
    var netWorthMissing = false;
    var cash = 0;
    var cashMissing = false;
    var cardOwed = 0;
    var cardMissing = false;
    for (final account in await accounts.list()) {
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
        if (minor == null) {
          cardMissing = true;
        } else {
          cardOwed += -minor;
        }
      }
    }

    return HomeSummary(
      currencyCode: currencyCode,
      netWorthMinor: netWorthMissing ? null : netWorth,
      cashMinor: cashMissing ? null : cash,
      cardOwedMinor: cardMissing ? null : cardOwed,
      moneyInMinor: moneyInView.amountMinor,
      spentMinor: spendingView.moneyOutMinor,
      limitMinor: spendingView.limitMinor,
      used: spendingView.used,
      monthGone: spendingView.monthGone,
      monthDay: month.dayNumber,
      monthDays: month.lengthInDays,
      inboxCount: inboxCount,
      repeatingCount: schedulesList.length,
      recent: <HomeRecentPayment>[
        for (final item in paymentPage.items.take(5))
          HomeRecentPayment(
            id: item.id,
            date: item.date,
            amountMinor: item.amountMinor,
            currencyCode: item.currencyCode,
            merchantName: item.merchantName,
            categoryName: item.categoryName,
          ),
      ],
    );
  }
}
