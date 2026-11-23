// P16 (SPEC 8.17; DATABASE_DESIGN 4.3; F05-C): obligations and settlement.
//
// One canonical obligation is an amount expected on a date. An accepted
// settlement references an actual transaction and is never more than the
// unpaid remainder: 1,240 - 500 = 740. A larger payment keeps its unallocated
// part; the remainder is never clamped to zero silently. A cross-currency
// settlement stays unavailable (v1.1).

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/dates.dart';
import '../db/app_database.dart';
import '../db/command_repository.dart';
import 'occurrences.dart';
import 'write_plan.dart';

/// One obligation row.
final class ObligationRow {
  const ObligationRow({
    required this.id,
    required this.accountId,
    required this.date,
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.amountState,
    required this.status,
    required this.revision,
  });

  final String id;
  final String? accountId;
  final String date;
  final String direction;
  final int? amountMinor;
  final String currency;
  final String amountState;
  final String status;
  final int revision;
}

/// Obligation reads and the `SettleObligation` write.
final class SettlementRepository {
  SettlementRepository({
    required AppDatabase db,
    required DateTime Function() clockUtc,
  })  : _db = db,
        _clockUtc = clockUtc;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  /// One obligation, or null.
  Future<ObligationRow?> obligation(String id) async {
    final row = await _db.customSelect(
      'SELECT id, account_id, date, direction, amount_minor, currency, '
      'amount_state, status, revision FROM obligations WHERE id = ?',
      variables: [Variable(id)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return ObligationRow(
      id: row.data['id'] as String,
      accountId: row.data['account_id'] as String?,
      date: row.data['date'] as String,
      direction: row.data['direction'] as String,
      amountMinor: row.data['amount_minor'] as int?,
      currency: row.data['currency'] as String,
      amountState: row.data['amount_state'] as String,
      status: row.data['status'] as String,
      revision: row.data['revision'] as int,
    );
  }

  /// The accepted settlement amount of one obligation.
  Future<int> acceptedMinor(String obligationId) async {
    final row = await _db.customSelect(
      'SELECT COALESCE(SUM(amount_minor), 0) AS total '
      'FROM settlement_allocations WHERE obligation_id = ? '
      'AND deleted_at IS NULL',
      variables: [Variable(obligationId)],
    ).getSingle();
    return row.data['total'] as int;
  }

  /// The unpaid amount, or null when the obligation amount is Missing.
  Future<int?> unpaidMinor(String obligationId) async {
    final obligation = await this.obligation(obligationId);
    if (obligation == null) {
      throw const ScheduleError(ScheduleErrorCode.unknownRecord);
    }
    final amount = obligation.amountMinor;
    if (amount == null) {
      return null;
    }
    final accepted = await acceptedMinor(obligationId);
    final remaining = amount - accepted;
    return remaining < 0 ? 0 : remaining;
  }

  /// Creates one canonical obligation (a statement, a one-off entry or an
  /// accepted occurrence).
  WritePlan planCreateObligation({
    required String id,
    required String date,
    required String direction,
    required int amountMinor,
    required String currency,
    String? accountId,
    String amountState = 'known',
  }) {
    LocalDate.parse(date);
    if (direction != 'in' && direction != 'out') {
      throw ArgumentError.value(direction, 'direction', 'Must be in or out');
    }
    if (amountMinor < 0) {
      throw ArgumentError.value(
        amountMinor,
        'amountMinor',
        'Must be 0 or more',
      );
    }
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: id,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'date': date,
            'direction': direction,
            'amountMinor': amountMinor,
            'currency': currency,
          }),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'INSERT INTO obligations (id, created_at, updated_at, deleted_at, '
          'revision, account_id, date, direction, amount_minor, currency, '
          'amount_state, status) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, '
          "'open')",
          [
            id,
            now,
            now,
            accountId,
            date,
            direction,
            amountMinor,
            currency,
            amountState,
          ],
        );
        if (accountId != null) {
          await _bumpAccountScope(accountId);
          await _markDirty(accountId, date);
        }
      },
    );
  }

  /// The `SettleObligation` plan.
  ///
  /// [amountMinor] is the part of [transactionId] allocated to the
  /// obligation. A larger payment can keep an unallocated part, but the
  /// allocation may not exceed the unpaid remainder.
  Future<WritePlan> planSettle({
    required String allocationId,
    required String obligationId,
    required String transactionId,
    required int amountMinor,
    required String currency,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor', 'Must be above 0');
    }
    final obligation = await this.obligation(obligationId);
    if (obligation == null) {
      throw const ScheduleError(ScheduleErrorCode.unknownRecord);
    }
    if (obligation.currency != currency) {
      throw const ScheduleError(ScheduleErrorCode.invalidTransition);
    }
    if (obligation.status != 'open') {
      throw const ScheduleError(ScheduleErrorCode.invalidTransition);
    }
    final amount = obligation.amountMinor;
    if (amount == null) {
      throw const ScheduleError(ScheduleErrorCode.invalidTransition);
    }
    final accepted = await acceptedMinor(obligationId);
    final remaining = amount - accepted;
    if (amountMinor > remaining) {
      throw ScheduleError(
        ScheduleErrorCode.overAllocation,
        remainingMinor: remaining,
      );
    }
    final transaction = await _db.customSelect(
      'SELECT account_id, currency FROM transactions WHERE id = ? '
      'AND deleted_at IS NULL',
      variables: [Variable(transactionId)],
    ).getSingleOrNull();
    if (transaction == null) {
      throw const ScheduleError(ScheduleErrorCode.unknownRecord);
    }
    if (transaction.data['currency'] != currency) {
      throw const ScheduleError(ScheduleErrorCode.invalidTransition);
    }
    final accountId = transaction.data['account_id'] as String;
    final now = _nowMs();
    final settles = amountMinor == remaining;
    final changes = <ChangeLogEntry>[
      ChangeLogEntry(
        entityId: allocationId,
        toRevision: 1,
        changeKind: 'create',
        afterJson: jsonEncode(<String, Object?>{
          'obligationId': obligationId,
          'transactionId': transactionId,
          'amountMinor': amountMinor,
          'currency': currency,
        }),
        schemaVersion: 1,
      ),
      if (settles)
        ChangeLogEntry(
          entityId: obligationId,
          fromRevision: obligation.revision,
          toRevision: obligation.revision + 1,
          changeKind: 'edit',
          beforeJson: '{"status":"open"}',
          afterJson: '{"status":"settled"}',
          schemaVersion: 1,
        ),
    ];
    return WritePlan(
      changes: changes,
      apply: () async {
        await _db.customStatement(
          'INSERT INTO settlement_allocations (id, created_at, updated_at, '
          'deleted_at, revision, obligation_id, transaction_id, amount_minor, '
          'currency) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?)',
          [
            allocationId,
            now,
            now,
            obligationId,
            transactionId,
            amountMinor,
            currency,
          ],
        );
        if (settles) {
          await _db.customStatement(
            'UPDATE obligations SET status = ?, updated_at = ?, '
            'revision = revision + 1 WHERE id = ?',
            ['settled', now, obligationId],
          );
        }
        await _bumpAccountScope(accountId);
        await _markDirty(accountId, obligation.date);
      },
    );
  }

  Future<void> _bumpAccountScope(String accountId) async {
    await _db.customStatement(
      'INSERT INTO dependency_scopes (kind, scope_key) '
      'SELECT ?, ? WHERE NOT EXISTS (SELECT 1 FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      ['account', accountId, 'account', accountId],
    );
    await _db.customStatement(
      'INSERT INTO dependency_revisions (scope_id, revision) '
      'SELECT id, 1 FROM dependency_scopes WHERE kind = ? AND scope_key = ? '
      'AND NOT EXISTS (SELECT 1 FROM dependency_revisions '
      'WHERE scope_id = dependency_scopes.id)',
      ['account', accountId],
    );
    await _db.customStatement(
      'UPDATE dependency_revisions SET revision = revision + 1 '
      'WHERE scope_id = (SELECT id FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      ['account', accountId],
    );
  }

  Future<void> _markDirty(String accountId, String date) async {
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
      ['metric.cashflow', date, 'account', accountId],
    );
  }
}
