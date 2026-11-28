// X50: in-memory Plan reads. It writes no database.
import 'package:contour/core/dates.dart';
import 'package:contour/features/plan/plan_models.dart';

/// Fixed synthetic occurrences for the X50 widget and golden tests.
final class FakePlanGateway implements PlanGateway {
  FakePlanGateway({this.fail = false});

  final bool fail;

  @override
  Future<PlanView> load() async {
    if (fail) {
      throw const PlanError(PlanErrorCode.loadFailed);
    }
    final today = LocalDate(2026, 11, 28);
    return PlanView(
      currencyCode: 'USD',
      today: today,
      rangeStart: today,
      rangeEnd: LocalDate(2027, 1, 12),
      events: <PlanEvent>[
        PlanEvent(
          id: 'e1',
          date: LocalDate(2026, 11, 30),
          name: 'Rent',
          amountMinor: 180000,
          currencyCode: 'USD',
          kind: PlanEventKind.spending,
        ),
        PlanEvent(
          id: 'e2',
          date: LocalDate(2026, 12, 1),
          name: 'Salary',
          amountMinor: 820000,
          currencyCode: 'USD',
          kind: PlanEventKind.income,
        ),
        PlanEvent(
          id: 'e3',
          date: LocalDate(2026, 12, 4),
          name: 'Netflix',
          amountMinor: 1799,
          currencyCode: 'USD',
          kind: PlanEventKind.spending,
        ),
        PlanEvent(
          id: 'e4',
          date: LocalDate(2026, 12, 6),
          name: 'VTI',
          amountMinor: 50000,
          currencyCode: 'USD',
          kind: PlanEventKind.investing,
        ),
        PlanEvent(
          id: 'e5',
          date: LocalDate(2026, 12, 20),
          name: 'Phone',
          amountMinor: 4500,
          currencyCode: 'USD',
          kind: PlanEventKind.spending,
        ),
      ],
      nextIncomeDate: LocalDate(2026, 12, 1),
    );
  }
}
