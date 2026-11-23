// P12 (SPEC 9.3; DATABASE_DESIGN 4.1, 5): payments and their children.
//
// The repository prepares a plan; the command writer runs it. Reads use
// owner-validated statements over the authored tables. Money stays integer
// minor units (SPEC 4.1).

import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/command_repository.dart';
import 'write_plan.dart';

/// One payment row for a list (Q01 account payments).
final class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.accountId,
    required this.date,
    required this.amountMinor,
    required this.currency,
    required this.kind,
    required this.merchantName,
    required this.categoryId,
    required this.revision,
    required this.note,
  });

  final String id;
  final String accountId;
  final String date;
  final int amountMinor;
  final String currency;
  final String kind;
  final String? merchantName;
  final String? categoryId;
  final int revision;
  final String? note;
}

/// One split of a new payment.
final class PaymentSplitInput {
  const PaymentSplitInput({
    required this.id,
    required this.categoryId,
    required this.amountMinor,
    this.note,
  });

  final String id;
  final String categoryId;
  final int amountMinor;
  final String? note;
}

/// A payment to create inside one command.
final class NewPayment {
  const NewPayment({
    required this.id,
    required this.eventId,
    required this.accountId,
    required this.date,
    required this.amountMinor,
    required this.currency,
    required this.kind,
    this.merchantName,
    this.note,
    this.categoryId,
    this.splits = const <PaymentSplitInput>[],
    this.tagIds = const <String>[],
    this.source = 'manual',
  });

  final String id;
  final String eventId;
  final String accountId;
  final String date;
  final int amountMinor;
  final String currency;
  final String kind;
  final String? merchantName;
  final String? note;
  final String? categoryId;
  final List<PaymentSplitInput> splits;
  final List<String> tagIds;
  final String source;
}

/// One category total (split contributions only).
final class CategoryTotalRow {
  const CategoryTotalRow({
    required this.categoryId,
    required this.amountMinor,
  });

  final String? categoryId;
  final int amountMinor;
}

/// Safe payment failure codes (no amount, merchant or id in the text).
enum PaymentErrorCode {
  /// The payment row is absent or already deleted.
  unknownPayment,

  /// The stored revision differs from the expected one.
  staleRevision,
}

/// A typed payment failure. It holds a code only (AGENTS 2.6).
class PaymentError implements Exception {
  const PaymentError(this.code);

  final PaymentErrorCode code;

  @override
  String toString() => 'PaymentError(${code.name})';
}

/// SPEC 6.5 / DATABASE_DESIGN 7: payment reads and prepared writes.
final class PaymentRepository {
  PaymentRepository({
    required AppDatabase db,
    required DateTime Function() clockUtc,
  })  : _db = db,
        _clockUtc = clockUtc;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  /// Q01: one account's payments, newest first, keyset paged.
  Future<List<PaymentRow>> page({
    required String accountId,
    int limit = 50,
    ({String date, String id})? before,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be 1 to 100');
    }
    final rows = await _db.customSelect(
      'SELECT id, account_id, date, amount_minor, currency, kind, '
      'merchant_name, category_id, revision, note FROM transactions '
      'WHERE account_id = ? AND deleted_at IS NULL '
      '${before == null ? '' : 'AND (date < ? OR (date = ? AND id < ?)) '}'
      'ORDER BY date DESC, id DESC LIMIT ?',
      variables: [
        Variable(accountId),
        if (before != null) ...[
          Variable(before.date),
          Variable(before.date),
          Variable(before.id),
        ],
        Variable(limit),
      ],
    ).get();
    return <PaymentRow>[
      for (final row in rows)
        PaymentRow(
          id: row.data['id'] as String,
          accountId: row.data['account_id'] as String,
          date: row.data['date'] as String,
          amountMinor: row.data['amount_minor'] as int,
          currency: row.data['currency'] as String,
          kind: row.data['kind'] as String,
          merchantName: row.data['merchant_name'] as String?,
          categoryId: row.data['category_id'] as String?,
          revision: row.data['revision'] as int,
          note: row.data['note'] as String?,
        ),
    ];
  }

  /// Q11: category totals for a date range.
  ///
  /// A split transaction contributes only its split rows; an unsplit
  /// transaction contributes its own category once (DATABASE_DESIGN 7).
  Future<List<CategoryTotalRow>> categoryTotals({
    required String from,
    required String to,
    Set<String>? accountIds,
  }) async {
    final scope = accountIds == null || accountIds.isEmpty
        ? ''
        : 'AND t.account_id IN (${List<String>.filled(accountIds.length, '?').join(', ')}) ';
    final rows = await _db.customSelect(
      'SELECT category_id, SUM(amount_minor) AS total FROM ('
      'SELECT s.category_id AS category_id, s.amount_minor AS amount_minor '
      'FROM transaction_splits s JOIN transactions t ON t.id = s.transaction_id '
      'WHERE s.deleted_at IS NULL AND t.deleted_at IS NULL '
      'AND t.date >= ? AND t.date <= ? $scope'
      'UNION ALL '
      'SELECT t.category_id, t.amount_minor FROM transactions t '
      'WHERE t.deleted_at IS NULL AND t.category_id IS NOT NULL '
      'AND t.date >= ? AND t.date <= ? '
      'AND NOT EXISTS (SELECT 1 FROM transaction_splits s2 '
      'WHERE s2.transaction_id = t.id AND s2.deleted_at IS NULL) '
      '$scope'
      ') GROUP BY category_id ORDER BY total DESC',
      variables: [
        Variable(from),
        Variable(to),
        if (accountIds != null && accountIds.isNotEmpty)
          for (final id in accountIds) Variable(id),
        Variable(from),
        Variable(to),
        if (accountIds != null && accountIds.isNotEmpty)
          for (final id in accountIds) Variable(id),
      ],
    ).get();
    return <CategoryTotalRow>[
      for (final row in rows)
        CategoryTotalRow(
          categoryId: row.data['category_id'] as String?,
          amountMinor: row.data['total'] as int,
        ),
    ];
  }

  /// SPEC 8.16: creates the payment event, the payment, its splits, its tags
  /// and one ChangeLog entry per authored row (the bridge writes none).
  ///
  /// The plan must run inside a command whose running intent belongs to
  /// [NewPayment.draftId]; the event carries that operation id.
  WritePlan planCreate(NewPayment payment) {
    final splitTotal =
        payment.splits.fold<int>(0, (sum, s) => sum + s.amountMinor);
    if (payment.splits.isNotEmpty && splitTotal != payment.amountMinor) {
      throw ArgumentError('The splits must add to the payment amount');
    }
    if (payment.kind != 'expense' &&
        payment.kind != 'income' &&
        payment.kind != 'refund' &&
        payment.kind != 'fee' &&
        payment.kind != 'transfer' &&
        payment.kind != 'loanIn' &&
        payment.kind != 'saleProceeds') {
      throw ArgumentError.value(payment.kind, 'kind', 'Unknown payment kind');
    }
    final now = _nowMs();
    final changes = <ChangeLogEntry>[
      ChangeLogEntry(
        entityId: payment.eventId,
        toRevision: 1,
        changeKind: 'create',
        afterJson: jsonEncode(<String, Object?>{
          'type': 'financial_event',
          'date': payment.date,
        }),
        schemaVersion: 1,
      ),
      ChangeLogEntry(
        entityId: payment.id,
        toRevision: 1,
        changeKind: 'create',
        afterJson: jsonEncode(<String, Object?>{
          'amountMinor': payment.amountMinor,
          'currency': payment.currency,
          'kind': payment.kind,
          'accountId': payment.accountId,
        }),
        schemaVersion: 1,
      ),
      for (final split in payment.splits)
        ChangeLogEntry(
          entityId: split.id,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'amountMinor': split.amountMinor,
            'categoryId': split.categoryId,
          }),
          schemaVersion: 1,
        ),
    ];
    return WritePlan(
      changes: changes,
      apply: () async {
        // The single writer runs one command at a time; the event carries
        // that operation id (financial_events.operation_id).
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
            payment.eventId,
            now,
            now,
            _eventType(payment.kind),
            payment.date,
            operationId,
          ],
        );
        await _db.customStatement(
          'INSERT INTO transactions (id, created_at, updated_at, deleted_at, '
          'revision, event_id, account_id, date, amount_minor, currency, '
          'kind, merchant_name, note, category_id, source, is_estimated) '
          'VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
          [
            payment.id,
            now,
            now,
            payment.eventId,
            payment.accountId,
            payment.date,
            payment.amountMinor,
            payment.currency,
            payment.kind,
            payment.merchantName,
            payment.note,
            payment.categoryId,
            payment.source,
          ],
        );
        for (final split in payment.splits) {
          await _db.customStatement(
            'INSERT INTO transaction_splits (id, created_at, updated_at, '
            'deleted_at, revision, transaction_id, category_id, amount_minor, '
            'currency, note) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?)',
            [
              split.id,
              now,
              now,
              payment.id,
              split.categoryId,
              split.amountMinor,
              payment.currency,
              split.note,
            ],
          );
        }
        for (final tagId in payment.tagIds) {
          await _db.customStatement(
            'INSERT INTO transaction_tags (transaction_id, tag_id) '
            'VALUES (?, ?)',
            [payment.id, tagId],
          );
        }
        await _bumpAccountRevision(payment.accountId);
      },
    );
  }

  /// P22 / flow F03 step 5 (SPEC 8.16): an edit changes the existing event.
  ///
  /// The payment row keeps its identity and its event. The live split rows are
  /// soft-deleted with one ChangeLog entry each, and the new parts are
  /// inserted. A changed payload with the same identity fails here first.
  Future<WritePlan> planUpdate({
    required String id,
    required int expectedRevision,
    required String date,
    required int amountMinor,
    required String kind,
    String? merchantName,
    String? note,
    String? categoryId,
    List<PaymentSplitInput> splits = const <PaymentSplitInput>[],
    List<String> tagIds = const <String>[],
  }) async {
    final splitTotal = splits.fold<int>(0, (sum, s) => sum + s.amountMinor);
    if (splits.isNotEmpty && splitTotal != amountMinor) {
      throw ArgumentError('The splits must add to the payment amount');
    }
    const kinds = <String>{
      'expense',
      'income',
      'refund',
      'fee',
      'transfer',
      'loanIn',
      'saleProceeds',
    };
    if (!kinds.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', 'Unknown payment kind');
    }
    final current = await _db.customSelect(
      'SELECT id, account_id, currency, revision FROM transactions WHERE id = ? '
      'AND deleted_at IS NULL',
      variables: [Variable(id)],
    ).getSingleOrNull();
    if (current == null) {
      throw const PaymentError(PaymentErrorCode.unknownPayment);
    }
    final currency = current.data['currency'] as String;
    if (current.data['revision'] != expectedRevision) {
      throw const PaymentError(PaymentErrorCode.staleRevision);
    }
    final accountId = current.data['account_id'] as String;
    final liveSplits = await _db.customSelect(
      'SELECT id, revision FROM transaction_splits WHERE transaction_id = ? '
      'AND deleted_at IS NULL ORDER BY id',
      variables: [Variable(id)],
    ).get();
    final now = _nowMs();
    final changes = <ChangeLogEntry>[
      ChangeLogEntry(
        entityId: id,
        fromRevision: expectedRevision,
        toRevision: expectedRevision + 1,
        changeKind: 'edit',
        beforeJson: jsonEncode(<String, Object?>{
          'revision': expectedRevision,
        }),
        afterJson: jsonEncode(<String, Object?>{
          'amountMinor': amountMinor,
          'date': date,
          'kind': kind,
          'accountId': accountId,
        }),
        schemaVersion: 1,
      ),
      for (final split in liveSplits)
        ChangeLogEntry(
          entityId: split.data['id'] as String,
          fromRevision: split.data['revision'] as int,
          toRevision: (split.data['revision'] as int) + 1,
          changeKind: 'softDelete',
          beforeJson: '{"deleted":false}',
          afterJson: '{"deleted":true}',
          schemaVersion: 1,
        ),
      for (final split in splits)
        ChangeLogEntry(
          entityId: split.id,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'amountMinor': split.amountMinor,
            'categoryId': split.categoryId,
          }),
          schemaVersion: 1,
        ),
    ];
    return WritePlan(
      changes: changes,
      apply: () async {
        final updated = await _db.customUpdate(
          'UPDATE transactions SET updated_at = ?, revision = revision + 1, '
          'date = ?, amount_minor = ?, kind = ?, merchant_name = ?, note = ?, '
          'category_id = ? WHERE id = ? AND revision = ? '
          'AND deleted_at IS NULL',
          variables: [
            Variable(now),
            Variable(date),
            Variable(amountMinor),
            Variable(kind),
            Variable(merchantName),
            Variable(note),
            Variable(categoryId),
            Variable(id),
            Variable(expectedRevision),
          ],
        );
        if (updated == 0) {
          throw const PaymentError(PaymentErrorCode.staleRevision);
        }
        await _db.customStatement(
          'UPDATE transaction_splits SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE transaction_id = ? '
          'AND deleted_at IS NULL',
          [now, now, id],
        );
        for (final split in splits) {
          await _db.customStatement(
            'INSERT INTO transaction_splits (id, created_at, updated_at, '
            'deleted_at, revision, transaction_id, category_id, amount_minor, '
            'currency, note) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?)',
            [
              split.id,
              now,
              now,
              id,
              split.categoryId,
              split.amountMinor,
              currency,
              split.note,
            ],
          );
        }
        await _db.customStatement(
          'DELETE FROM transaction_tags WHERE transaction_id = ?',
          [id],
        );
        for (final tagId in tagIds) {
          await _db.customStatement(
            'INSERT INTO transaction_tags (transaction_id, tag_id) '
            'VALUES (?, ?)',
            [id, tagId],
          );
        }
        await _bumpAccountRevision(accountId);
      },
    );
  }

  /// P22 / SPEC 8.18: Undo of one confirmed payment creation.
  ///
  /// The command soft-deletes the event, the payment and its splits and keeps
  /// every identity. Dependency checks, Activity history and a repeated Undo
  /// belong to P29; this plan is the compensating write for one confirmed
  /// payment. A later authoritative record is not edited or deleted.
  Future<WritePlan> planUndoCreate({required String paymentId}) async {
    final payment = await _db.customSelect(
      'SELECT id, event_id, account_id, revision FROM transactions '
      'WHERE id = ? AND deleted_at IS NULL',
      variables: [Variable(paymentId)],
    ).getSingleOrNull();
    if (payment == null) {
      throw const PaymentError(PaymentErrorCode.unknownPayment);
    }
    final eventId = payment.data['event_id'] as String;
    final accountId = payment.data['account_id'] as String;
    final event = await _db.customSelect(
      'SELECT revision FROM financial_events WHERE id = ? '
      'AND deleted_at IS NULL',
      variables: [Variable(eventId)],
    ).getSingleOrNull();
    final liveSplits = await _db.customSelect(
      'SELECT id, revision FROM transaction_splits WHERE transaction_id = ? '
      'AND deleted_at IS NULL ORDER BY id',
      variables: [Variable(paymentId)],
    ).get();
    final now = _nowMs();
    final changes = <ChangeLogEntry>[
      if (event != null)
        ChangeLogEntry(
          entityId: eventId,
          fromRevision: event.data['revision'] as int,
          toRevision: (event.data['revision'] as int) + 1,
          changeKind: 'softDelete',
          beforeJson: '{"deleted":false}',
          afterJson: '{"deleted":true}',
          schemaVersion: 1,
        ),
      ChangeLogEntry(
        entityId: paymentId,
        fromRevision: payment.data['revision'] as int,
        toRevision: (payment.data['revision'] as int) + 1,
        changeKind: 'softDelete',
        beforeJson: '{"deleted":false}',
        afterJson: '{"deleted":true}',
        schemaVersion: 1,
      ),
      for (final split in liveSplits)
        ChangeLogEntry(
          entityId: split.data['id'] as String,
          fromRevision: split.data['revision'] as int,
          toRevision: (split.data['revision'] as int) + 1,
          changeKind: 'softDelete',
          beforeJson: '{"deleted":false}',
          afterJson: '{"deleted":true}',
          schemaVersion: 1,
        ),
    ];
    return WritePlan(
      changes: changes,
      apply: () async {
        if (event != null) {
          await _db.customStatement(
            'UPDATE financial_events SET deleted_at = ?, updated_at = ?, '
            'revision = revision + 1 WHERE id = ? AND deleted_at IS NULL',
            [now, now, eventId],
          );
        }
        await _db.customStatement(
          'UPDATE transactions SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ? AND deleted_at IS NULL',
          [now, now, paymentId],
        );
        await _db.customStatement(
          'UPDATE transaction_splits SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE transaction_id = ? '
          'AND deleted_at IS NULL',
          [now, now, paymentId],
        );
        await _bumpAccountRevision(accountId);
      },
    );
  }

  /// P27 / SPEC 8.18: Undo of a X39 delete.
  ///
  /// Restores one soft-deleted payment, its event and its splits. The
  /// identities are the original ones, so the day total, the category total
  /// and the balance return to their earlier values once (F08-C).
  Future<WritePlan> planRestore({required String paymentId}) async {
    final payment = await _db.customSelect(
      'SELECT id, event_id, account_id, revision FROM transactions '
      'WHERE id = ? AND deleted_at IS NOT NULL',
      variables: [Variable(paymentId)],
    ).getSingleOrNull();
    if (payment == null) {
      throw const PaymentError(PaymentErrorCode.unknownPayment);
    }
    final eventId = payment.data['event_id'] as String;
    final accountId = payment.data['account_id'] as String;
    final event = await _db.customSelect(
      'SELECT revision FROM financial_events WHERE id = ?',
      variables: [Variable(eventId)],
    ).getSingleOrNull();
    final splits = await _db.customSelect(
      'SELECT id, revision FROM transaction_splits WHERE transaction_id = ? '
      'AND deleted_at IS NOT NULL ORDER BY id',
      variables: [Variable(paymentId)],
    ).get();
    final now = _nowMs();
    final changes = <ChangeLogEntry>[
      if (event != null)
        ChangeLogEntry(
          entityId: eventId,
          fromRevision: event.data['revision'] as int,
          toRevision: (event.data['revision'] as int) + 1,
          changeKind: 'restore',
          beforeJson: '{"deleted":true}',
          afterJson: '{"deleted":false}',
          schemaVersion: 1,
        ),
      ChangeLogEntry(
        entityId: paymentId,
        fromRevision: payment.data['revision'] as int,
        toRevision: (payment.data['revision'] as int) + 1,
        changeKind: 'restore',
        beforeJson: '{"deleted":true}',
        afterJson: '{"deleted":false}',
        schemaVersion: 1,
      ),
      for (final split in splits)
        ChangeLogEntry(
          entityId: split.data['id'] as String,
          fromRevision: split.data['revision'] as int,
          toRevision: (split.data['revision'] as int) + 1,
          changeKind: 'restore',
          beforeJson: '{"deleted":true}',
          afterJson: '{"deleted":false}',
          schemaVersion: 1,
        ),
    ];
    return WritePlan(
      changes: changes,
      apply: () async {
        if (event != null) {
          await _db.customStatement(
            'UPDATE financial_events SET deleted_at = NULL, updated_at = ?, '
            'revision = revision + 1 WHERE id = ? AND deleted_at IS NOT NULL',
            [now, eventId],
          );
        }
        await _db.customStatement(
          'UPDATE transactions SET deleted_at = NULL, updated_at = ?, '
          'revision = revision + 1 WHERE id = ? AND deleted_at IS NOT NULL',
          [now, paymentId],
        );
        await _db.customStatement(
          'UPDATE transaction_splits SET deleted_at = NULL, updated_at = ?, '
          'revision = revision + 1 WHERE transaction_id = ? '
          'AND deleted_at IS NOT NULL',
          [now, paymentId],
        );
        await _bumpAccountRevision(accountId);
      },
    );
  }

  /// SPEC 8.16 / DATABASE_DESIGN 4.1: a soft delete keeps identity.
  WritePlan planSoftDelete({
    required String id,
    required int expectedRevision,
  }) {
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: id,
          fromRevision: expectedRevision,
          toRevision: expectedRevision + 1,
          changeKind: 'softDelete',
          beforeJson: '{"deleted":false}',
          afterJson: '{"deleted":true}',
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        final before = await _db.customSelect(
          'SELECT entity_id FROM change_log WHERE entity_id = ? LIMIT 1',
          variables: [Variable(id)],
        ).get();
        if (before.isEmpty) {
          throw StateError('Unknown payment');
        }
        await _db.customStatement(
          'UPDATE transactions SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ? AND deleted_at IS NULL',
          [now, now, id],
        );
      },
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

  String _eventType(String kind) => switch (kind) {
        'income' => 'income',
        'transfer' => 'transfer',
        'refund' => 'refund',
        'fee' => 'fee',
        _ => 'payment',
      };
}
