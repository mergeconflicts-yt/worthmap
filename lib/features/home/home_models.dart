// Phase 4 (SCREENS X10; SPEC 6.1): the Home read model.
//
// Home shows one number (net worth), its 12-month line, Quick look, the next
// 30 days, this month and the footer facts. Every amount is a real read from
// the vault; a missing balance is Missing, never zero (SPEC 4.3).
library;

import '../../core/dates.dart';
import '../../core/percent.dart';

/// One month-end net worth point. A null amount is a gap.
final class HomeSeriesPoint {
  const HomeSeriesPoint({required this.month, required this.amountMinor});

  final LocalDate month;
  final int? amountMinor;
}

/// One dated item in the next 30 days.
final class HomeUpcomingItem {
  const HomeUpcomingItem({
    required this.date,
    required this.name,
    required this.amountMinor,
    required this.currencyCode,
    required this.kind,
  });

  final LocalDate date;
  final String name;

  /// Null is Missing: the amount is not known yet.
  final int? amountMinor;
  final String currencyCode;
  final String kind;
}

/// The parts of this month's money that can be read today.
///
/// Needs and Wants need the category tag, which the schema does not store yet
/// (`P26-NEEDS-WANTS`); they are absent here.
final class HomeIncomeSplit {
  const HomeIncomeSplit({
    required this.moneyInMinor,
    required this.needsMinor,
    required this.wantsMinor,
    required this.unclassifiedMinor,
    required this.investedMinor,
    required this.inCashMinor,
    required this.currencyCode,
  });

  final int moneyInMinor;
  final int needsMinor;
  final int wantsMinor;
  final int unclassifiedMinor;
  final int investedMinor;
  final int inCashMinor;
  final String currencyCode;
}

/// The net worth target: the amount and the date, plus the share reached.
///
/// SPEC 13.2: the target measures net worth and assigns no money. The share is
/// null when net worth is Missing or the target is zero, so no bar is drawn.
final class HomeNetWorthTarget {
  const HomeNetWorthTarget({
    required this.amountMinor,
    required this.date,
    required this.share,
  });

  final int amountMinor;
  final LocalDate date;

  /// The reached share in percentage points. Null is not available.
  final Percent? share;
}

/// The Home screen summary.
final class HomeSummary {
  const HomeSummary({
    required this.currencyCode,
    required this.month,
    required this.monthDay,
    required this.monthDays,
    required this.inboxCount,
    required this.repeatingCount,
    required this.accountCount,
    required this.netWorthSeries,
    required this.upcoming,
    this.netWorthMinor,
    this.netWorthChangeMinor,
    this.netWorthTarget,
    this.cashMinor,
    this.cardOwedMinor,
    this.cardName,
    this.investmentsMinor,
    this.investmentsTodayMinor,
    this.subscriptionsMonthlyMinor,
    this.moneyInMinor,
    this.spentMinor,
    this.limitMinor,
    this.used,
    this.monthGone,
    this.incomeSplit,
  });

  final String currencyCode;

  /// The first day of the budget month.
  final LocalDate month;

  /// Null is Missing: no balance anchor covers the account.
  final int? netWorthMinor;

  /// The change from the first known point to the last, over 12 months.
  final int? netWorthChangeMinor;

  /// The owner's net worth target. Null when no target exists (v1: goals
  /// record G09 is not shipped; the line stays absent).
  final HomeNetWorthTarget? netWorthTarget;
  final List<HomeSeriesPoint> netWorthSeries;
  final int? cashMinor;
  final int? cardOwedMinor;

  /// The name of the one card the bill belongs to. Null when there is no card
  /// or more than one.
  final String? cardName;

  final int? investmentsMinor;

  /// The change in the investments value today. Null when it is not read.
  final int? investmentsTodayMinor;

  final int? subscriptionsMonthlyMinor;
  final int? moneyInMinor;
  final int? spentMinor;
  final int? limitMinor;
  final Percent? used;
  final Percent? monthGone;
  final int monthDay;
  final int monthDays;
  final int inboxCount;
  final int repeatingCount;
  final int accountCount;
  final List<HomeUpcomingItem> upcoming;
  final HomeIncomeSplit? incomeSplit;
}

/// The Home data port. Reads only.
abstract interface class HomeGateway {
  Future<HomeSummary> load();
}

/// The placeholder port before the composition mounts the vault.
final class UnavailableHomeGateway implements HomeGateway {
  const UnavailableHomeGateway();

  @override
  Future<HomeSummary> load() async => throw StateError('home-not-wired');
}
