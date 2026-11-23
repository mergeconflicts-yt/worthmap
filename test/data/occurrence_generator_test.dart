// P16 (SPEC 8.17; F09-A): bounded occurrence generation and decisions.
//
// Generation writes Expected proposals only, never a payment. A repeated run
// creates one occurrence per slot. The page bound is 500 rows. A decision is
// dated, selected and kept; a later decision supersedes it.

import 'dart:async';

import 'package:contour/core/dates.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/occurrences.dart';
import 'package:contour/data/repositories/schedules.dart';
import 'package:contour/data/repositories/write_plan.dart';
import 'package:contour/domain/periods/period_range.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _account = '00000000-0000-7000-8000-0000000000a1';

String _uuid(String prefix, int n) =>
    '00000000-0000-7000-8000-$prefix${n.toString().padLeft(11, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late ScheduleRepository schedules;
  late OccurrenceGenerator generator;
  late OccurrenceRepository occurrences;
  var nowMs = 1700000000000;
  var operation = 0;
  var scheduleSeed = 0;
  var occurrenceSeed = 0;
  var obligationSeed = 0;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newOperationId: () {
        operation += 1;
        return _uuid('d', operation);
      },
    );
    schedules = ScheduleRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newId: () {
        scheduleSeed += 1;
        return _uuid('c', scheduleSeed);
      },
    );
    generator = OccurrenceGenerator(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newId: () {
        occurrenceSeed += 1;
        return _uuid('e', occurrenceSeed);
      },
    );
    occurrences = OccurrenceRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newId: () {
        obligationSeed += 1;
        return _uuid('7', obligationSeed);
      },
    );
    operation = 0;
    scheduleSeed = 0;
    occurrenceSeed = 0;
    obligationSeed = 0;
    await vault.database.customStatement(
      "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
    );
    await vault.database.customStatement(
      'INSERT INTO accounts (id, created_at, updated_at, deleted_at, '
      'revision, name, type, currency, institution, is_liability, is_liquid, '
      'include_in_net_worth, archived) '
      "VALUES (?, ?, ?, NULL, 1, 'Checking', 'bank', 'USD', NULL, 0, 1, 1, 0)",
      [_account, nowMs, nowMs],
    );
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<void> run(FutureOr<WritePlan> pending) async {
    final plan = await pending;
    final op = _uuid('a', operation);
    await commands.prepare(
      operationId: op,
      commandType: 'schedule.command',
      draftId: _uuid('b', operation),
      formType: 'schedule',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    await commands.execute(
      operationId: op,
      changes: plan.changes,
      effects: plan.apply,
      resultJson: '{}',
    );
    operation += 1;
  }

  Future<String> createSchedule({
    required String rrule,
    String start = '2026-01-01',
    String? end,
    int amount = 180000,
    bool oneOff = false,
  }) async {
    final id = _uuid('f', scheduleSeed + 1);
    await run(
      schedules.planCreate(
        scheduleId: id,
        fields: ScheduleFields(
          name: 'Rent',
          kind: oneOff ? 'oneOff' : 'bill',
          accountId: _account,
          amountMinor: amount,
          currency: 'USD',
          startDate: start,
          endDate: end,
          rrule: rrule,
          isOneOff: oneOff,
        ),
      ),
    );
    return id;
  }

  Future<int> count(String table) async => (await vault.database
          .customSelect('SELECT count(*) AS n FROM $table')
          .getSingle())
      .data['n'] as int;

  test('generation writes Expected proposals and never a payment', () async {
    final id = await createSchedule(rrule: 'FREQ=MONTHLY;BYMONTHDAY=1');
    final result = await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-03-31'),
      ),
    );
    expect(result.inserted, 3);
    expect(result.pages, 1);
    expect(await count('transactions'), 0);
    expect(await count('obligations'), 0);
    expect(await count('settlement_allocations'), 0);
    expect(await count('change_log'), 1);
    final statuses = await vault.database.customSelect(
      'SELECT status FROM scheduled_occurrences WHERE schedule_id = ?',
      variables: [Variable(id)],
    ).get();
    expect(statuses, hasLength(3));
    expect(statuses.map((row) => row.data['status']).toSet(), <String>{
      'expected',
    });
  });

  test('a repeated run creates one occurrence per slot (F09-A)', () async {
    final id = await createSchedule(rrule: 'FREQ=MONTHLY;BYMONTHDAY=1');
    final window = DateRange(
      LocalDate.parse('2026-01-01'),
      LocalDate.parse('2026-12-31'),
    );
    final first = await generator.generate(window: window);
    final second = await generator.generate(window: window);
    expect(first.inserted, 12);
    expect(second.inserted, 0);
    expect(second.reused, 12);
    final rows = await occurrences.listForSchedule(id);
    expect(rows, hasLength(12));
    expect(rows.map((row) => row.occurrenceKey).toSet(), hasLength(12));
  });

  test('a large window pages at 500 rows', () async {
    await createSchedule(
      rrule: 'FREQ=MONTHLY;BYMONTHDAY=1',
      start: '2000-01-01',
      end: '2050-12-31',
    );
    final result = await generator.generate(
      window: DateRange(
        LocalDate.parse('2000-01-01'),
        LocalDate.parse('2050-12-31'),
      ),
      rowsPerPage: 500,
    );
    expect(result.inserted, 612);
    expect(result.pages, 2);
    expect(await count('scheduled_occurrences'), 612);
  });

  test('a monthly day 31 skips a month without that day', () async {
    final id = await createSchedule(
      rrule: 'FREQ=MONTHLY;BYMONTHDAY=31',
      start: '2026-01-31',
    );
    final result = await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-03-31'),
      ),
    );
    expect(result.inserted, 2);
    final rows = await occurrences.listForSchedule(id);
    expect(rows.map((row) => row.date).toList(), <String>[
      '2026-01-31',
      '2026-03-31',
    ]);
  });

  test('a weekly rule emits one slot per selected weekday', () async {
    final id = await createSchedule(
      rrule: 'FREQ=WEEKLY;BYDAY=MO,FR',
      start: '2026-01-01',
    );
    await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-01-11'),
      ),
    );
    final rows = await occurrences.listForSchedule(id);
    expect(rows.map((row) => row.date).toList(), <String>[
      '2026-01-02',
      '2026-01-05',
      '2026-01-09',
    ]);
  });

  test('a skipped decision is selected and keeps the identity', () async {
    final id = await createSchedule(rrule: 'FREQ=MONTHLY;BYMONTHDAY=1');
    await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-01-31'),
      ),
    );
    final occurrence = (await occurrences.listForSchedule(id)).single;
    final firstDecision = _uuid('8', 1);
    await run(
      occurrences.planDecide(
        decisionId: firstDecision,
        occurrenceId: occurrence.id,
        decisionType: 'skipped',
      ),
    );
    final selected = await occurrences.currentDecisions(id);
    expect(selected[occurrence.id]!.decisionType, 'skipped');
    expect(selected[occurrence.id]!.decisionId, firstDecision);

    final secondDecision = _uuid('8', 2);
    await run(
      occurrences.planDecide(
        decisionId: secondDecision,
        occurrenceId: occurrence.id,
        decisionType: 'skipped',
        supersedesDecisionId: firstDecision,
      ),
    );
    final again = await occurrences.currentDecisions(id);
    expect(again[occurrence.id]!.decisionId, secondDecision);
    final kept = await occurrences.listForSchedule(id);
    expect(kept.single.id, occurrence.id);
    final decisions = await vault.database.customSelect(
      'SELECT count(*) AS n FROM occurrence_decisions '
      'WHERE occurrence_id = ?',
      variables: [Variable(occurrence.id)],
    ).getSingle();
    expect(decisions.data['n'], 2);
  });

  test('an accepted decision creates and links an obligation', () async {
    final id = await createSchedule(rrule: 'FREQ=MONTHLY;BYMONTHDAY=1');
    await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-01-31'),
      ),
    );
    final occurrence = (await occurrences.listForSchedule(id)).single;
    final decisionId = _uuid('8', 3);
    final obligationId = _uuid('9', 1);
    await run(
      occurrences.planDecide(
        decisionId: decisionId,
        occurrenceId: occurrence.id,
        decisionType: 'accepted',
        effectiveDate: occurrence.date,
        amountMinor: 180000,
        currency: 'USD',
        accountId: _account,
        newObligationId: obligationId,
      ),
    );
    final selected = await occurrences.currentDecisions(id);
    expect(selected[occurrence.id]!.decisionType, 'accepted');
    expect(selected[occurrence.id]!.obligationId, obligationId);
    final obligation = await vault.database.customSelect(
      'SELECT amount_minor, currency, status FROM obligations WHERE id = ?',
      variables: [Variable(obligationId)],
    ).getSingle();
    expect(obligation.data['amount_minor'], 180000);
    expect(obligation.data['currency'], 'USD');
    expect(obligation.data['status'], 'open');
  });

  test('a decided occurrence is not rewritten by a later schedule edit',
      () async {
    final id = await createSchedule(
      rrule: 'FREQ=MONTHLY;BYMONTHDAY=1',
      amount: 100000,
    );
    await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-01-31'),
      ),
    );
    final occurrence = (await occurrences.listForSchedule(id)).single;
    await run(
      occurrences.planDecide(
        decisionId: _uuid('8', 4),
        occurrenceId: occurrence.id,
        decisionType: 'skipped',
      ),
    );
    final edit = await schedules.planEdit(
      scheduleId: id,
      expectedRevision: 1,
      fields: ScheduleFields(
        name: 'Rent',
        kind: 'bill',
        accountId: _account,
        amountMinor: 200000,
        currency: 'USD',
        startDate: '2026-01-01',
        rrule: 'FREQ=MONTHLY;BYMONTHDAY=1',
      ),
    );
    await run(edit.plan);
    await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-01-31'),
      ),
    );
    final after = (await occurrences.listForSchedule(id))
        .firstWhere((row) => row.id == occurrence.id);
    expect(after.id, occurrence.id);
    expect(after.amountMinor, 100000);
  });
}
