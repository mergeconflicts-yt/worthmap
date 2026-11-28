// X50 (SCREENS; SPEC 6.10): the Plan calendar contract.
//
// The reads are the retained Expected occurrences between today and the
// range end. A day with no occurrence has no entry; a missing amount stays
// Missing. The feature formats no money.
library;

import '../../core/dates.dart';

/// X50 legend and glyph groups.
enum PlanEventKind { income, investing, spending }

/// One occurrence on the calendar.
final class PlanEvent {
  const PlanEvent({
    required this.id,
    required this.date,
    required this.name,
    required this.amountMinor,
    required this.currencyCode,
    required this.kind,
  });

  final String id;
  final LocalDate date;
  final String name;

  /// Null is Missing (an Expected item without an amount).
  final int? amountMinor;
  final String currencyCode;
  final PlanEventKind kind;
}

/// One loaded Plan screen.
final class PlanView {
  const PlanView({
    required this.currencyCode,
    required this.today,
    required this.rangeStart,
    required this.rangeEnd,
    required this.events,
    required this.nextIncomeDate,
  });

  final String currencyCode;
  final LocalDate today;
  final LocalDate rangeStart;
  final LocalDate rangeEnd;

  /// Oldest first, then by name.
  final List<PlanEvent> events;

  /// The first income date in the range, or null when none is known.
  final LocalDate? nextIncomeDate;

  /// The events before the next income (X50 "Before next income").
  List<PlanEvent> get beforeIncome => nextIncomeDate == null
      ? events
      : <PlanEvent>[
          for (final event in events)
            if (event.date.compareTo(nextIncomeDate!) < 0) event,
        ];

  /// The income and the events after it.
  List<PlanEvent> get fromIncome => nextIncomeDate == null
      ? const <PlanEvent>[]
      : <PlanEvent>[
          for (final event in events)
            if (event.date.compareTo(nextIncomeDate!) >= 0) event,
        ];
}

/// The Plan data port. It writes nothing.
abstract interface class PlanGateway {
  Future<PlanView> load();
}

/// The app composition has not mounted a gateway.
final class UnavailablePlanGateway implements PlanGateway {
  const UnavailablePlanGateway();

  @override
  Future<PlanView> load() async =>
      throw const PlanError(PlanErrorCode.notWired);
}

/// Typed, safe failure codes (no amount or name in the text).
enum PlanErrorCode { notWired, loadFailed }

class PlanError implements Exception {
  const PlanError(this.code);

  final PlanErrorCode code;

  @override
  String toString() => 'PlanError($code)';
}
