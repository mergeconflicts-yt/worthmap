// P23 (SPEC 4.2, 4.10, 6.3; flow F05; DATABASE_DESIGN 4.2): transfer writes.
//
// A transfer is one financial event with two linked principal postings: the
// sending account posts negative and the receiving account posts positive.
// Neither principal side is income or spending (F05-A, SPEC 4.2). A charged
// fee is a separate posting of kind `fee` on the sending account, once
// (SPEC 4.10, F05-D). The two sides and the link commit together.
//
// The repository prepares a plan; the command writer runs it. Money stays
// integer minor units (SPEC 4.1).

import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/command_repository.dart';
import 'write_plan.dart';

/// One transfer to create inside one command.
///
/// [amountMinor] is positive. The plan writes the sign: the sending posting is
/// negative and the receiving posting is positive.
final class NewTransfer {
  const NewTransfer({
    required this.eventId,
    required this.linkId,
    required this.sendingId,
    required this.receivingId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.date,
    required this.amountMinor,
    required this.currency,
    this.feeId,
    this.feeMinor,
    this.note,
  });

  final String eventId;
  final String linkId;
  final String sendingId;
  final String receivingId;
  final String fromAccountId;
  final String toAccountId;
  final String date;
  final int amountMinor;
  final String currency;

  /// The fee posting and amount, both null when no fee is charged.
  final String? feeId;
  final int? feeMinor;
  final String? note;
}

/// Safe transfer failure codes (no amount, account or id in the text).
enum TransferWriteErrorCode {
  /// The transfer row is absent or already deleted.
  unknownTransfer,

  /// The stored transfer is already soft-deleted.
  alreadyDeleted,
}

/// A typed transfer failure. It holds a code only (AGENTS 2.6).
class TransferWriteError implements Exception {
  const TransferWriteError(this.code);

  final TransferWriteErrorCode code;

  @override
  String toString() => 'TransferWriteError(${code.name})';
}

/// SPEC 6.3 / 4.10: transfer reads and prepared writes.
final class TransferRepository {
  TransferRepository({
    required AppDatabase db,
    required DateTime Function() clockUtc,
  })  : _db = db,
        _clockUtc = clockUtc;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  /// F05 step 2: writes the event, the two principals, an optional fee and the
  /// link in one plan. The event carries the running operation id.
  WritePlan planCreate(NewTransfer transfer) {
    if (transfer.amountMinor <= 0) {
      throw ArgumentError.value(
        transfer.amountMinor,
        'amountMinor',
        'Must be positive',
      );
    }
    if (transfer.fromAccountId == transfer.toAccountId) {
      throw ArgumentError.value(
        transfer.toAccountId,
        'toAccountId',
        'Must differ from the sending account',
      );
    }
    if ((transfer.feeId == null) != (transfer.feeMinor == null)) {
      throw ArgumentError('The fee needs both an id and an amount');
    }
    final feeMinor = transfer.feeMinor;
    if (feeMinor != null && feeMinor <= 0) {
      throw ArgumentError.value(feeMinor, 'feeMinor', 'Must be positive');
    }
    final now = _nowMs();
    final changes = <ChangeLogEntry>[
      ChangeLogEntry(
        entityId: transfer.eventId,
        toRevision: 1,
        changeKind: 'create',
        afterJson: jsonEncode(<String, Object?>{
          'type': 'financial_event',
          'date': transfer.date,
          'event': 'transfer',
        }),
        schemaVersion: 1,
      ),
      ChangeLogEntry(
        entityId: transfer.sendingId,
        toRevision: 1,
        changeKind: 'create',
        afterJson: jsonEncode(<String, Object?>{
          'amountMinor': -transfer.amountMinor,
          'currency': transfer.currency,
          'kind': 'transfer',
          'accountId': transfer.fromAccountId,
        }),
        schemaVersion: 1,
      ),
      ChangeLogEntry(
        entityId: transfer.receivingId,
        toRevision: 1,
        changeKind: 'create',
        afterJson: jsonEncode(<String, Object?>{
          'amountMinor': transfer.amountMinor,
          'currency': transfer.currency,
          'kind': 'transfer',
          'accountId': transfer.toAccountId,
        }),
        schemaVersion: 1,
      ),
      if (transfer.feeId != null)
        ChangeLogEntry(
          entityId: transfer.feeId!,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'amountMinor': -feeMinor!,
            'currency': transfer.currency,
            'kind': 'fee',
            'accountId': transfer.fromAccountId,
          }),
          schemaVersion: 1,
        ),
      ChangeLogEntry(
        entityId: transfer.linkId,
        toRevision: 1,
        changeKind: 'create',
        afterJson: '{"type":"transfer_links"}',
        schemaVersion: 1,
      ),
    ];
    return WritePlan(
      changes: changes,
      apply: () async {
        final intent = await _db.customSelect(
          'SELECT operation_id FROM operation_intents WHERE state = ? LIMIT 1',
          variables: [const Variable('running')],
        ).getSingleOrNull();
        if (intent == null) {
          throw StateError('No running operation for the draft');
        }
        final operationId = intent.data['operation_id'] as String;
        await _db.customStatement(
          'INSERT INTO financial_events (id, created_at, updated_at, '
          'deleted_at, revision, event_type, date, operation_id, '
          'supersedes_event_id) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, NULL)',
          [
            transfer.eventId,
            now,
            now,
            'transfer',
            transfer.date,
            operationId,
          ],
        );
        await _insertPosting(
          id: transfer.sendingId,
          eventId: transfer.eventId,
          accountId: transfer.fromAccountId,
          date: transfer.date,
          amountMinor: -transfer.amountMinor,
          currency: transfer.currency,
          kind: 'transfer',
          note: transfer.note,
          now: now,
        );
        await _insertPosting(
          id: transfer.receivingId,
          eventId: transfer.eventId,
          accountId: transfer.toAccountId,
          date: transfer.date,
          amountMinor: transfer.amountMinor,
          currency: transfer.currency,
          kind: 'transfer',
          note: transfer.note,
          now: now,
        );
        final feeId = transfer.feeId;
        if (feeId != null) {
          await _insertPosting(
            id: feeId,
            eventId: transfer.eventId,
            accountId: transfer.fromAccountId,
            date: transfer.date,
            amountMinor: -feeMinor!,
            currency: transfer.currency,
            kind: 'fee',
            note: null,
            now: now,
          );
        }
        await _db.customStatement(
          'INSERT INTO transfer_links (id, created_at, updated_at, '
          'deleted_at, revision, event_id, sending_transaction_id, '
          'receiving_transaction_id, fee_transaction_id) '
          'VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?)',
          [
            transfer.linkId,
            now,
            now,
            transfer.eventId,
            transfer.sendingId,
            transfer.receivingId,
            transfer.feeId,
          ],
        );
        await _bumpAccountRevision(transfer.fromAccountId);
        await _bumpAccountRevision(transfer.toAccountId);
      },
    );
  }

  /// SPEC 8.18 / F05: Undo of one confirmed transfer.
  ///
  /// The compensating write soft-deletes the event, both principals, the fee
  /// and the link. Every identity stays reserved. A later authoritative record
  /// is not edited.
  Future<WritePlan> planUndoCreate({required String eventId}) async {
    final event = await _db.customSelect(
      'SELECT revision FROM financial_events WHERE id = ? '
      'AND deleted_at IS NULL',
      variables: [Variable(eventId)],
    ).getSingleOrNull();
    if (event == null) {
      throw const TransferWriteError(TransferWriteErrorCode.unknownTransfer);
    }
    final link = await _db.customSelect(
      'SELECT id, revision FROM transfer_links WHERE event_id = ? '
      'AND deleted_at IS NULL',
      variables: [Variable(eventId)],
    ).getSingleOrNull();
    final postings = await _db.customSelect(
      'SELECT id, account_id, revision FROM transactions WHERE event_id = ? '
      'AND deleted_at IS NULL ORDER BY id',
      variables: [Variable(eventId)],
    ).get();
    if (link == null || postings.length < 2) {
      throw const TransferWriteError(TransferWriteErrorCode.unknownTransfer);
    }
    final now = _nowMs();
    final changes = <ChangeLogEntry>[
      ChangeLogEntry(
        entityId: eventId,
        fromRevision: event.data['revision'] as int,
        toRevision: (event.data['revision'] as int) + 1,
        changeKind: 'softDelete',
        beforeJson: '{"deleted":false}',
        afterJson: '{"deleted":true}',
        schemaVersion: 1,
      ),
      for (final posting in postings)
        ChangeLogEntry(
          entityId: posting.data['id'] as String,
          fromRevision: posting.data['revision'] as int,
          toRevision: (posting.data['revision'] as int) + 1,
          changeKind: 'softDelete',
          beforeJson: '{"deleted":false}',
          afterJson: '{"deleted":true}',
          schemaVersion: 1,
        ),
      ChangeLogEntry(
        entityId: link.data['id'] as String,
        fromRevision: link.data['revision'] as int,
        toRevision: (link.data['revision'] as int) + 1,
        changeKind: 'softDelete',
        beforeJson: '{"deleted":false}',
        afterJson: '{"deleted":true}',
        schemaVersion: 1,
      ),
    ];
    final accountIds = <String>{
      for (final posting in postings) posting.data['account_id'] as String,
    };
    return WritePlan(
      changes: changes,
      apply: () async {
        await _db.customStatement(
          'UPDATE financial_events SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ? AND deleted_at IS NULL',
          [now, now, eventId],
        );
        await _db.customStatement(
          'UPDATE transactions SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE event_id = ? AND deleted_at IS NULL',
          [now, now, eventId],
        );
        await _db.customStatement(
          'UPDATE transfer_links SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE event_id = ? AND deleted_at IS NULL',
          [now, now, eventId],
        );
        for (final accountId in accountIds) {
          await _bumpAccountRevision(accountId);
        }
      },
    );
  }

  Future<void> _insertPosting({
    required String id,
    required String eventId,
    required String accountId,
    required String date,
    required int amountMinor,
    required String currency,
    required String kind,
    required String? note,
    required int now,
  }) async {
    await _db.customStatement(
      'INSERT INTO transactions (id, created_at, updated_at, deleted_at, '
      'revision, event_id, account_id, date, amount_minor, currency, '
      'kind, merchant_name, note, category_id, source, is_estimated) '
      "VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, NULL, ?, NULL, 'manual', 0)",
      [
        id,
        now,
        now,
        eventId,
        accountId,
        date,
        amountMinor,
        currency,
        kind,
        note,
      ],
    );
  }

  Future<void> _bumpAccountRevision(String accountId) async {
    await _db.customStatement(
      'INSERT INTO dependency_scopes (kind, scope_key) '
      'SELECT ?, ? WHERE NOT EXISTS ('
      'SELECT 1 FROM dependency_scopes WHERE kind = ? AND scope_key = ?)',
      ['account', accountId, 'account', accountId],
    );
    await _db.customStatement(
      'UPDATE dependency_revisions SET revision = revision + 1 '
      'WHERE scope_id = (SELECT id FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      ['account', accountId],
    );
    await _db.customStatement(
      'INSERT INTO dependency_revisions (scope_id, revision) '
      'SELECT id, 1 FROM dependency_scopes WHERE kind = ? AND scope_key = ? '
      'AND NOT EXISTS (SELECT 1 FROM dependency_revisions '
      'WHERE scope_id = dependency_scopes.id)',
      ['account', accountId],
    );
  }
}
