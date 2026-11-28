// Phase 4 (SCREENS X40): the Wealth composition.
//
// Reads come from the P14 account balances. The gateway writes nothing and
// formats no money (AGENTS 6.4). A point before an account's anchor is
// Missing, so a 5Y change is Missing until the history covers it.
library;

import '../core/dates.dart';
import '../core/money.dart';
import '../data/repositories/accounts.dart';
import '../data/repositories/inbox.dart';
import '../domain/numbers/net_worth_target.dart';
import '../domain/numbers/wealth_change.dart';
import '../domain/periods/budget_month.dart';
import '../domain/periods/period_math.dart';
import '../features/wealth/wealth_models.dart';

/// The account repository behind [WealthGateway].
final class SqlWealthGateway implements WealthGateway {
  SqlWealthGateway({
    required this.accounts,
    required this.inbox,
    required this.today,
    this.currencyCode = 'USD',
    this.targetMinor,
    this.targetDate,
    this.unvestedMinor,
    this.owedToYouMinor,
    this.dividendsMinor,
  });

  final AccountRepository accounts;
  final InboxRepository inbox;
  final LocalDate Function() today;
  final String currencyCode;

  /// Synthetic demo values for "Not in net worth". The release path passes
  /// none, so the rows stay out until records exist.
  final int? unvestedMinor;
  final int? owedToYouMinor;
  final int? dividendsMinor;

  /// The owner's target. Null in v1 until the goals record ships (G09).
  final int? targetMinor;
  final LocalDate? targetDate;

  @override
  Future<WealthView> load(WealthPeriod period) async {
    final date = today();
    final rows = await accounts.list();
    final points = <WealthPoint>[];
    for (final pointDate in await _dates(period, date)) {
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
    // MAX uses the earliest known reading; the other periods use their own
    // start, so a short history stays Missing (SCREENS X40 5Y).
    int? first;
    if (period == WealthPeriod.max) {
      for (final point in points) {
        if (point.netWorthMinor != null) {
          first = point.netWorthMinor;
          break;
        }
      }
    } else {
      first = points.isEmpty ? null : points.first.netWorthMinor;
    }

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
      today: date,
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
      inboxCount: await inbox.pendingCount(),
      target: target,
      unvestedMinor: unvestedMinor,
      owedToYouMinor: owedToYouMinor,
      dividendsMinor: dividendsMinor,
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
  /// 1D, 1W and 1M are rolling days (SCREENS X40: 1M is 30 days). 1Y and 5Y
  /// use month ends. MAX starts at the first anchor month. Every period ends
  /// at today, never at a future date.
  Future<List<LocalDate>> _dates(WealthPeriod period, LocalDate today) async {
    switch (period) {
      case WealthPeriod.oneDay:
        return <LocalDate>[addDays(today, -1), today];
      case WealthPeriod.oneWeek:
        return <LocalDate>[for (var i = 7; i >= 0; i--) addDays(today, -i)];
      case WealthPeriod.oneMonth:
        return <LocalDate>[for (var i = 30; i >= 0; i--) addDays(today, -i)];
      case WealthPeriod.oneYear:
        return _monthEnds(today, 12);
      case WealthPeriod.fiveYears:
        return _monthEnds(today, 60);
      case WealthPeriod.max:
        final raw = await accounts.firstAnchorDate();
        final anchor = raw == null ? null : LocalDate.tryParse(raw);
        if (anchor == null) {
          return <LocalDate>[today];
        }
        final monthStart = LocalDate(today.year, today.month, 1);
        final start = LocalDate(anchor.year, anchor.month, 1);
        var months = 0;
        var cursor = start;
        while (cursor.compareTo(monthStart) < 0) {
          months++;
          cursor = addMonths(cursor, 1);
        }
        return _monthEnds(today, months);
    }
  }

  List<LocalDate> _monthEnds(LocalDate today, int months) {
    final monthStart = LocalDate(today.year, today.month, 1);
    return <LocalDate>[
      for (var i = months; i >= 1; i--)
        BudgetMonth.containing(addMonths(monthStart, -i)).end,
      today,
    ];
  }
}
