// P28 (flow F09; SPEC 8.9, 9.3): the app composition for repeating payments
// and rules.
//
// Reads come from P16 schedules and occurrences and P12 categories and rules.
// The three writes are `SaveSchedule`, `StopSchedule` and `SaveRule`. A saved
// schedule writes no payment; Stop keeps history (F09-C).
library;

import '../core/dates.dart';
import '../data/db/command_repository.dart';
import '../data/repositories/accounts.dart';
import '../data/repositories/categories.dart';
import '../data/repositories/occurrences.dart';
import '../data/repositories/schedules.dart';
import '../data/repositories/write_plan.dart';
import '../domain/periods/period_math.dart';
import '../domain/periods/period_range.dart';
import '../features/spending/repeating_models.dart';

/// P16 + P12 behind the repeating feature port.
final class SqlRepeatingGateway implements RepeatingGateway {
  SqlRepeatingGateway({
    required this.schedules,
    required this.occurrences,
    required this.categories,
    required this.accounts,
    required this.commands,
    required this.today,
    required this.newOperationId,
    this.currencyCode = 'USD',
  });

  final ScheduleRepository schedules;
  final OccurrenceRepository occurrences;
  final CategoryRepository categories;
  final AccountRepository accounts;
  final CommandRepository commands;
  final LocalDate Function() today;
  final String Function() newOperationId;
  final String currencyCode;

  @override
  Future<RepeatingView> loadRepeating() async {
    final rows = await schedules.list();
    final items = <RepeatingItem>[];
    var monthlyTotal = 0;
    var monthlyCount = 0;
    var yearlyCount = 0;
    for (final row in rows) {
      final frequency = _frequencyOf(row.rrule, row.isOneOff);
      final history = await occurrences.listForSchedule(row.id);
      final next = _nextDate(row, frequency);
      final paid = _paidThisMonth(history);
      items.add(
        RepeatingItem(
          id: row.id,
          name: row.name,
          kind: row.kind,
          currencyCode: row.currency,
          revision: row.revision,
          amountState: row.amountState,
          amountMinor: row.amountMinor,
          nextDate: next,
          paidThisMonth: paid,
          frequency: frequency,
          // The account name is read for the detail screen.
        ),
      );
      final amount = row.amountMinor;
      if (amount != null) {
        monthlyTotal += _monthlyEquivalent(amount, frequency);
      }
      switch (frequency) {
        case RepeatFrequency.monthly:
          monthlyCount += 1;
        case RepeatFrequency.yearly:
          yearlyCount += 1;
        case RepeatFrequency.weekly:
          monthlyCount += 1;
      }
    }
    return RepeatingView(
      items: items,
      monthlyTotalMinor: monthlyTotal,
      currencyCode: currencyCode,
      monthlyCount: monthlyCount,
      yearlyCount: yearlyCount,
    );
  }

  @override
  Future<RepeatingDetailView?> loadSchedule(String id) async {
    final row = await schedules.find(id);
    if (row == null) {
      return null;
    }
    final frequency = _frequencyOf(row.rrule, row.isOneOff);
    final history = await occurrences.listForSchedule(id);
    final priceRows = await schedules.priceChanges(id);
    final accountName =
        row.accountId == null ? null : (await _accountNames())[row.accountId];
    final sorted = <OccurrenceRow>[...history]
      ..sort((a, b) => b.date.compareTo(a.date));
    return RepeatingDetailView(
      id: row.id,
      name: row.name,
      kind: row.kind,
      currencyCode: row.currency,
      revision: row.revision,
      amountState: row.amountState,
      startDate: LocalDate.parse(row.startDate),
      endDate: row.endDate == null ? null : LocalDate.parse(row.endDate!),
      frequency: frequency,
      amountMinor: row.amountMinor,
      nextDate: _nextDate(row, frequency),
      accountName: accountName,
      occurrences: <OccurrencePoint>[
        for (final occurrence in sorted.take(6))
          OccurrencePoint(
            date: LocalDate.parse(occurrence.date),
            amountMinor: occurrence.amountMinor,
            state: occurrence.amountState,
          ),
      ],
      priceChanges: <PriceChangePoint>[
        for (final change in priceRows)
          PriceChangePoint(
            date: LocalDate.parse(change.date),
            oldMinor: change.oldMinor,
            newMinor: change.newMinor,
          ),
      ],
    );
  }

  @override
  Future<void> stopSchedule(
    RepeatingDetailView detail, {
    required LocalDate lastDate,
  }) async {
    final plan = await schedules.planStop(
      scheduleId: detail.id,
      expectedRevision: detail.revision,
      lastDate: lastDate.toString(),
    );
    await _run(
      commandType: 'schedule.stop',
      formType: 'scheduleStop',
      plan: plan,
      resultJson: '{"schedule":"${detail.id}"}',
    );
  }

  @override
  Future<void> saveSchedule(ScheduleDraft draft) async {
    final fields = ScheduleFields(
      name: draft.name.trim(),
      kind: 'subscription',
      currency: draft.currencyCode,
      accountId: draft.accountId,
      amountMinor: draft.amountMinor,
      startDate: draft.startDate.toString(),
      rrule: _rrule(draft.frequency, draft.startDate),
      autoCreate: false,
    );
    final id = newOperationId();
    final plan = schedules.planCreate(scheduleId: id, fields: fields);
    await _run(
      commandType: 'schedule.create',
      formType: 'schedule',
      plan: plan,
      resultJson: '{"schedule":"$id"}',
    );
  }

  @override
  Future<List<RuleView>> loadRules() async {
    final rules = await categories.rules();
    final names = <String, String>{
      for (final row in await categoryOptions()) row.id: row.name,
    };
    return <RuleView>[
      for (final rule in rules)
        RuleView(
          id: rule.id,
          pattern: rule.pattern,
          matchType: rule.matchType,
          categoryName: names[rule.categoryId] ?? '',
          hitCount: rule.hitCount,
        ),
    ];
  }

  @override
  Future<List<NamedOption>> categoryOptions() async {
    final expense = await categories.list(kind: 'expense');
    final income = await categories.list(kind: 'income');
    return <NamedOption>[
      for (final row in <CategoryRow>[...expense, ...income])
        NamedOption(id: row.id, name: row.name),
    ];
  }

  @override
  Future<void> saveRule(RuleDraft draft) async {
    final pattern = draft.pattern.trim();
    if (pattern.isEmpty || draft.categoryId.isEmpty) {
      throw const RepeatingError(RepeatingErrorCode.invalidDraft);
    }
    final id = newOperationId();
    final plan = categories.planCreateRule(
      id: id,
      matchType: draft.matchType,
      pattern: pattern,
      categoryId: draft.categoryId,
      createdFrom: 'user',
    );
    await _run(
      commandType: 'categoryRule.create',
      formType: 'categoryRule',
      plan: plan,
      resultJson: '{"rule":"$id"}',
    );
  }

  @override
  Future<List<NamedOption>> accountOptions() async => <NamedOption>[
        for (final row in await accounts.list())
          NamedOption(id: row.id, name: row.name),
      ];

  Future<Map<String, String>> _accountNames() async => <String, String>{
        for (final row in await accounts.list()) row.id: row.name,
      };

  Future<void> _run({
    required String commandType,
    required String formType,
    required WritePlan plan,
    required String resultJson,
  }) async {
    final operationId = newOperationId();
    await commands.prepare(
      operationId: operationId,
      commandType: commandType,
      draftId: newOperationId(),
      formType: formType,
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    try {
      await commands.execute(
        operationId: operationId,
        changes: plan.changes,
        effects: plan.apply,
        resultJson: resultJson,
      );
    } on Object {
      final receipt = await commands.receiptOf(operationId);
      if (receipt == null) {
        throw const RepeatingError(RepeatingErrorCode.saveFailed);
      }
    }
  }

  RepeatFrequency _frequencyOf(String? rrule, bool oneOff) {
    if (rrule == null || oneOff) {
      return RepeatFrequency.monthly;
    }
    final rule = RecurrenceRule.parse(rrule);
    return switch (rule.family) {
      RecurrenceFamily.weekly => RepeatFrequency.weekly,
      RecurrenceFamily.yearly => RepeatFrequency.yearly,
      _ => RepeatFrequency.monthly,
    };
  }

  LocalDate? _nextDate(ScheduleRow row, RepeatFrequency frequency) {
    final start = LocalDate.parse(row.startDate);
    if (row.isOneOff) {
      return start;
    }
    final rule = RecurrenceRule.parse(row.rrule ?? 'FREQ=MONTHLY');
    final window = DateRange(today(), addMonths(today(), 24));
    final slots = rule.slotsIn(window, start: start);
    for (final slot in slots) {
      if (slot.compareTo(today()) >= 0) {
        return slot;
      }
    }
    return null;
  }

  bool _paidThisMonth(List<OccurrenceRow> history) {
    final month = today().month;
    final year = today().year;
    for (final occurrence in history) {
      final date = LocalDate.tryParse(occurrence.date);
      if (date != null &&
          date.year == year &&
          date.month == month &&
          occurrence.amountState == 'actual') {
        return true;
      }
    }
    return false;
  }

  int _monthlyEquivalent(int amount, RepeatFrequency frequency) =>
      switch (frequency) {
        RepeatFrequency.monthly => amount,
        RepeatFrequency.yearly => amount ~/ 12,
        RepeatFrequency.weekly => amount * 52 ~/ 12,
      };

  String _rrule(RepeatFrequency frequency, LocalDate start) =>
      switch (frequency) {
        RepeatFrequency.monthly => 'FREQ=MONTHLY;BYMONTHDAY=${start.day}',
        RepeatFrequency.weekly =>
          'FREQ=WEEKLY;BYDAY=${_weekdayToken(weekdayOf(start))}',
        RepeatFrequency.yearly =>
          'FREQ=YEARLY;BYMONTH=${start.month};BYMONTHDAY=${start.day}',
      };

  static String _weekdayToken(int iso) =>
      const <String>['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'][iso - 1];
}
