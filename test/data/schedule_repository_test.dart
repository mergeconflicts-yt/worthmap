// P16 (SPEC 8.9, 8.17; F09): schedules, rule edits, Stop and price changes.
//
// A rule edit freezes a reconciliation plan. A month-end change keeps the
// occurrence identity. A monthly-to-weekly change needs a review first.
// Stop keeps the schedule and its occurrences. A price change is a dated
// observation.

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
  var nowMs = 1700000000000;
  var operation = 0;
  var scheduleSeed = 0;
  var occurrenceSeed = 0;

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
    operation = 0;
    scheduleSeed = 0;
    occurrenceSeed = 0;
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
      commandType: 'schedule.save',
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

  ScheduleFields monthly({
    int day = 28,
    int amount = 180000,
    String? rrule,
    String start = '2026-01-28',
  }) =>
      ScheduleFields(
        name: 'Rent',
        kind: 'bill',
        accountId: _account,
        amountMinor: amount,
        currency: 'USD',
        startDate: start,
        rrule: rrule ?? 'FREQ=MONTHLY;BYMONTHDAY=$day',
      );

  test('a saved schedule writes no occurrence and no payment', () async {
    final id = _uuid('f', 1);
    await run(schedules.planCreate(scheduleId: id, fields: monthly()));

    final saved = await schedules.find(id);
    expect(saved, isNotNull);
    expect(saved!.revision, 1);
    final occurrences = await vault.database
        .customSelect('SELECT count(*) AS n FROM scheduled_occurrences')
        .getSingle();
    expect(occurrences.data['n'], 0);
    final payments = await vault.database
        .customSelect('SELECT count(*) AS n FROM transactions')
        .getSingle();
    expect(payments.data['n'], 0);
    final scheduleScope = await vault.database.customSelect(
      'SELECT r.revision FROM dependency_revisions r '
      'JOIN dependency_scopes s ON s.id = r.scope_id '
      'WHERE s.kind = ? AND s.scope_key = ?',
      variables: [const Variable('schedule'), Variable(id)],
    ).getSingle();
    expect(scheduleScope.data['revision'], greaterThanOrEqualTo(1));
  });

  test('a month-end rule change keeps the occurrence identity', () async {
    final id = _uuid('f', 2);
    await run(
      schedules.planCreate(
        scheduleId: id,
        fields: monthly(day: 28, start: '2026-01-01'),
      ),
    );
    await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-03-31'),
      ),
    );
    final before = await OccurrenceRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    ).listForSchedule(id);
    expect(before, hasLength(3));
    final march = before.firstWhere((row) => row.date.startsWith('2026-03'));

    final edit = await schedules.planEdit(
      scheduleId: id,
      expectedRevision: 1,
      fields: monthly(day: 27, start: '2026-01-01'),
    );
    expect(edit.needsReview, isFalse);
    await run(edit.plan);

    final after = await OccurrenceRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    ).listForSchedule(id);
    final kept =
        after.firstWhere((row) => row.occurrenceKey.contains('2026-03'));
    expect(kept.id, march.id);
    expect(kept.date, '2026-03-27');

    final locators = await vault.database.customSelect(
      'SELECT occurrence_id FROM occurrence_locators WHERE schedule_id = ? '
      'AND rule_revision = 2 AND nominal_slot = ?',
      variables: [Variable(id), const Variable('2026-03-27')],
    ).get();
    expect(locators.single.data['occurrence_id'], march.id);
  });

  test('a monthly-to-weekly change needs a review and keeps a mapped identity',
      () async {
    final id = _uuid('f', 3);
    await run(
      schedules.planCreate(
        scheduleId: id,
        fields: monthly(
          day: 2,
          start: '2026-03-02',
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=2',
        ),
      ),
    );
    await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-03-01'),
        LocalDate.parse('2026-03-31'),
      ),
    );
    final occurrenceRepo = OccurrenceRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    final before = await occurrenceRepo.listForSchedule(id);
    expect(before, hasLength(1));
    final monthlyId = before.single.id;

    final weekly = ScheduleFields(
      name: 'Rent',
      kind: 'bill',
      accountId: _account,
      amountMinor: 180000,
      currency: 'USD',
      startDate: '2026-03-02',
      rrule: 'FREQ=WEEKLY;BYDAY=MO;INTERVAL=1',
    );
    final review = await schedules.planEdit(
      scheduleId: id,
      expectedRevision: 1,
      fields: weekly,
    );
    expect(review.needsReview, isTrue);
    expect(review.reviewKeys, contains('M:2026-03#0'));

    final planned = await schedules.planEdit(
      scheduleId: id,
      expectedRevision: 1,
      fields: weekly,
      slotMap: <String, String>{'2026-03-02': monthlyId},
    );
    expect(planned.needsReview, isFalse);
    await run(planned.plan);

    final after = await occurrenceRepo.listForSchedule(id);
    final kept = after.firstWhere((row) => row.id == monthlyId);
    expect(kept.date, '2026-03-02');
  });

  test('Stop ends generation and keeps the history', () async {
    final id = _uuid('f', 4);
    await run(schedules.planCreate(scheduleId: id, fields: monthly()));
    await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-02-28'),
      ),
    );
    final stops = await schedules.planStop(
      scheduleId: id,
      expectedRevision: 1,
      lastDate: '2026-02-28',
    );
    await run(stops);

    final stopped = await schedules.find(id);
    expect(stopped, isNotNull);
    expect(stopped!.endDate, '2026-02-28');
    expect(stopped.revision, 2);

    final generated = await generator.generate(
      window: DateRange(
        LocalDate.parse('2026-03-01'),
        LocalDate.parse('2026-03-31'),
      ),
    );
    expect(generated.inserted, 0);
    final occurrences = await vault.database
        .customSelect('SELECT count(*) AS n FROM scheduled_occurrences')
        .getSingle();
    expect(occurrences.data['n'], 2);
  });

  test('a price change is a dated observation', () async {
    final id = _uuid('f', 5);
    await run(schedules.planCreate(scheduleId: id, fields: monthly()));
    final priceId = _uuid('1', 1);
    await run(
      schedules.planPriceChange(
        priceChangeId: priceId,
        scheduleId: id,
        date: '2026-02-28',
        oldMinor: 1549,
        newMinor: 1799,
        currency: 'USD',
      ),
    );
    final changes = await schedules.priceChanges(id);
    expect(changes, hasLength(1));
    expect(changes.single.oldMinor, 1549);
    expect(changes.single.newMinor, 1799);
    expect(changes.single.date, '2026-02-28');

    // A second identical price is a caller error; an observation is a change.
    await expectLater(
      schedules.planPriceChange(
        priceChangeId: _uuid('1', 2),
        scheduleId: id,
        date: '2026-03-28',
        oldMinor: 1799,
        newMinor: 1799,
        currency: 'USD',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('a one-off schedule has one stable occurrence', () async {
    final id = _uuid('f', 6);
    await run(
      schedules.planCreate(
        scheduleId: id,
        fields: ScheduleFields(
          name: 'Insurance',
          kind: 'oneOff',
          accountId: _account,
          amountMinor: 50000,
          currency: 'USD',
          startDate: '2026-04-10',
          isOneOff: true,
        ),
      ),
    );
    final window = DateRange(
      LocalDate.parse('2026-04-01'),
      LocalDate.parse('2026-04-30'),
    );
    final first = await generator.generate(window: window);
    final second = await generator.generate(window: window);
    expect(first.inserted, 1);
    expect(second.inserted, 0);
    expect(second.reused, 1);
    final occurrences = await OccurrenceRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    ).listForSchedule(id);
    expect(occurrences, hasLength(1));
    expect(occurrences.single.occurrenceKey, 'O:2026-04-10');
  });
}
