import 'package:contour/core/dates.dart';
import 'package:contour/features/spending/repeating_models.dart';

/// In-memory repeating and rule reads for the P28 tests.
final class FakeRepeatingGateway implements RepeatingGateway {
  final List<RuleDraft> savedRules = <RuleDraft>[];
  final List<ScheduleDraft> savedSchedules = <ScheduleDraft>[];
  final List<String> stopped = <String>[];
  Object? loadFailure;
  Object? stopFailure;

  static final LocalDate today = LocalDate(2026, 11, 22);

  @override
  Future<RepeatingView> loadRepeating() async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return RepeatingView(
      items: <RepeatingItem>[
        RepeatingItem(
          id: 's1',
          name: 'Rent',
          kind: 'bill',
          currencyCode: 'USD',
          revision: 1,
          amountState: 'known',
          amountMinor: 180000,
          nextDate: LocalDate(2026, 11, 1),
          paidThisMonth: true,
        ),
        RepeatingItem(
          id: 's2',
          name: 'Netflix',
          kind: 'subscription',
          currencyCode: 'USD',
          revision: 2,
          amountState: 'estimated',
          amountMinor: 1799,
          nextDate: LocalDate(2026, 11, 18),
          frequency: RepeatFrequency.monthly,
        ),
        RepeatingItem(
          id: 's3',
          name: 'Car insurance',
          kind: 'insurance',
          currencyCode: 'USD',
          revision: 1,
          amountState: 'known',
          amountMinor: 78000,
          nextDate: LocalDate(2027, 2, 4),
          frequency: RepeatFrequency.yearly,
        ),
      ],
      monthlyTotalMinor: 188099,
      currencyCode: 'USD',
      monthlyCount: 2,
      yearlyCount: 1,
    );
  }

  @override
  Future<RepeatingDetailView?> loadSchedule(String id) async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    if (id != 's2') {
      return null;
    }
    return RepeatingDetailView(
      id: 's2',
      name: 'Netflix',
      kind: 'subscription',
      currencyCode: 'USD',
      revision: 2,
      amountState: 'estimated',
      startDate: LocalDate(2026, 4, 18),
      endDate: null,
      frequency: RepeatFrequency.monthly,
      amountMinor: 1799,
      nextDate: LocalDate(2026, 11, 18),
      accountName: 'Visa card',
      occurrences: <OccurrencePoint>[
        for (var month = 4; month <= 9; month += 1)
          OccurrencePoint(
            date: LocalDate(2026, month, 18),
            amountMinor: 1549,
            state: 'actual',
          ),
      ],
      priceChanges: <PriceChangePoint>[
        PriceChangePoint(
          date: LocalDate(2026, 10, 18),
          oldMinor: 1549,
          newMinor: 1799,
        ),
      ],
    );
  }

  @override
  Future<void> stopSchedule(
    RepeatingDetailView detail, {
    required LocalDate lastDate,
  }) async {
    final failure = stopFailure;
    if (failure != null) {
      throw failure;
    }
    stopped.add(detail.id);
  }

  @override
  Future<void> saveSchedule(ScheduleDraft draft) async {
    savedSchedules.add(draft);
  }

  @override
  Future<List<RuleView>> loadRules() async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return const <RuleView>[
      RuleView(
        id: 'r1',
        pattern: 'Whole Foods',
        matchType: 'merchantContains',
        categoryName: 'Groceries',
        hitCount: 12,
      ),
      RuleView(
        id: 'r2',
        pattern: 'Uber',
        matchType: 'merchantContains',
        categoryName: 'Transport',
        hitCount: 8,
      ),
    ];
  }

  @override
  Future<List<NamedOption>> categoryOptions() async => const <NamedOption>[
        NamedOption(id: 'c1', name: 'Groceries'),
        NamedOption(id: 'c2', name: 'Transport'),
        NamedOption(id: 'c3', name: 'Subscriptions'),
      ];

  @override
  Future<void> saveRule(RuleDraft draft) async {
    savedRules.add(draft);
  }

  @override
  Future<List<NamedOption>> accountOptions() async => const <NamedOption>[
        NamedOption(id: 'a1', name: 'Checking'),
        NamedOption(id: 'a2', name: 'Visa card'),
      ];
}
