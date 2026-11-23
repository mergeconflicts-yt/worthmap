// P16 (SPEC 8.9, 8.17; DATABASE_DESIGN 4.3; SYSTEM_DESIGN 5.3): repeating
// occurrences, occurrence decisions and the rule-edit reconciliation.
//
// Identity is `(schedule_id, occurrence_key)`. The key names the nominal
// occurrence independent of the rule revision: a monthly rule keys by its
// calendar month, a weekly rule by its Monday, a yearly rule by its year. The
// append-only `occurrence_locators` map the exact nominal slot of the current
// rule revision to that stable occurrence.
//
// Generation writes Expected proposals only. It never writes a payment, an
// obligation, a settlement or a ChangeLog entry. A repeated run reuses the
// locator and creates no second proposal (F09-A).

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../../domain/periods/period_math.dart';
import '../../domain/periods/period_range.dart';
import '../db/app_database.dart';
import '../db/command_repository.dart';
import 'write_plan.dart';

/// The recurrence family of a rule.
enum RecurrenceFamily { daily, weekly, monthly, yearly }

/// Safe schedule failure codes (no personal data, AGENTS 2.6).
enum ScheduleErrorCode {
  /// A rule edit changes the recurrence family and needs a review plan.
  ruleEditNeedsReview,

  /// A decision would exceed the unpaid obligation.
  overAllocation,

  /// A decision transitions to a state the current decision does not allow.
  invalidTransition,

  /// A referenced record does not exist in this vault.
  unknownRecord,
}

class ScheduleError implements Exception {
  const ScheduleError(this.code, {this.remainingMinor});

  final ScheduleErrorCode code;

  /// The unpaid amount in minor units, when the error is an over-allocation.
  final int? remainingMinor;

  @override
  String toString() => 'ScheduleError(${code.name}'
      '${remainingMinor == null ? '' : ', $remainingMinor remaining'})';
}

/// One parsed iCalendar RRULE (the subset repeating payments use).
///
/// Supported parts: `FREQ` (DAILY, WEEKLY, MONTHLY, YEARLY), `INTERVAL`,
/// `COUNT`, `UNTIL`, `BYDAY`, `BYMONTHDAY`, `BYMONTH` and `WKST=MO`. An
/// unknown part is a caller error and fails closed.
final class RecurrenceRule {
  RecurrenceRule._({
    required this.family,
    required this.interval,
    required this.byMonthDay,
    required this.byDay,
    required this.byMonth,
    required this.count,
    required this.until,
  });

  /// Parses `[RRULE:]FREQ=...;INTERVAL=...`.
  factory RecurrenceRule.parse(String source) {
    var text = source.trim();
    if (text.toUpperCase().startsWith('RRULE:')) {
      text = text.substring(6);
    }
    if (text.isEmpty) {
      throw ArgumentError.value(source, 'source', 'Must not be empty');
    }
    RecurrenceFamily? family;
    var interval = 1;
    int? count;
    LocalDate? until;
    final byMonthDay = <int>[];
    final byDay = <int>[];
    final byMonth = <int>[];
    for (final part in text.split(';')) {
      if (part.isEmpty) {
        continue;
      }
      final split = part.indexOf('=');
      if (split < 1) {
        throw ArgumentError.value(source, 'source', 'Malformed rule part');
      }
      final key = part.substring(0, split).toUpperCase();
      final value = part.substring(split + 1);
      switch (key) {
        case 'FREQ':
          family = switch (value.toUpperCase()) {
            'DAILY' => RecurrenceFamily.daily,
            'WEEKLY' => RecurrenceFamily.weekly,
            'MONTHLY' => RecurrenceFamily.monthly,
            'YEARLY' => RecurrenceFamily.yearly,
            _ =>
              throw ArgumentError.value(source, 'source', 'Unsupported FREQ'),
          };
        case 'INTERVAL':
          interval = int.parse(value);
          if (interval < 1) {
            throw ArgumentError.value(source, 'source', 'INTERVAL must be 1+');
          }
        case 'COUNT':
          count = int.parse(value);
          if (count < 1) {
            throw ArgumentError.value(source, 'source', 'COUNT must be 1+');
          }
        case 'UNTIL':
          until = LocalDate.parse(value.substring(0, 10));
        case 'BYDAY':
          for (final day in value.split(',')) {
            byDay.add(_weekday(day));
          }
        case 'BYMONTHDAY':
          for (final day in value.split(',')) {
            byMonthDay.add(int.parse(day));
          }
        case 'BYMONTH':
          for (final month in value.split(',')) {
            byMonth.add(int.parse(month));
          }
        case 'WKST':
          if (value.toUpperCase() != 'MO') {
            throw ArgumentError.value(source, 'source', 'Only WKST=MO');
          }
        default:
          throw ArgumentError.value(source, 'source', 'Unsupported rule part');
      }
    }
    if (family == null) {
      throw ArgumentError.value(source, 'source', 'FREQ is required');
    }
    return RecurrenceRule._(
      family: family,
      interval: interval,
      byMonthDay: byMonthDay,
      byDay: byDay,
      byMonth: byMonth,
      count: count,
      until: until,
    );
  }

  /// The recurrence family.
  final RecurrenceFamily family;

  /// The interval between periods.
  final int interval;

  /// Days of the month (monthly and yearly rules).
  final List<int> byMonthDay;

  /// ISO weekdays, Monday 1 to Sunday 7 (weekly rules).
  final List<int> byDay;

  /// Months, 1 to 12 (yearly rules).
  final List<int> byMonth;

  /// The maximum number of occurrences from the rule start.
  final int? count;

  /// The last date, inclusive.
  final LocalDate? until;

  /// The stable occurrence key of a slot (independent of a rule revision).
  ///
  /// The key uses the nominal slot position in its period, not its exact
  /// date. A single-day monthly rule therefore keeps `M:2026-03#0` when its
  /// day changes from 31 to 28; a two-day rule keeps one identity per
  /// position. [start] supplies the rule's default day or weekday.
  String stableKey(LocalDate slot, LocalDate start) {
    final index = _slotIndex(slot, start);
    return switch (family) {
      RecurrenceFamily.monthly => 'M:${slot.year.toString().padLeft(4, '0')}-'
          '${slot.month.toString().padLeft(2, '0')}#$index',
      RecurrenceFamily.weekly => 'W:${_mondayOf(slot)}#$index',
      RecurrenceFamily.yearly =>
        'Y:${slot.year.toString().padLeft(4, '0')}#$index',
      RecurrenceFamily.daily => 'D:$slot',
    };
  }

  int _slotIndex(LocalDate slot, LocalDate start) {
    switch (family) {
      case RecurrenceFamily.monthly:
        final days = (byMonthDay.isEmpty ? <int>[start.day] : byMonthDay)
            .where((day) => day >= 1 && day <= 31)
            .toSet()
            .toList()
          ..sort();
        final lastDay = LocalDate.daysInMonth(slot.year, slot.month);
        final valid = days.where((day) => day <= lastDay).toList();
        final index = valid.indexOf(slot.day);
        return index < 0 ? 0 : index;
      case RecurrenceFamily.weekly:
        final days = (byDay.isEmpty ? <int>[_weekdayOf(start)] : byDay)
            .toSet()
            .toList()
          ..sort();
        final index = days.indexOf(_weekdayOf(slot));
        return index < 0 ? 0 : index;
      case RecurrenceFamily.yearly:
        final months = (byMonth.isEmpty ? <int>[start.month] : byMonth)
            .toSet()
            .toList()
          ..sort();
        final days = (byMonthDay.isEmpty ? <int>[start.day] : byMonthDay)
            .toSet()
            .toList()
          ..sort();
        var index = 0;
        for (final month in months) {
          final lastDay = LocalDate.daysInMonth(slot.year, month);
          for (final day in days) {
            if (day > lastDay) {
              continue;
            }
            if (month == slot.month && day == slot.day) {
              return index;
            }
            index += 1;
          }
        }
        return 0;
      case RecurrenceFamily.daily:
        return 0;
    }
  }

  /// The nominal slot text stored in `occurrence_locators`.
  String nominalSlot(LocalDate slot) => slot.toString();

  /// The slots inside [window], from [start], up to [end].
  ///
  /// COUNT counts every occurrence from [start], including the ones before
  /// the window. A month without a `BYMONTHDAY` day is skipped (RFC 5545).
  List<LocalDate> slotsIn(
    DateRange window, {
    required LocalDate start,
    LocalDate? end,
  }) {
    final limit =
        end == null || end.compareTo(window.end) > 0 ? window.end : end;
    final slots = <LocalDate>[];
    var emitted = 0;
    var candidates = 0;
    void emit(LocalDate date) {
      candidates += 1;
      if (candidates > 100000) {
        throw ArgumentError('The rule has too many slots');
      }
      if (until != null && date.compareTo(until!) > 0) {
        return;
      }
      if (count != null && emitted >= count!) {
        return;
      }
      emitted += 1;
      if (date.compareTo(start) < 0 || date.compareTo(limit) > 0) {
        return;
      }
      slots.add(date);
    }

    switch (family) {
      case RecurrenceFamily.daily:
        var date = start;
        while (date.compareTo(limit) <= 0) {
          if (until != null && date.compareTo(until!) > 0) {
            break;
          }
          if (count != null && emitted >= count!) {
            break;
          }
          emit(date);
          date = addDays(date, interval);
        }
      case RecurrenceFamily.weekly:
        final days = byDay.isEmpty ? <int>[_weekdayOf(start)] : byDay;
        days.sort();
        var weekStart = _mondayOf(start);
        while (weekStart.compareTo(limit) <= 0) {
          for (final day in days) {
            if (count != null && emitted >= count!) {
              break;
            }
            final date = addDays(weekStart, day - 1);
            if (date.compareTo(limit) > 0) {
              continue;
            }
            if (date.compareTo(start) < 0) {
              continue;
            }
            emit(date);
          }
          if (until != null && weekStart.compareTo(until!) > 0) {
            break;
          }
          weekStart = addDays(weekStart, 7 * interval);
        }
      case RecurrenceFamily.monthly:
        final days = byMonthDay.isEmpty ? <int>[start.day] : byMonthDay;
        days.sort();
        var month = LocalDate(start.year, start.month, 1);
        while (month.compareTo(limit) <= 0) {
          final lastDay = LocalDate.daysInMonth(month.year, month.month);
          for (final day in days) {
            if (count != null && emitted >= count!) {
              break;
            }
            if (day < 1 || day > lastDay) {
              continue;
            }
            final date = LocalDate(month.year, month.month, day);
            if (date.compareTo(start) < 0) {
              continue;
            }
            if (date.compareTo(limit) > 0) {
              continue;
            }
            emit(date);
          }
          month = addMonths(month, interval);
        }
      case RecurrenceFamily.yearly:
        final months = byMonth.isEmpty ? <int>[start.month] : byMonth;
        final days = byMonthDay.isEmpty ? <int>[start.day] : byMonthDay;
        months.sort();
        days.sort();
        var year = start.year;
        while (year <= limit.year) {
          for (final month in months) {
            final lastDay = LocalDate.daysInMonth(year, month);
            for (final day in days) {
              if (count != null && emitted >= count!) {
                break;
              }
              if (day < 1 || day > lastDay) {
                continue;
              }
              final date = LocalDate(year, month, day);
              if (date.compareTo(start) < 0) {
                continue;
              }
              if (date.compareTo(limit) > 0) {
                continue;
              }
              emit(date);
            }
          }
          year += interval;
        }
    }
    slots.sort();
    return slots;
  }

  static int _weekday(String source) {
    return switch (source.toUpperCase()) {
      'MO' => 1,
      'TU' => 2,
      'WE' => 3,
      'TH' => 4,
      'FR' => 5,
      'SA' => 6,
      'SU' => 7,
      _ => throw ArgumentError.value(source, 'source', 'Unsupported BYDAY'),
    };
  }

  static int _weekdayOf(LocalDate date) =>
      DateTime.utc(date.year, date.month, date.day).weekday;

  static LocalDate _mondayOf(LocalDate date) =>
      addDays(date, -(_weekdayOf(date) - 1));
}

/// One schedule row.
final class ScheduleRow {
  const ScheduleRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.accountId,
    required this.amountMinor,
    required this.currency,
    required this.amountState,
    required this.startDate,
    required this.endDate,
    required this.rrule,
    required this.isOneOff,
    required this.autoCreate,
    required this.revision,
  });

  final String id;
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
  final int revision;
}

/// One generation result.
final class GenerationResult {
  const GenerationResult({
    required this.pages,
    required this.inserted,
    required this.updated,
    required this.reused,
  });

  final int pages;
  final int inserted;
  final int updated;
  final int reused;
}

/// The bounded occurrence generator (DATABASE_DESIGN 4.3).
final class OccurrenceGenerator {
  OccurrenceGenerator({
    required AppDatabase db,
    required DateTime Function() clockUtc,
    String Function()? newId,
  })  : _db = db,
        _clockUtc = clockUtc,
        _newId = newId;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;
  final String Function()? _newId;

  /// The generator codec version stored in each locator.
  static const int generatorVersion = 1;

  /// The largest page of one generation transaction.
  static const int maxRowsPerPage = 500;

  /// The largest page of one generation transaction, in bytes.
  static const int maxBytesPerPage = 1024 * 1024;

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

  /// Generates Expected proposals for every live schedule in [window].
  ///
  /// Writes at most [maxRowsPerPage] rows and [maxBytesPerPage] bytes per
  /// transaction. Returns the page count and the row counts. It never writes
  /// a payment, an obligation, a settlement or a ChangeLog entry.
  Future<GenerationResult> generate({
    required DateRange window,
    int rowsPerPage = maxRowsPerPage,
  }) async {
    if (rowsPerPage < 1 || rowsPerPage > maxRowsPerPage) {
      throw ArgumentError.value(
        rowsPerPage,
        'rowsPerPage',
        'Must be 1 to $maxRowsPerPage',
      );
    }
    var pages = 0;
    var inserted = 0;
    var updated = 0;
    var reused = 0;
    final page = <_PreparedOccurrence>[];
    var pageBytes = 0;

    Future<void> flush() async {
      if (page.isEmpty) {
        return;
      }
      final snapshot = <_PreparedOccurrence>[...page];
      page.clear();
      pageBytes = 0;
      await _db.transaction(() async {
        for (final row in snapshot) {
          if (row.update) {
            await _db.customStatement(
              'UPDATE scheduled_occurrences SET date = ?, amount_minor = ?, '
              'amount_state = ?, schedule_revision = ?, updated_at = ?, '
              'revision = revision + 1 WHERE id = ?',
              [
                row.date,
                row.amountMinor,
                row.amountState,
                row.scheduleRevision,
                row.updatedAt,
                row.occurrenceId,
              ],
            );
          } else {
            final existing = await _db.customSelect(
              'SELECT id FROM scheduled_occurrences WHERE schedule_id = ? '
              'AND occurrence_key = ?',
              variables: [
                Variable(row.scheduleId),
                Variable(row.occurrenceKey),
              ],
            ).getSingleOrNull();
            if (existing == null) {
              await _db.customStatement(
                'INSERT INTO scheduled_occurrences (id, created_at, '
                'updated_at, deleted_at, revision, schedule_id, '
                'schedule_revision, occurrence_key, date, amount_minor, '
                'currency, amount_state, status) '
                "VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, ?, 'expected')",
                [
                  row.occurrenceId,
                  row.updatedAt,
                  row.updatedAt,
                  row.scheduleId,
                  row.scheduleRevision,
                  row.occurrenceKey,
                  row.date,
                  row.amountMinor,
                  row.currency,
                  row.amountState,
                ],
              );
            } else {
              row.occurrenceId = existing.data['id'] as String;
            }
          }
          await _db.customStatement(
            'INSERT OR IGNORE INTO occurrence_locators (schedule_id, '
            'rule_revision, generator_version, nominal_slot, occurrence_id) '
            'VALUES (?, ?, ?, ?, ?)',
            [
              row.scheduleId,
              row.scheduleRevision,
              generatorVersion,
              row.nominalSlot,
              row.occurrenceId,
            ],
          );
        }
      });
      pages += 1;
    }

    var lastId = '';
    while (true) {
      final rows = await _db.customSelect(
        'SELECT id, name, kind, account_id, amount_minor, currency, '
        'amount_state, start_date, end_date, rrule, is_one_off, auto_create, '
        'revision FROM schedules WHERE deleted_at IS NULL AND id > ? '
        'ORDER BY id LIMIT ?',
        variables: [Variable(lastId), const Variable(100)],
      ).get();
      if (rows.isEmpty) {
        break;
      }
      for (final row in rows) {
        final schedule = _scheduleFromRow(row);
        lastId = schedule.id;
        if (schedule.startDate.compareTo(window.end.toString()) > 0) {
          continue;
        }
        final end = schedule.endDate;
        if (end != null && end.compareTo(window.start.toString()) < 0) {
          continue;
        }
        final slots = _slotsFor(schedule, window);
        final rule = schedule.rrule == null
            ? null
            : RecurrenceRule.parse(schedule.rrule!);
        for (final slot in slots) {
          final nominal = slot.toString();
          final located = await _db.customSelect(
            'SELECT occurrence_id FROM occurrence_locators WHERE '
            'schedule_id = ? AND rule_revision = ? AND generator_version = ? '
            'AND nominal_slot = ?',
            variables: [
              Variable(schedule.id),
              Variable(schedule.revision),
              const Variable(generatorVersion),
              Variable(nominal),
            ],
          ).getSingleOrNull();
          if (located != null) {
            reused += 1;
            continue;
          }
          final key = schedule.isOneOff
              ? 'O:$slot'
              : rule!.stableKey(slot, LocalDate.parse(schedule.startDate));
          final existing = await _db.customSelect(
            'SELECT id, date, amount_minor, amount_state, revision '
            'FROM scheduled_occurrences WHERE schedule_id = ? '
            'AND occurrence_key = ? AND deleted_at IS NULL',
            variables: [Variable(schedule.id), Variable(key)],
          ).getSingleOrNull();
          if (existing != null) {
            final occurrenceId = existing.data['id'] as String;
            final decided = await _db.customSelect(
              'SELECT 1 AS found FROM current_occurrence_decisions '
              'WHERE occurrence_id = ?',
              variables: [Variable(occurrenceId)],
            ).getSingleOrNull();
            final changed = existing.data['date'] != nominal ||
                existing.data['amount_minor'] != schedule.amountMinor ||
                existing.data['amount_state'] != schedule.amountState;
            if (!changed || decided != null) {
              await _db.customStatement(
                'INSERT OR IGNORE INTO occurrence_locators (schedule_id, '
                'rule_revision, generator_version, nominal_slot, '
                'occurrence_id) VALUES (?, ?, ?, ?, ?)',
                [
                  schedule.id,
                  schedule.revision,
                  generatorVersion,
                  nominal,
                  occurrenceId,
                ],
              );
              reused += 1;
              continue;
            }
            page.add(
              _PreparedOccurrence(
                scheduleId: schedule.id,
                occurrenceId: occurrenceId,
                occurrenceKey: key,
                nominalSlot: nominal,
                date: nominal,
                amountMinor: schedule.amountMinor,
                currency: schedule.currency,
                amountState: schedule.amountState,
                scheduleRevision: schedule.revision,
                updatedAt: _nowMs(),
                update: true,
              ),
            );
            updated += 1;
          } else {
            page.add(
              _PreparedOccurrence(
                scheduleId: schedule.id,
                occurrenceId: _nextId(),
                occurrenceKey: key,
                nominalSlot: nominal,
                date: nominal,
                amountMinor: schedule.amountMinor,
                currency: schedule.currency,
                amountState: schedule.amountState,
                scheduleRevision: schedule.revision,
                updatedAt: _nowMs(),
                update: false,
              ),
            );
            inserted += 1;
          }
          pageBytes += key.length + nominal.length + 96;
          if (page.length >= rowsPerPage || pageBytes >= maxBytesPerPage) {
            await flush();
          }
        }
      }
      if (rows.length < 100) {
        break;
      }
    }
    await flush();
    return GenerationResult(
      pages: pages,
      inserted: inserted,
      updated: updated,
      reused: reused,
    );
  }

  List<LocalDate> _slotsFor(ScheduleRow schedule, DateRange window) {
    final start = LocalDate.parse(schedule.startDate);
    final end =
        schedule.endDate == null ? null : LocalDate.parse(schedule.endDate!);
    if (schedule.isOneOff) {
      if (start.compareTo(window.start) < 0 ||
          start.compareTo(window.end) > 0) {
        return const <LocalDate>[];
      }
      if (end != null && start.compareTo(end) > 0) {
        return const <LocalDate>[];
      }
      return <LocalDate>[start];
    }
    final rule = RecurrenceRule.parse(schedule.rrule!);
    return rule.slotsIn(window, start: start, end: end);
  }

  ScheduleRow _scheduleFromRow(QueryRow row) => ScheduleRow(
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

final class _PreparedOccurrence {
  _PreparedOccurrence({
    required this.scheduleId,
    required this.occurrenceId,
    required this.occurrenceKey,
    required this.nominalSlot,
    required this.date,
    required this.amountMinor,
    required this.currency,
    required this.amountState,
    required this.scheduleRevision,
    required this.updatedAt,
    required this.update,
  });

  final String scheduleId;
  String occurrenceId;
  final String occurrenceKey;
  final String nominalSlot;
  final String date;
  final int? amountMinor;
  final String currency;
  final String amountState;
  final int scheduleRevision;
  final int updatedAt;
  final bool update;
}

/// One retained Expected occurrence.
final class OccurrenceRow {
  const OccurrenceRow({
    required this.id,
    required this.scheduleId,
    required this.scheduleRevision,
    required this.occurrenceKey,
    required this.date,
    required this.amountMinor,
    required this.currency,
    required this.amountState,
    required this.revision,
  });

  final String id;
  final String scheduleId;
  final int scheduleRevision;
  final String occurrenceKey;
  final String date;
  final int? amountMinor;
  final String currency;
  final String amountState;
  final int revision;
}

/// One selected decision of an occurrence.
final class CurrentDecisionRow {
  const CurrentDecisionRow({
    required this.occurrenceId,
    required this.decisionId,
    required this.decisionType,
    required this.obligationId,
    required this.settlementAllocationId,
  });

  final String occurrenceId;
  final String decisionId;
  final String decisionType;
  final String? obligationId;
  final String? settlementAllocationId;
}

/// Occurrence reads and the `DecideOccurrence` write.
///
/// A decision is immutable and dated. The selected pointer is
/// `current_occurrence_decisions`. Undo appends a compensating decision with
/// `supersedesDecisionId`; it never deletes the occurrence.
final class OccurrenceRepository {
  OccurrenceRepository({
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

  /// Upcoming occurrences in a date window, with the schedule name.
  Future<List<UpcomingOccurrenceRow>> upcomingBetween({
    required LocalDate from,
    required LocalDate to,
  }) async {
    final rows = await _db.customSelect(
      'SELECT o.id, o.schedule_id, o.date, o.amount_minor, o.currency, '
      's.name, s.kind '
      'FROM scheduled_occurrences o '
      'JOIN schedules s ON s.id = o.schedule_id '
      'WHERE o.deleted_at IS NULL AND s.deleted_at IS NULL '
      'AND o.date >= ? AND o.date <= ? '
      'ORDER BY o.date, o.id',
      variables: <Variable<Object>>[
        Variable<String>(from.toString()),
        Variable<String>(to.toString()),
      ],
    ).get();
    return <UpcomingOccurrenceRow>[
      for (final row in rows)
        UpcomingOccurrenceRow(
          id: row.data['id'] as String,
          scheduleId: row.data['schedule_id'] as String,
          name: row.data['name'] as String,
          kind: row.data['kind'] as String,
          date: row.data['date'] as String,
          amountMinor: row.data['amount_minor'] as int?,
          currency: row.data['currency'] as String,
        ),
    ];
  }

  /// One schedule's occurrences, oldest first.
  Future<List<OccurrenceRow>> listForSchedule(String scheduleId) async {
    final rows = await _db.customSelect(
      'SELECT id, schedule_id, schedule_revision, occurrence_key, date, '
      'amount_minor, currency, amount_state, revision '
      'FROM scheduled_occurrences WHERE schedule_id = ? '
      'AND deleted_at IS NULL ORDER BY date, id',
      variables: [Variable(scheduleId)],
    ).get();
    return <OccurrenceRow>[
      for (final row in rows)
        OccurrenceRow(
          id: row.data['id'] as String,
          scheduleId: row.data['schedule_id'] as String,
          scheduleRevision: row.data['schedule_revision'] as int,
          occurrenceKey: row.data['occurrence_key'] as String,
          date: row.data['date'] as String,
          amountMinor: row.data['amount_minor'] as int?,
          currency: row.data['currency'] as String,
          amountState: row.data['amount_state'] as String,
          revision: row.data['revision'] as int,
        ),
    ];
  }

  /// The selected decision of every occurrence of one schedule.
  Future<Map<String, CurrentDecisionRow>> currentDecisions(
    String scheduleId,
  ) async {
    final rows = await _db.customSelect(
      'SELECT c.occurrence_id, c.decision_id, d.decision_type, '
      'd.obligation_id, d.settlement_allocation_id '
      'FROM current_occurrence_decisions c '
      'JOIN occurrence_decisions d ON d.id = c.decision_id '
      'JOIN scheduled_occurrences o ON o.id = c.occurrence_id '
      'WHERE o.schedule_id = ?',
      variables: [Variable(scheduleId)],
    ).get();
    return <String, CurrentDecisionRow>{
      for (final row in rows)
        row.data['occurrence_id'] as String: CurrentDecisionRow(
          occurrenceId: row.data['occurrence_id'] as String,
          decisionId: row.data['decision_id'] as String,
          decisionType: row.data['decision_type'] as String,
          obligationId: row.data['obligation_id'] as String?,
          settlementAllocationId:
              row.data['settlement_allocation_id'] as String?,
        ),
    };
  }

  /// The `DecideOccurrence` plan.
  ///
  /// [decisionType] is accepted, edited, skipped, matched or cancelled. A
  /// skip or cancel after an accepted decision cancels the linked open
  /// obligation only when no settlement exists. The occurrence identity and
  /// the earlier decisions stay.
  Future<WritePlan> planDecide({
    required String decisionId,
    required String occurrenceId,
    required String decisionType,
    String? effectiveDate,
    int? amountMinor,
    String? currency,
    String? accountId,
    String? obligationId,
    String? settlementAllocationId,
    String? supersedesDecisionId,
    String? newObligationId,
  }) async {
    const valid = <String>{
      'accepted',
      'edited',
      'skipped',
      'matched',
      'cancelled',
    };
    if (!valid.contains(decisionType)) {
      throw ArgumentError.value(
        decisionType,
        'decisionType',
        'Unknown decision type',
      );
    }
    if (amountMinor != null && amountMinor < 0) {
      throw ArgumentError.value(
        amountMinor,
        'amountMinor',
        'Must be 0 or more',
      );
    }
    if (decisionType == 'matched' && obligationId == null) {
      throw const ScheduleError(ScheduleErrorCode.invalidTransition);
    }
    final occurrence = await _db.customSelect(
      'SELECT id, schedule_id, date, amount_minor, currency, amount_state '
      'FROM scheduled_occurrences WHERE id = ? AND deleted_at IS NULL',
      variables: [Variable(occurrenceId)],
    ).getSingleOrNull();
    if (occurrence == null) {
      throw const ScheduleError(ScheduleErrorCode.unknownRecord);
    }
    final scheduleId = occurrence.data['schedule_id'] as String;
    final occurrenceDate = occurrence.data['date'] as String;
    final occurrenceCurrency = occurrence.data['currency'] as String;
    final current = await _db.customSelect(
      'SELECT d.id, d.decision_type, d.obligation_id FROM '
      'current_occurrence_decisions c JOIN occurrence_decisions d '
      'ON d.id = c.decision_id WHERE c.occurrence_id = ?',
      variables: [Variable(occurrenceId)],
    ).getSingleOrNull();
    if (supersedesDecisionId != null) {
      final prior = await _db.customSelect(
        'SELECT occurrence_id FROM occurrence_decisions WHERE id = ?',
        variables: [Variable(supersedesDecisionId)],
      ).getSingleOrNull();
      if (prior == null || prior.data['occurrence_id'] != occurrenceId) {
        throw const ScheduleError(ScheduleErrorCode.unknownRecord);
      }
    }

    final now = _nowMs();
    final decisionCurrency = currency ?? occurrenceCurrency;
    final changes = <ChangeLogEntry>[];
    final statements = <Future<void> Function()>[];
    String? linkedObligation = obligationId;

    final priorObligation = current?.data['obligation_id'] as String?;
    if ((decisionType == 'skipped' || decisionType == 'cancelled') &&
        priorObligation != null) {
      final allocated = await _db.customSelect(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total '
        'FROM settlement_allocations WHERE obligation_id = ? '
        'AND deleted_at IS NULL',
        variables: [Variable(priorObligation)],
      ).getSingle();
      if ((allocated.data['total'] as int) > 0) {
        throw const ScheduleError(ScheduleErrorCode.invalidTransition);
      }
      final obligation = await _db.customSelect(
        'SELECT revision, status FROM obligations WHERE id = ?',
        variables: [Variable(priorObligation)],
      ).getSingleOrNull();
      if (obligation != null && obligation.data['status'] == 'open') {
        final revision = obligation.data['revision'] as int;
        changes.add(
          ChangeLogEntry(
            entityId: priorObligation,
            fromRevision: revision,
            toRevision: revision + 1,
            changeKind: 'softDelete',
            beforeJson: '{"status":"open"}',
            afterJson: '{"status":"cancelled"}',
            schemaVersion: 1,
          ),
        );
        statements.add(() async {
          await _db.customStatement(
            'UPDATE obligations SET status = ?, updated_at = ?, '
            'revision = revision + 1 WHERE id = ?',
            ['cancelled', now, priorObligation],
          );
        });
      }
    }

    if ((decisionType == 'accepted' || decisionType == 'edited') &&
        linkedObligation == null &&
        amountMinor != null) {
      final id = newObligationId ?? _nextId();
      linkedObligation = id;
      final scheduleKind = await _db.customSelect(
        'SELECT kind FROM schedules WHERE id = ?',
        variables: [Variable(scheduleId)],
      ).getSingleOrNull();
      final direction = scheduleKind?.data['kind'] == 'income' ? 'in' : 'out';
      changes.add(
        ChangeLogEntry(
          entityId: id,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'amountMinor': amountMinor,
            'currency': decisionCurrency,
            'direction': direction,
            'date': effectiveDate ?? occurrenceDate,
          }),
          schemaVersion: 1,
        ),
      );
      statements.add(() async {
        await _db.customStatement(
          'INSERT INTO obligations (id, created_at, updated_at, deleted_at, '
          'revision, account_id, date, direction, amount_minor, currency, '
          'amount_state, status) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, ?)',
          [
            id,
            now,
            now,
            accountId,
            effectiveDate ?? occurrenceDate,
            direction,
            amountMinor,
            decisionCurrency,
            'known',
            'open',
          ],
        );
      });
    }

    changes.add(
      ChangeLogEntry(
        entityId: decisionId,
        toRevision: 1,
        changeKind: 'create',
        afterJson: jsonEncode(<String, Object?>{
          'occurrenceId': occurrenceId,
          'decisionType': decisionType,
          if (effectiveDate != null) 'effectiveDate': effectiveDate,
          if (amountMinor != null) 'amountMinor': amountMinor,
        }),
        schemaVersion: 1,
      ),
    );
    statements.add(() async {
      final intent = await _db.customSelect(
        'SELECT operation_id FROM operation_intents WHERE state = ? LIMIT 1',
        variables: [const Variable('running')],
      ).getSingleOrNull();
      if (intent == null) {
        throw StateError('No running operation for the decision');
      }
      final operationId = intent.data['operation_id'] as String;
      final amountState = amountMinor == null ? 'unchanged' : 'known';
      await _db.customStatement(
        'INSERT INTO occurrence_decisions (id, created_at, updated_at, '
        'deleted_at, revision, occurrence_id, operation_id, decision_type, '
        'account_id, effective_date, amount_minor, currency, amount_state, '
        'obligation_id, settlement_allocation_id, supersedes_decision_id) '
        'VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          decisionId,
          now,
          now,
          occurrenceId,
          operationId,
          decisionType,
          accountId,
          effectiveDate,
          amountMinor,
          amountMinor == null ? null : decisionCurrency,
          amountState,
          linkedObligation,
          settlementAllocationId,
          supersedesDecisionId,
        ],
      );
      await _db.customStatement(
        'INSERT INTO current_occurrence_decisions (occurrence_id, '
        'decision_id, selected_operation_id) VALUES (?, ?, ?) '
        'ON CONFLICT(occurrence_id) DO UPDATE SET '
        'decision_id = excluded.decision_id, '
        'selected_operation_id = excluded.selected_operation_id',
        [occurrenceId, decisionId, operationId],
      );
      await _bumpScheduleScope(scheduleId);
      await _markDirty(scheduleId, effectiveDate ?? occurrenceDate);
    });

    return WritePlan(
      changes: changes,
      apply: () async {
        for (final statement in statements) {
          await statement();
        }
      },
    );
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

/// One upcoming occurrence with its schedule name (Home timeline).
final class UpcomingOccurrenceRow {
  const UpcomingOccurrenceRow({
    required this.id,
    required this.scheduleId,
    required this.name,
    required this.kind,
    required this.date,
    required this.amountMinor,
    required this.currency,
  });

  final String id;
  final String scheduleId;
  final String name;
  final String kind;
  final String date;
  final int? amountMinor;
  final String currency;
}
