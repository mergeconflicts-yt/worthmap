// Phase 4 first slice (SCREENS X10; SPEC 6.1): the Home read model.
//
// Home shows one number (net worth), a quick look, this month and the latest
// payments. Every amount is a real read from the vault; a missing balance is
// Missing, never zero (SPEC 4.3). No advice, no score.
library;

import '../../core/dates.dart';
import '../../core/percent.dart';

/// One recent payment row.
final class HomeRecentPayment {
  const HomeRecentPayment({
    required this.id,
    required this.date,
    required this.amountMinor,
    required this.currencyCode,
    this.merchantName,
    this.categoryName,
  });

  final String id;
  final LocalDate date;
  final int amountMinor;
  final String currencyCode;
  final String? merchantName;
  final String? categoryName;
}

/// The Home screen summary.
final class HomeSummary {
  const HomeSummary({
    required this.currencyCode,
    required this.monthDay,
    required this.monthDays,
    required this.inboxCount,
    required this.repeatingCount,
    required this.recent,
    this.netWorthMinor,
    this.cashMinor,
    this.cardOwedMinor,
    this.moneyInMinor,
    this.spentMinor,
    this.limitMinor,
    this.used,
    this.monthGone,
  });

  final String currencyCode;

  /// Null is Missing: no balance anchor covers the account.
  final int? netWorthMinor;
  final int? cashMinor;
  final int? cardOwedMinor;
  final int? moneyInMinor;
  final int? spentMinor;
  final int? limitMinor;
  final Percent? used;
  final Percent? monthGone;
  final int monthDay;
  final int monthDays;
  final int inboxCount;
  final int repeatingCount;
  final List<HomeRecentPayment> recent;
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
