// P28 (SCREENS X34, X35, X84, C02, C03; flow F09): repeating payments and
// category rules.
//
// A schedule proposes; a saved schedule writes no payment (F09-A). Stop keeps
// confirmed history (F09-C). A rule only proposes a category and never
// reclassifies by itself (SPEC 9.3, F09-D).
library;

import '../../core/dates.dart';

/// The frequency choices of C02.
enum RepeatFrequency { weekly, monthly, yearly }

/// One schedule of X34.
final class RepeatingItem {
  const RepeatingItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.revision,
    required this.amountState,
    this.amountMinor,
    this.nextDate,
    this.paidThisMonth = false,
    this.frequency = RepeatFrequency.monthly,
  });

  final String id;
  final String name;
  final String kind;
  final String currencyCode;
  final int revision;
  final String amountState;

  /// Null when the amount is Missing (never zero, SPEC 4.3).
  final int? amountMinor;
  final LocalDate? nextDate;
  final bool paidThisMonth;
  final RepeatFrequency frequency;
}

/// X34: the repeating list and its monthly total.
final class RepeatingView {
  const RepeatingView({
    required this.items,
    required this.monthlyTotalMinor,
    required this.currencyCode,
    required this.monthlyCount,
    required this.yearlyCount,
    this.changesThisMonth = 0,
  });

  final List<RepeatingItem> items;

  /// Every schedule converted to a monthly amount.
  final int monthlyTotalMinor;
  final String currencyCode;
  final int monthlyCount;
  final int yearlyCount;

  /// The number of schedules with a price change in the current month.
  final int changesThisMonth;

  /// The yearly total, from the monthly total.
  int get yearlyTotalMinor => monthlyTotalMinor * 12;
}

/// One past occurrence of X35.
final class OccurrencePoint {
  const OccurrencePoint({
    required this.date,
    required this.amountMinor,
    required this.state,
  });

  final LocalDate date;
  final int? amountMinor;

  /// `expected`, `estimated` or `actual`.
  final String state;
}

/// One price observation of X35.
final class PriceChangePoint {
  const PriceChangePoint({
    required this.date,
    required this.oldMinor,
    required this.newMinor,
  });

  final LocalDate date;
  final int oldMinor;
  final int newMinor;
}

/// X35: one schedule with its history.
final class RepeatingDetailView {
  const RepeatingDetailView({
    required this.id,
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.revision,
    required this.amountState,
    required this.startDate,
    required this.endDate,
    required this.frequency,
    this.amountMinor,
    this.nextDate,
    this.accountName,
    this.occurrences = const <OccurrencePoint>[],
    this.priceChanges = const <PriceChangePoint>[],
  });

  final String id;
  final String name;
  final String kind;
  final String currencyCode;
  final int revision;
  final String amountState;
  final LocalDate startDate;
  final LocalDate? endDate;
  final RepeatFrequency frequency;
  final int? amountMinor;
  final LocalDate? nextDate;
  final String? accountName;
  final List<OccurrencePoint> occurrences;
  final List<PriceChangePoint> priceChanges;

  /// True when Stop is still possible.
  bool get isLive => endDate == null;
}

/// One category rule of X84.
final class RuleView {
  const RuleView({
    required this.id,
    required this.pattern,
    required this.matchType,
    required this.categoryName,
    required this.hitCount,
  });

  final String id;
  final String pattern;
  final String matchType;
  final String categoryName;
  final int hitCount;
}

/// The C03 rule draft.
final class RuleDraft {
  const RuleDraft({
    required this.pattern,
    required this.categoryId,
    this.matchType = 'merchantContains',
  });

  final String pattern;
  final String categoryId;
  final String matchType;
}

/// The C02 schedule draft.
final class ScheduleDraft {
  const ScheduleDraft({
    required this.name,
    required this.amountMinor,
    required this.currencyCode,
    required this.frequency,
    required this.startDate,
    required this.accountId,
  });

  final String name;
  final int amountMinor;
  final String currencyCode;
  final RepeatFrequency frequency;
  final LocalDate startDate;
  final String accountId;
}

/// One category choice for C03.
final class NamedOption {
  const NamedOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// The repeating and rule data port.
abstract interface class RepeatingGateway {
  Future<RepeatingView> loadRepeating();

  Future<RepeatingDetailView?> loadSchedule(String id);

  /// `StopSchedule`: ends generation from [lastDate]; history stays.
  Future<void> stopSchedule(
    RepeatingDetailView detail, {
    required LocalDate lastDate,
  });

  /// `SaveSchedule` for C02. It writes no payment.
  Future<void> saveSchedule(ScheduleDraft draft);

  Future<List<RuleView>> loadRules();

  /// Expense and income categories for C03 and X84.
  Future<List<NamedOption>> categoryOptions();

  /// `SaveRule`. Returns nothing; the caller reloads the list.
  Future<void> saveRule(RuleDraft draft);

  /// Accounts for C02.
  Future<List<NamedOption>> accountOptions();
}

/// Safe failure codes (no amount, name or id in the text).
enum RepeatingErrorCode {
  notWired,
  loadFailed,
  saveFailed,
  stopFailed,
  invalidDraft,
}

class RepeatingError implements Exception {
  const RepeatingError(this.code);

  final RepeatingErrorCode code;

  @override
  String toString() => 'RepeatingError(${code.name})';
}

/// The placeholder gateway before the vault is mounted.
final class UnavailableRepeatingGateway implements RepeatingGateway {
  const UnavailableRepeatingGateway();

  @override
  Future<RepeatingView> loadRepeating() async => const RepeatingView(
        items: <RepeatingItem>[],
        monthlyTotalMinor: 0,
        currencyCode: 'USD',
        monthlyCount: 0,
        yearlyCount: 0,
      );

  @override
  Future<RepeatingDetailView?> loadSchedule(String id) async => null;

  @override
  Future<void> stopSchedule(
    RepeatingDetailView detail, {
    required LocalDate lastDate,
  }) async =>
      throw const RepeatingError(RepeatingErrorCode.notWired);

  @override
  Future<void> saveSchedule(ScheduleDraft draft) async =>
      throw const RepeatingError(RepeatingErrorCode.notWired);

  @override
  Future<List<RuleView>> loadRules() async => const <RuleView>[];

  @override
  Future<List<NamedOption>> categoryOptions() async => const <NamedOption>[];

  @override
  Future<void> saveRule(RuleDraft draft) async =>
      throw const RepeatingError(RepeatingErrorCode.notWired);

  @override
  Future<List<NamedOption>> accountOptions() async => const <NamedOption>[];
}
