// P16 (SPEC 8.9, 8.17; DATABASE_DESIGN 4.3): schedules, rule edits, Stop and
// price-change facts.
//
// A saved schedule creates no payment (F09). A rule edit freezes an explicit
// reconciliation plan: every new nominal slot maps to one existing occurrence
// or a new identity, and an open occurrence that the plan does not map needs a
// review before the edit commits. Amount or date similarity is never proof of
// an unchanged slot.

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../../domain/periods/period_math.dart';
import '../../domain/periods/period_range.dart';
import '../db/app_database.dart';
import '../db/command_repository.dart';
import 'occurrences.dart';
import 'write_plan.dart';

/// One authored price-change observation (SPEC 8.9).
final class PriceChangeRow {
  const PriceChangeRow({
    required this.id,
    required this.scheduleId,
    required this.date,
    required this.oldMinor,
    required this.newMinor,
    required this.currency,
  });

  final String id;
  final String scheduleId;
  final String date;
  final int oldMinor;
  final int newMinor;
  final String currency;
}

/// The full editable fields of a schedule.
final class ScheduleFields {
  ScheduleFields({
    required this.name,
    required this.kind,
    required this.currency,
    this.accountId,
    this.amountMinor,
    this.amountState = 'known',
    required this.startDate,
    this.endDate,
    this.rrule,
    this.isOneOff = false,
    this.autoCreate = false,
  });

  final String name;
  final String kind;
  final String? accountId;
  final int? amountMinor;
  final String currency;
  final String amountState;
  final String startDate;
  final String? endDate;
  final String? rrule;
  final bool isOneOff;
  final bool autoCreate;

  /// Validates the field set and the rule text. It writes nothing.
  void validate() {
    if (name.trim().isEmpty || name.length > 256) {
      throw ArgumentError.value(name, 'name', 'Must be 1 to 256 characters');
    }
    const kinds = <String>{
      'bill',
      'subscription',
      'income',
      'investment',
      'premium',
      'emi',
      'transfer',
      'vest',
      'tax',
      'dividend',
      'oneOff',
    };
    if (!kinds.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', 'Unknown schedule kind');
    }
    final start = LocalDate.parse(startDate);
    final end = endDate == null ? null : LocalDate.parse(endDate!);
    if (end != null && end.compareTo(start) < 0) {
      throw ArgumentError('The end date must not be before the start date');
    }
    if (isOneOff && rrule != null) {
      throw ArgumentError('A one-off payment has no rule');
    }
    if (!isOneOff && rrule == null) {
      throw ArgumentError('A repeating payment needs a rule');
    }
    if (rrule != null) {
      RecurrenceRule.parse(rrule!);
    }
    if (amountState == 'missing' && amountMinor != null) {
      throw ArgumentError('A missing amount has no value');
    }
    if (amountState != 'missing' && amountMinor == null) {
      throw ArgumentError('A known or estimated amount needs a value');
    }
    if (amountMinor != null && amountMinor! < 0) {
      throw ArgumentError.value(
        amountMinor,
        'amountMinor',
        'Must be 0 or more',
      );
    }
    if (amountState != 'known' &&
        amountState != 'estimated' &&
        amountState != 'missing') {
      throw ArgumentError.value(amountState, 'amountState', 'Unknown state');
    }
  }
}

/// The outcome of a rule edit: the prepared plan and any slots that need a
/// review before the edit can commit.
final class ScheduleEditPlan {
  const ScheduleEditPlan({required this.plan, required this.reviewKeys});

  final WritePlan plan;

  /// The open occurrence keys that the plan does not map. Empty when the
  /// edit can commit.
  final List<String> reviewKeys;

  /// True when the caller must supply a reconciliation plan.
  bool get needsReview => reviewKeys.isNotEmpty;
}

/// Schedule reads and the `SaveSchedule` and `StopSchedule` writes.
final class ScheduleRepository {
  ScheduleRepository({
    required AppDatabase db,
    required DateTime Function() clockUtc,
    String Function()? newId,
  })  : _db = db,
        _clockUtc = clockUtc,
        _newId = newId;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;
  final String Function()? _newId;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  String _nextId() {
    final injected = _newId;
    if (injected != null) {
      return injected();
    }
    final random = Random.secure();
    final bytes = List<int>.generate(10, (_) => random.nextInt(256));
    return UuidV7.generate(
      unixMillis: _nowMs(),
      randomBytes: bytes,
    ).toString();
  }

  /// Live schedules by name.
  Future<List<ScheduleRow>> list() async {
    final rows = await _db
        .customSelect(
          'SELECT id, name, kind, account_id, amount_minor, currency, '
          'amount_state, start_date, end_date, rrule, is_one_off, auto_create, '
          'revision FROM schedules WHERE deleted_at IS NULL ORDER BY name, id',
        )
        .get();
    return <ScheduleRow>[
      for (final row in rows)
        ScheduleRow(
          id: row.data['id'] as String,
          name: row.data['name'] as String,
          kind: row.data['kind'] as String,
          accountId: row.data['account_id'] as String?,
          amountMinor: row.data['amount_minor'] as int?,
          currency: row.data['currency'] as String,
          amountState: row.data['amount_state'] as String,
          startDate: row.data['start_date'] as String,
          endDate: row.data['end_date'] as String?,
          rrule: row.data['rrule'] as String?,
          isOneOff: (row.data['is_one_off'] as int) == 1,
          autoCreate: (row.data['auto_create'] as int) == 1,
          revision: row.data['revision'] as int,
        ),
    ];
  }

  /// One live schedule, or null.
  Future<ScheduleRow?> find(String scheduleId) async {
    final row = await _db.customSelect(
      'SELECT id, name, kind, account_id, amount_minor, currency, '
      'amount_state, start_date, end_date, rrule, is_one_off, auto_create, '
      'revision FROM schedules WHERE id = ? AND deleted_at IS NULL',
      variables: [Variable(scheduleId)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return ScheduleRow(
      id: row.data['id'] as String,
      name: row.data['name'] as String,
      kind: row.data['kind'] as String,
      accountId: row.data['account_id'] as String?,
      amountMinor: row.data['amount_minor'] as int?,
      currency: row.data['currency'] as String,
      amountState: row.data['amount_state'] as String,
      startDate: row.data['start_date'] as String,
      endDate: row.data['end_date'] as String?,
      rrule: row.data['rrule'] as String?,
      isOneOff: (row.data['is_one_off'] as int) == 1,
      autoCreate: (row.data['auto_create'] as int) == 1,
      revision: row.data['revision'] as int,
    );
  }

  /// C02 / F09: creates a schedule. No occurrence and no payment is written.
  WritePlan planCreate({
    required String scheduleId,
    required ScheduleFields fields,
  }) {
    fields.validate();
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: scheduleId,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'name': fields.name,
            'kind': fields.kind,
            'amountMinor': fields.amountMinor,
            'currency': fields.currency,
            'startDate': fields.startDate,
            'rrule': fields.rrule,
            'isOneOff': fields.isOneOff,
            'autoCreate': fields.autoCreate,
          }),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'INSERT INTO schedules (id, created_at, updated_at, deleted_at, '
          'revision, name, kind, account_id, amount_minor, currency, '
          'amount_state, start_date, end_date, rrule, is_one_off, '
          'auto_create) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            scheduleId,
            now,
            now,
            fields.name,
            fields.kind,
            fields.accountId,
            fields.amountMinor,
            fields.currency,
            fields.amountState,
            fields.startDate,
            fields.endDate,
            fields.rrule,
            fields.isOneOff ? 1 : 0,
            fields.autoCreate ? 1 : 0,
          ],
        );
        await _bumpScheduleScope(scheduleId);
        await _markDirty(scheduleId, fields.startDate);
      },
    );
  }

  /// A rule edit and its frozen reconciliation plan.
  ///
  /// [slotMap] maps a new nominal slot (`YYYY-MM-DD`) to an existing
  /// occurrence identity. A slot without a map entry maps automatically only
  /// when its stable occurrence key already exists. An open occurrence that
  /// the plan does not map is a review key, unless [cancelUnmapped] is true.
  Future<ScheduleEditPlan> planEdit({
    required String scheduleId,
    required int expectedRevision,
    required ScheduleFields fields,
    Map<String, String>? slotMap,
    bool cancelUnmapped = false,
  }) async {
    fields.validate();
    final current = await find(scheduleId);
    if (current == null) {
      throw const ScheduleError(ScheduleErrorCode.unknownRecord);
    }
    if (current.revision != expectedRevision) {
      throw const ScheduleError(ScheduleErrorCode.invalidTransition);
    }
    final occurrences = OccurrenceRepository(
      db: _db,
      clockUtc: _clockUtc,
      newId: _newId,
    );
    final existing = await occurrences.listForSchedule(scheduleId);
    final decisions = await occurrences.currentDecisions(scheduleId);

    final newStart = LocalDate.parse(fields.startDate);
    final newEnd =
        fields.endDate == null ? null : LocalDate.parse(fields.endDate!);
    final window = _reconciliationWindow(newStart, existing);
    final rule = fields.isOneOff ? null : RecurrenceRule.parse(fields.rrule!);
    final slots = fields.isOneOff
        ? (newStart.compareTo(window.start) >= 0 &&
                newStart.compareTo(window.end) <= 0
            ? <LocalDate>[newStart]
            : <LocalDate>[])
        : rule!.slotsIn(window, start: newStart, end: newEnd);
    final slotKeys = <String, String>{
      for (final slot in slots)
        slot.toString():
            fields.isOneOff ? 'O:$slot' : rule!.stableKey(slot, newStart),
    };
    final byKey = <String, _ExistingOccurrence>{
      for (final row in existing)
        row.occurrenceKey: _ExistingOccurrence(
          id: row.id,
          key: row.occurrenceKey,
          date: row.date,
          amountMinor: row.amountMinor,
          amountState: row.amountState,
          decided: decisions.containsKey(row.id),
        ),
    };
    if (slotMap != null) {
      for (final key in slotMap.keys) {
        if (!slotKeys.containsKey(key)) {
          throw ArgumentError.value(key, 'slotMap', 'Not a proposed slot');
        }
      }
    }
    final resolved = <String, String>{};
    final usedIds = <String>{};
    for (final slot in slots) {
      final nominal = slot.toString();
      final explicit = slotMap?[nominal];
      if (explicit != null) {
        if (!existing.any((row) => row.id == explicit)) {
          throw const ScheduleError(ScheduleErrorCode.unknownRecord);
        }
        resolved[nominal] = explicit;
        usedIds.add(explicit);
        continue;
      }
      final match = byKey[slotKeys[nominal]];
      if (match != null) {
        resolved[nominal] = match.id;
        usedIds.add(match.id);
      }
    }
    final reviewKeys = <String>[];
    for (final row in existing) {
      if (usedIds.contains(row.id)) {
        continue;
      }
      final decided = decisions.containsKey(row.id);
      if (decided || cancelUnmapped) {
        continue;
      }
      reviewKeys.add(row.occurrenceKey);
    }
    if (reviewKeys.isNotEmpty) {
      return ScheduleEditPlan(
        plan: WritePlan(changes: const <ChangeLogEntry>[], apply: () async {}),
        reviewKeys: reviewKeys,
      );
    }

    final now = _nowMs();
    final changes = <ChangeLogEntry>[
      ChangeLogEntry(
        entityId: scheduleId,
        fromRevision: expectedRevision,
        toRevision: expectedRevision + 1,
        changeKind: 'edit',
        beforeJson: jsonEncode(<String, Object?>{
          'startDate': current.startDate,
          'rrule': current.rrule,
          'amountMinor': current.amountMinor,
        }),
        afterJson: jsonEncode(<String, Object?>{
          'startDate': fields.startDate,
          'rrule': fields.rrule,
          'amountMinor': fields.amountMinor,
        }),
        schemaVersion: 1,
      ),
    ];
    final statements = <Future<void> Function()>[
      () async {
        await _db.customStatement(
          'UPDATE schedules SET name = ?, kind = ?, account_id = ?, '
          'amount_minor = ?, currency = ?, amount_state = ?, start_date = ?, '
          'end_date = ?, rrule = ?, is_one_off = ?, auto_create = ?, '
          'updated_at = ?, revision = revision + 1 WHERE id = ?',
          [
            fields.name,
            fields.kind,
            fields.accountId,
            fields.amountMinor,
            fields.currency,
            fields.amountState,
            fields.startDate,
            fields.endDate,
            fields.rrule,
            fields.isOneOff ? 1 : 0,
            fields.autoCreate ? 1 : 0,
            now,
            scheduleId,
          ],
        );
      },
    ];

    for (final slot in slots) {
      final nominal = slot.toString();
      final occurrenceId = resolved[nominal] ?? _nextId();
      final isNew = resolved[nominal] == null;
      _ExistingOccurrence? existingRow;
      for (final row in existing) {
        if (row.id == occurrenceId) {
          existingRow = byKey[row.occurrenceKey];
          break;
        }
      }
      final decided = existingRow?.decided ?? false;
      statements.add(() async {
        if (isNew) {
          await _db.customStatement(
            'INSERT OR IGNORE INTO scheduled_occurrences (id, created_at, '
            'updated_at, deleted_at, revision, schedule_id, '
            'schedule_revision, occurrence_key, date, amount_minor, '
            'currency, amount_state, status) '
            "VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, ?, 'expected')",
            [
              occurrenceId,
              now,
              now,
              scheduleId,
              expectedRevision + 1,
              slotKeys[nominal],
              nominal,
              fields.amountMinor,
              fields.currency,
              fields.amountState,
            ],
          );
        } else if (!decided &&
            (existingRow!.date != nominal ||
                existingRow.amountMinor != fields.amountMinor ||
                existingRow.amountState != fields.amountState)) {
          await _db.customStatement(
            'UPDATE scheduled_occurrences SET date = ?, amount_minor = ?, '
            'amount_state = ?, schedule_revision = ?, updated_at = ?, '
            'revision = revision + 1 WHERE id = ?',
            [
              nominal,
              fields.amountMinor,
              fields.amountState,
              expectedRevision + 1,
              now,
              occurrenceId,
            ],
          );
        }
        await _db.customStatement(
          'INSERT OR IGNORE INTO occurrence_locators (schedule_id, '
          'rule_revision, generator_version, nominal_slot, occurrence_id) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            scheduleId,
            expectedRevision + 1,
            OccurrenceGenerator.generatorVersion,
            nominal,
            occurrenceId,
          ],
        );
      });
    }

    for (final row in existing) {
      if (usedIds.contains(row.id) ||
          !cancelUnmapped ||
          decisions.containsKey(row.id)) {
        continue;
      }
      final decisionId = _nextId();
      changes.add(
        ChangeLogEntry(
          entityId: decisionId,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'occurrenceId': row.id,
            'decisionType': 'cancelled',
          }),
          schemaVersion: 1,
        ),
      );
      statements.add(
        () => _cancelOccurrence(
          occurrenceId: row.id,
          decisionId: decisionId,
          now: now,
        ),
      );
    }

    statements.add(() async {
      await _bumpScheduleScope(scheduleId);
      await _markDirty(scheduleId, fields.startDate);
    });
    return ScheduleEditPlan(
      plan: WritePlan(
        changes: changes,
        apply: () async {
          for (final statement in statements) {
            await statement();
          }
        },
      ),
      reviewKeys: const <String>[],
    );
  }

  /// F09-C: Stop ends generation after [lastDate] and keeps the history.
  ///
  /// The schedule row, its occurrences, decisions and obligations stay.
  /// [lastDate] must be on or after the schedule start.
  Future<WritePlan> planStop({
    required String scheduleId,
    required int expectedRevision,
    required String lastDate,
  }) async {
    final current = await find(scheduleId);
    if (current == null) {
      throw const ScheduleError(ScheduleErrorCode.unknownRecord);
    }
    if (current.revision != expectedRevision) {
      throw const ScheduleError(ScheduleErrorCode.invalidTransition);
    }
    if (lastDate.compareTo(current.startDate) < 0) {
      throw ArgumentError.value(
        lastDate,
        'lastDate',
        'Must be on or after the start date',
      );
    }
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: scheduleId,
          fromRevision: expectedRevision,
          toRevision: expectedRevision + 1,
          changeKind: 'edit',
          beforeJson: jsonEncode(<String, Object?>{
            'endDate': current.endDate,
          }),
          afterJson: jsonEncode(<String, Object?>{'endDate': lastDate}),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'UPDATE schedules SET end_date = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ?',
          [lastDate, now, scheduleId],
        );
        await _bumpScheduleScope(scheduleId);
        await _markDirty(scheduleId, lastDate);
      },
    );
  }

  /// SPEC 8.9: a different actual amount is a dated observation.
  Future<WritePlan> planPriceChange({
    required String priceChangeId,
    required String scheduleId,
    required String date,
    required int oldMinor,
    required int newMinor,
    required String currency,
  }) async {
    LocalDate.parse(date);
    if (oldMinor < 0 || newMinor < 0) {
      throw ArgumentError('A price must be zero or more');
    }
    if (oldMinor == newMinor) {
      throw ArgumentError('A price change needs two different amounts');
    }
    final schedule = await find(scheduleId);
    if (schedule == null) {
      throw const ScheduleError(ScheduleErrorCode.unknownRecord);
    }
    if (schedule.currency != currency) {
      throw ArgumentError.value(currency, 'currency', 'Currency mismatch');
    }
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: priceChangeId,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'scheduleId': scheduleId,
            'date': date,
            'oldMinor': oldMinor,
            'newMinor': newMinor,
            'currency': currency,
          }),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'INSERT INTO price_changes (id, created_at, updated_at, '
          'deleted_at, revision, schedule_id, date, old_minor, new_minor, '
          'currency) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?)',
          [
            priceChangeId,
            now,
            now,
            scheduleId,
            date,
            oldMinor,
            newMinor,
            currency,
          ],
        );
        await _bumpScheduleScope(scheduleId);
        await _markDirty(scheduleId, date);
      },
    );
  }

  /// One schedule's price changes, newest first.
  Future<List<PriceChangeRow>> priceChanges(String scheduleId) async {
    final rows = await _db.customSelect(
      'SELECT id, schedule_id, date, old_minor, new_minor, currency '
      'FROM price_changes WHERE schedule_id = ? AND deleted_at IS NULL '
      'ORDER BY date DESC, id DESC',
      variables: [Variable(scheduleId)],
    ).get();
    return <PriceChangeRow>[
      for (final row in rows)
        PriceChangeRow(
          id: row.data['id'] as String,
          scheduleId: row.data['schedule_id'] as String,
          date: row.data['date'] as String,
          oldMinor: row.data['old_minor'] as int,
          newMinor: row.data['new_minor'] as int,
          currency: row.data['currency'] as String,
        ),
    ];
  }

  DateRange _reconciliationWindow(
    LocalDate newStart,
    List<OccurrenceRow> existing,
  ) {
    var start = newStart;
    var end = addMonths(newStart, 12);
    for (final row in existing) {
      final date = LocalDate.parse(row.date);
      if (date.compareTo(start) < 0) {
        start = date;
      }
      if (date.compareTo(end) > 0) {
        end = date;
      }
    }
    return DateRange(start, end);
  }

  Future<void> _cancelOccurrence({
    required String occurrenceId,
    required String decisionId,
    required int now,
  }) async {
    final intent = await _db.customSelect(
      'SELECT operation_id FROM operation_intents WHERE state = ? LIMIT 1',
      variables: [const Variable('running')],
    ).getSingleOrNull();
    if (intent == null) {
      throw StateError('No running operation for the cancellation');
    }
    final operationId = intent.data['operation_id'] as String;
    final current = await _db.customSelect(
      'SELECT obligation_id FROM current_occurrence_decisions '
      'WHERE occurrence_id = ?',
      variables: [Variable(occurrenceId)],
    ).getSingleOrNull();
    final obligationId = current?.data['obligation_id'] as String?;
    await _db.customStatement(
      'INSERT INTO occurrence_decisions (id, created_at, updated_at, '
      'deleted_at, revision, occurrence_id, operation_id, decision_type, '
      'account_id, effective_date, amount_minor, currency, amount_state, '
      'obligation_id, settlement_allocation_id, supersedes_decision_id) '
      "VALUES (?, ?, ?, NULL, 1, ?, ?, 'cancelled', NULL, NULL, NULL, NULL, "
      "'unchanged', ?, NULL, ?)",
      [decisionId, now, now, occurrenceId, operationId, obligationId, null],
    );
    await _db.customStatement(
      'INSERT INTO current_occurrence_decisions (occurrence_id, decision_id, '
      'selected_operation_id) VALUES (?, ?, ?) '
      'ON CONFLICT(occurrence_id) DO UPDATE SET decision_id = excluded.decision_id, '
      'selected_operation_id = excluded.selected_operation_id',
      [occurrenceId, decisionId, operationId],
    );
    if (obligationId != null) {
      final allocated = await _db.customSelect(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total '
        'FROM settlement_allocations WHERE obligation_id = ? '
        'AND deleted_at IS NULL',
        variables: [Variable(obligationId)],
      ).getSingle();
      if ((allocated.data['total'] as int) == 0) {
        await _db.customStatement(
          'UPDATE obligations SET status = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ? AND status = ?',
          ['cancelled', now, obligationId, 'open'],
        );
      }
    }
  }

  Future<void> _bumpScheduleScope(String scheduleId) async {
    await _db.customStatement(
      'INSERT INTO dependency_scopes (kind, scope_key) '
      'SELECT ?, ? WHERE NOT EXISTS (SELECT 1 FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      ['schedule', scheduleId, 'schedule', scheduleId],
    );
    await _db.customStatement(
      'INSERT INTO dependency_revisions (scope_id, revision) '
      'SELECT id, 1 FROM dependency_scopes WHERE kind = ? AND scope_key = ? '
      'AND NOT EXISTS (SELECT 1 FROM dependency_revisions '
      'WHERE scope_id = dependency_scopes.id)',
      ['schedule', scheduleId],
    );
    await _db.customStatement(
      'UPDATE dependency_revisions SET revision = revision + 1 '
      'WHERE scope_id = (SELECT id FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      ['schedule', scheduleId],
    );
  }

  Future<void> _markDirty(String scheduleId, String date) async {
    await _db.customStatement(
      'INSERT INTO dirty_ranges (scope_id, projection_kind, start_date, '
      'end_date, required_revision) '
      'SELECT s.id, ?, ?, NULL, r.revision FROM dependency_scopes s '
      'JOIN dependency_revisions r ON r.scope_id = s.id '
      'WHERE s.kind = ? AND s.scope_key = ? '
      'ON CONFLICT(scope_id, projection_kind) DO UPDATE SET '
      'start_date = MIN(dirty_ranges.start_date, excluded.start_date), '
      'required_revision = MAX(dirty_ranges.required_revision, '
      'excluded.required_revision)',
      ['metric.calendar', date, 'schedule', scheduleId],
    );
  }
}

final class _ExistingOccurrence {
  const _ExistingOccurrence({
    required this.id,
    required this.key,
    required this.date,
    required this.amountMinor,
    required this.amountState,
    required this.decided,
  });

  final String id;
  final String key;
  final String date;
  final int? amountMinor;
  final String amountState;
  final bool decided;
}
