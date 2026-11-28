// Phase 4 (SCREENS X50): the Plan composition.
//
// Reads the retained Expected occurrences and writes nothing. The window is
// today to 45 days ahead, which covers the X50 reference range (1 Oct to
// 15 Nov) without inventing dates that have no occurrence.
library;

import '../core/dates.dart';
import '../data/repositories/occurrences.dart';
import '../domain/periods/period_math.dart';
import '../features/plan/plan_models.dart';

/// The occurrence repository behind [PlanGateway].
final class SqlPlanGateway implements PlanGateway {
  SqlPlanGateway({
    required this.occurrences,
    required this.today,
    this.currencyCode = 'USD',
    this.daysAhead = 45,
  });

  final OccurrenceRepository occurrences;
  final LocalDate Function() today;
  final String currencyCode;
  final int daysAhead;

  @override
  Future<PlanView> load() async {
    final date = today();
    final end = addDays(date, daysAhead);
    final rows = await occurrences.upcomingBetween(from: date, to: end);
    final events = <PlanEvent>[
      for (final row in rows)
        PlanEvent(
          id: row.id,
          date: LocalDate.tryParse(row.date) ?? date,
          name: row.name,
          amountMinor: row.amountMinor,
          currencyCode: row.currency,
          kind: _kind(row.kind),
        ),
    ];
    LocalDate? nextIncome;
    for (final event in events) {
      if (event.kind != PlanEventKind.income) {
        continue;
      }
      if (nextIncome == null || event.date.compareTo(nextIncome) < 0) {
        nextIncome = event.date;
      }
    }
    return PlanView(
      currencyCode: currencyCode,
      today: date,
      rangeStart: date,
      rangeEnd: end,
      events: events,
      nextIncomeDate: nextIncome,
    );
  }

  static PlanEventKind _kind(String kind) => switch (kind) {
        'income' => PlanEventKind.income,
        'investment' || 'investing' => PlanEventKind.investing,
        _ => PlanEventKind.spending,
      };
}
