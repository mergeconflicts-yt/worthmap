// Phase 4 (SCREENS X40): the Wealth composition.
//
// Reads come from the P14 account balances. The gateway writes nothing and
// formats no money (AGENTS 6.4). A point before an account's anchor is
// Missing, so a 5Y change is Missing until the history covers it.
library;

import '../core/dates.dart';
import '../core/money.dart';
import '../data/repositories/accounts.dart';
import '../domain/numbers/net_worth_target.dart';
import '../domain/numbers/wealth_change.dart';
import '../domain/periods/budget_month.dart';
import '../domain/periods/period_math.dart';
import '../features/wealth/wealth_models.dart';

/// The account repository behind [WealthGateway].
final class SqlWealthGateway implements WealthGateway {
  SqlWealthGateway({
    required this.accounts,
    required this.today,
    this.currencyCode = 'USD',
    this.targetMinor,
    this.targetDate,
  });

  final AccountRepository accounts;
  final LocalDate Function() today;
  final String currencyCode;

  /// The owner's target. Null in v1 until the goals record ships (G09).
  final int? targetMinor;
  final LocalDate? targetDate;

  @override
  Future<WealthView> load(WealthPeriod period) async {
    final date = today();
    final rows = await accounts.list();
    final points = <WealthPoint>[];
    for (final pointDate in _dates(period, date)) {
      points.add(await _point(rows, pointDate));
    }

    var own = 0;
    var owe = 0;
    var ownMissing = false;
    var oweMissing = false;
    var cash = 0;
    var cashMissing = false;
    var investments = 0;
    var investmentsMissing = false;
    var cashCount = 0;
    var investmentsCount = 0;
    var cardCount = 0;
    for (final account in rows) {
      if (!account.includeInNetWorth) {
        continue;
      }
      final balance = await accounts.balanceAt(
        accountId: account.id,
        asOf: date.toString(),
      );
      final minor = switch (balance) {
        KnownBalance(:final amount) => amount.minor,
        MissingBalance() => null,
      };
      if (account.isLiability) {
        cardCount++;
        if (minor == null) {
          oweMissing = true;
        } else {
          owe += -minor;
        }
      } else if (account.isLiquid) {
        cashCount++;
        if (minor == null) {
          ownMissing = true;
          cashMissing = true;
        } else {
          own += minor;
          cash += minor;
        }
      } else {
        investmentsCount++;
        if (minor == null) {
          ownMissing = true;
          investmentsMissing = true;
        } else {
          own += minor;
          investments += minor;
        }
      }
    }
    final last = points.isEmpty ? null : points.last.netWorthMinor;
    final first = points.isEmpty ? null : points.first.netWorthMinor;

    final targetMinorNow = targetMinor;
    final targetDateNow = targetDate;
    final target = targetMinorNow == null || targetDateNow == null
        ? null
        : WealthTarget(
            amountMinor: targetMinorNow,
            date: targetDateNow,
            share: netWorthTargetShare(
              current: last == null
                  ? null
                  : Money.fromMinor(last, Currency.of(currencyCode)),
              target: Money.fromMinor(
                targetMinorNow,
                Currency.of(currencyCode),
              ),
            ),
          );

    return WealthView(
      currencyCode: currencyCode,
      period: period,
      netWorthMinor: last,
      changeMinor: wealthChangeMinor(startMinor: first, endMinor: last),
      changeShare: wealthChangeShare(startMinor: first, endMinor: last),
      points: points,
      ownMinor: ownMissing ? null : own,
      oweMinor: oweMissing ? null : owe,
      ownTypes: <WealthType>[
        if (cashCount > 0)
          WealthType(
            kind: WealthTypeKind.cash,
            amountMinor: cashMissing ? null : cash,
            count: cashCount,
          ),
        if (investmentsCount > 0)
          WealthType(
            kind: WealthTypeKind.investments,
            amountMinor: investmentsMissing ? null : investments,
            count: investmentsCount,
          ),
      ],
      oweTypes: <WealthType>[
        if (cardCount > 0)
          WealthType(
            kind: WealthTypeKind.card,
            amountMinor: oweMissing ? null : owe,
            count: cardCount,
          ),
      ],
      accountCount: rows.length,
      target: target,
    );
  }

  Future<WealthPoint> _point(
    List<AccountRow> rows,
    LocalDate date,
  ) async {
    var netWorth = 0;
    var netWorthMissing = false;
    var cash = 0;
    var cashMissing = false;
    var investments = 0;
    var investmentsMissing = false;
    for (final account in rows) {
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
      } else if (!account.isLiability && account.includeInNetWorth) {
        if (minor == null) {
          investmentsMissing = true;
        } else {
          investments += minor;
        }
      }
    }
    return WealthPoint(
      date: date,
      netWorthMinor: netWorthMissing ? null : netWorth,
      investmentsMinor: investmentsMissing ? null : investments,
      cashMinor: cashMissing ? null : cash,
    );
  }

  /// The dates of the selected period, oldest first.
  ///
  /// 1M is rolling 30 days (SCREENS X40). 1Y and 5Y use month ends, then
  /// today, so the last point is never a future date.
  List<LocalDate> _dates(WealthPeriod period, LocalDate today) {
    if (period == WealthPeriod.oneMonth) {
      return <LocalDate>[for (var i = 30; i >= 0; i--) addDays(today, -i)];
    }
    final months = period == WealthPeriod.oneYear ? 12 : 60;
    final monthStart = LocalDate(today.year, today.month, 1);
    return <LocalDate>[
      for (var i = months; i >= 1; i--)
        BudgetMonth.containing(addMonths(monthStart, -i)).end,
      today,
    ];
  }
}
