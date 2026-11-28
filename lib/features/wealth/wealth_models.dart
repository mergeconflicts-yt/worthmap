// X40 (SCREENS; SPEC 6.5, 13.12): the Wealth screen contract.
//
// One port. The app composition supplies the SQL reads; tests supply an
// in-memory one. The feature formats no money (AGENTS 6.4). Missing is never
// zero (SPEC 4.3).
library;

import '../../core/dates.dart';
import '../../core/percent.dart';

/// SCREENS X40: the period chips, 1Y by default.
enum WealthPeriod { oneMonth, oneYear, fiveYears }

/// One reading of the three series at a date.
///
/// Each series is Missing on its own: a cash account without an anchor makes
/// the cash point Missing but leaves a known net worth when that account is
/// outside net worth.
final class WealthPoint {
  const WealthPoint({
    required this.date,
    this.netWorthMinor,
    this.investmentsMinor,
    this.cashMinor,
  });

  final LocalDate date;
  final int? netWorthMinor;
  final int? investmentsMinor;
  final int? cashMinor;
}

/// A recorded part of what you own or owe (SCREENS X40).
enum WealthTypeKind { cash, investments, card }

final class WealthType {
  const WealthType({
    required this.kind,
    required this.amountMinor,
    required this.count,
  });

  final WealthTypeKind kind;

  /// The total in minor units; null is Missing.
  final int? amountMinor;
  final int count;
}

/// The optional net-worth target (G09 is v1.1; the demo passes one).
final class WealthTarget {
  const WealthTarget({
    required this.amountMinor,
    required this.date,
    required this.share,
  });

  final int amountMinor;
  final LocalDate date;
  final Percent? share;
}

/// One loaded Wealth screen.
final class WealthView {
  const WealthView({
    required this.currencyCode,
    required this.period,
    required this.netWorthMinor,
    required this.changeMinor,
    required this.changeShare,
    required this.points,
    required this.ownMinor,
    required this.oweMinor,
    required this.ownTypes,
    required this.oweTypes,
    required this.accountCount,
    this.target,
  });

  final String currencyCode;
  final WealthPeriod period;

  /// The net worth at the last point; null is Missing.
  final int? netWorthMinor;

  /// The change over the period; null when a reading is Missing.
  final int? changeMinor;
  final Percent? changeShare;

  /// Oldest first. The last point is today.
  final List<WealthPoint> points;

  final int? ownMinor;
  final int? oweMinor;
  final List<WealthType> ownTypes;
  final List<WealthType> oweTypes;
  final int accountCount;
  final WealthTarget? target;
}

/// The Wealth data port. It writes nothing.
abstract interface class WealthGateway {
  Future<WealthView> load(WealthPeriod period);
}

/// The app composition has not mounted a gateway (vault closed or unwired).
final class UnavailableWealthGateway implements WealthGateway {
  const UnavailableWealthGateway();

  @override
  Future<WealthView> load(WealthPeriod period) async =>
      throw const WealthError(WealthErrorCode.notWired);
}

/// Typed, safe failure codes (no amount or name in the text).
enum WealthErrorCode { notWired, loadFailed }

class WealthError implements Exception {
  const WealthError(this.code);

  final WealthErrorCode code;

  @override
  String toString() => 'WealthError($code)';
}
