// P3-18 (SPEC 8.6; DECISIONS P3-BALANCE-ROWS; G01-A..E): statement balance
// observations.
//
// A statement's opening or closing balance row is an observation, never a
// payment. Recording one writes an immutable inclusive `balance_anchors` row
// with `source = 'imported'`, selects it through `current_balance_anchors` and
// writes one ChangeLog entry, all in one command transaction.
//
// The rules (SPEC 8.6):
//   - a row dated before the selected anchor is already covered: no write;
//   - the same date and amount is already covered: no write;
//   - the same date with another amount is a correction: a new anchor with
//     `supersedes_anchor_id`, and the pointer moves;
//   - a later date is a new observation for that date.
//
// The row is the balance at the end of its local date, inclusive. The P14
// read adds only postings dated after the anchor date (G01-B). Amounts are
// integer minor units, signed; the row never writes a payment.
//
// The account, date, amount and currency stay inside the vault. Errors carry
// safe codes only, and nothing is logged (AGENTS 2.6).
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../db/app_database.dart';
import '../db/command_repository.dart';

/// Safe statement-balance failure codes.
enum ImportBalanceErrorCode {
  accountNotFound,
  currencyMismatch,
  replayMismatch,
  invalidResult,
}

/// A typed statement-balance failure. It holds a code only.
class ImportBalanceError implements Exception {
  const ImportBalanceError(this.code);

  final ImportBalanceErrorCode code;

  @override
  String toString() => 'ImportBalanceError(${code.name})';
}

/// The outcome of recording one statement balance row.
sealed class StatementBalanceResult {
  const StatementBalanceResult({
    required this.anchorId,
    required this.date,
    required this.balanceMinor,
    required this.currency,
  });

  /// The written anchor, or the selected anchor that already covers the row.
  final String anchorId;

  /// The row's local calendar date.
  final LocalDate date;

  final int balanceMinor;
  final String currency;
}

/// A new anchor was written and selected.
final class RecordedStatementBalance extends StatementBalanceResult {
  const RecordedStatementBalance({
    required super.anchorId,
    required super.date,
    required super.balanceMinor,
    required super.currency,
    required this.supersededAnchorId,
  });

  /// The previous selected anchor for the same date, or null.
  final String? supersededAnchorId;
}

/// The selected anchor already covers the row; nothing was written.
final class CoveredStatementBalance extends StatementBalanceResult {
  const CoveredStatementBalance({
    required super.anchorId,
    required super.date,
    required super.balanceMinor,
    required super.currency,
  });
}

/// One selected anchor.
final class _SelectedAnchor {
  const _SelectedAnchor({
    required this.anchorId,
    required this.date,
    required this.balanceMinor,
  });

  final String anchorId;
  final LocalDate date;
  final int balanceMinor;
}

/// Writes statement balance observations through the P14 account path.
final class ImportBalanceRepository {
  ImportBalanceRepository({
    required AppDatabase db,
    required CommandRepository commands,
    required DateTime Function() clockUtc,
    String Function()? newEntityId,
  })  : _db = db,
        _commands = commands,
        _clockUtc = clockUtc,
        _newEntityId = newEntityId;

  final AppDatabase _db;
  final CommandRepository _commands;
  final DateTime Function() _clockUtc;
  final String Function()? _newEntityId;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  String _nextId() {
    final injected = _newEntityId;
    if (injected != null) return injected();
    final random = Random.secure();
    final bytes = List<int>.generate(10, (_) => random.nextInt(256));
    return UuidV7.generate(
      unixMillis: _clockUtc().millisecondsSinceEpoch,
      randomBytes: bytes,
    ).toString();
  }

  /// Records one statement balance row as an anchor observation.
  ///
  /// [operationId] is the confirmed command identity; a retry returns the
  /// recorded result. A covered row returns [CoveredStatementBalance] and
  /// writes no command, anchor or ChangeLog entry.
  Future<StatementBalanceResult> record({
    required String operationId,
    required String accountId,
    required LocalDate date,
    required int balanceMinor,
    required String currency,
    int? sourceIdentityId,
  }) async {
    final existing = await _commands.receiptOf(operationId);
    if (existing != null) {
      return _fromReceipt(
        existing,
        accountId: accountId,
        date: date,
        balanceMinor: balanceMinor,
        currency: currency,
        sourceIdentityId: sourceIdentityId,
      );
    }

    final account = await _db.customSelect(
      'SELECT currency FROM accounts WHERE id = ? AND deleted_at IS NULL',
      variables: <Variable<Object>>[Variable<String>(accountId)],
    ).getSingleOrNull();
    if (account == null) {
      throw const ImportBalanceError(ImportBalanceErrorCode.accountNotFound);
    }
    if (account.data['currency'] != currency) {
      throw const ImportBalanceError(ImportBalanceErrorCode.currencyMismatch);
    }

    final selected = await _selectedAnchor(accountId);
    if (selected != null) {
      final order = date.compareTo(selected.date);
      if (order < 0 || (order == 0 && balanceMinor == selected.balanceMinor)) {
        return CoveredStatementBalance(
          anchorId: selected.anchorId,
          date: selected.date,
          balanceMinor: selected.balanceMinor,
          currency: currency,
        );
      }
    }
    final supersedes = selected != null && date.compareTo(selected.date) == 0
        ? selected.anchorId
        : null;

    final anchorId = _nextId();
    final draftId = _nextId();
    final resultJson = jsonEncode(<String, Object?>{
      'kind': 'import.recordStatementBalance',
      'accountId': accountId,
      'anchorId': anchorId,
      'date': date.toString(),
      'balanceMinor': balanceMinor,
      'currency': currency,
      'sourceIdentityId': sourceIdentityId,
      'supersededAnchorId': supersedes,
    });

    await _commands.prepare(
      operationId: operationId,
      commandType: 'import.recordStatementBalance',
      draftId: draftId,
      formType: 'importBalance',
      payloadJson: jsonEncode(<String, Object?>{
        'v': 1,
        'kind': 'import.recordStatementBalance',
        'accountId': accountId,
        'date': date.toString(),
        'balanceMinor': balanceMinor,
        'currency': currency,
        'sourceIdentityId': sourceIdentityId,
        'supersedesAnchorId': supersedes,
      }),
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );

    final outcome = await _commands.execute(
      operationId: operationId,
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: anchorId,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'date': date.toString(),
            'balanceMinor': balanceMinor,
            'currency': currency,
            'supersedesAnchorId': supersedes,
          }),
          schemaVersion: 1,
        ),
      ],
      effects: () => _apply(
        accountId: accountId,
        anchorId: anchorId,
        date: date,
        balanceMinor: balanceMinor,
        currency: currency,
        sourceIdentityId: sourceIdentityId,
        supersedesAnchorId: supersedes,
        operationId: operationId,
      ),
      resultJson: resultJson,
    );
    return _fromOutcome(outcome, date, balanceMinor, currency, supersedes);
  }

  Future<_SelectedAnchor?> _selectedAnchor(String accountId) async {
    final row = await _db.customSelect(
      'SELECT a.id AS anchor_id, a.date, a.balance_minor '
      'FROM current_balance_anchors c '
      'JOIN balance_anchors a ON a.id = c.anchor_id '
      'WHERE c.account_id = ?',
      variables: <Variable<Object>>[Variable<String>(accountId)],
    ).getSingleOrNull();
    if (row == null) return null;
    final date = LocalDate.tryParse(row.data['date'] as String);
    if (date == null) {
      throw const ImportBalanceError(ImportBalanceErrorCode.invalidResult);
    }
    return _SelectedAnchor(
      anchorId: row.data['anchor_id'] as String,
      date: date,
      balanceMinor: row.data['balance_minor'] as int,
    );
  }

  Future<void> _apply({
    required String accountId,
    required String anchorId,
    required LocalDate date,
    required int balanceMinor,
    required String currency,
    required int? sourceIdentityId,
    required String? supersedesAnchorId,
    required String operationId,
  }) async {
    final now = _nowMs();
    await _db.customStatement(
      'INSERT INTO balance_anchors (id, created_at, updated_at, deleted_at, '
      'revision, account_id, date, balance_minor, currency, source, '
      'source_identity_id, inclusive, supersedes_anchor_id) '
      "VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, 'imported', ?, 1, ?)",
      <Object?>[
        anchorId,
        now,
        now,
        accountId,
        date.toString(),
        balanceMinor,
        currency,
        sourceIdentityId,
        supersedesAnchorId,
      ],
    );
    await _db.customStatement(
      'DELETE FROM current_balance_anchors WHERE account_id = ?',
      <Object?>[accountId],
    );
    await _db.customStatement(
      'INSERT INTO current_balance_anchors (account_id, anchor_id, '
      'selected_operation_id) VALUES (?, ?, ?)',
      <Object?>[accountId, anchorId, operationId],
    );
    await _db.customStatement(
      'INSERT INTO dependency_scopes (kind, scope_key) '
      'SELECT ?, ? WHERE NOT EXISTS (SELECT 1 FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      <Object?>['account', accountId, 'account', accountId],
    );
    await _db.customStatement(
      'UPDATE dependency_revisions SET revision = revision + 1 '
      'WHERE scope_id = (SELECT id FROM dependency_scopes '
      'WHERE kind = ? AND scope_key = ?)',
      <Object?>['account', accountId],
    );
    await _db.customStatement(
      'INSERT INTO dependency_revisions (scope_id, revision) '
      'SELECT id, 1 FROM dependency_scopes WHERE kind = ? AND scope_key = ? '
      'AND NOT EXISTS (SELECT 1 FROM dependency_revisions '
      'WHERE scope_id = dependency_scopes.id)',
      <Object?>['account', accountId],
    );
  }

  RecordedStatementBalance _fromOutcome(
    CommandOutcome outcome,
    LocalDate date,
    int balanceMinor,
    String currency,
    String? supersededAnchorId,
  ) {
    final decoded = jsonDecode(outcome.resultJson);
    if (decoded is! Map) {
      throw const ImportBalanceError(ImportBalanceErrorCode.invalidResult);
    }
    final anchorId = decoded['anchorId'];
    if (decoded['kind'] != 'import.recordStatementBalance' ||
        anchorId is! String ||
        anchorId.isEmpty) {
      throw const ImportBalanceError(ImportBalanceErrorCode.invalidResult);
    }
    return RecordedStatementBalance(
      anchorId: anchorId,
      date: date,
      balanceMinor: balanceMinor,
      currency: currency,
      supersededAnchorId: supersededAnchorId,
    );
  }

  StatementBalanceResult _fromReceipt(
    CommandOutcome outcome, {
    required String accountId,
    required LocalDate date,
    required int balanceMinor,
    required String currency,
    required int? sourceIdentityId,
  }) {
    final decoded = jsonDecode(outcome.resultJson);
    if (decoded is! Map) {
      throw const ImportBalanceError(ImportBalanceErrorCode.invalidResult);
    }
    final anchorId = decoded['anchorId'];
    final storedDate = decoded['date'];
    final storedMinor = decoded['balanceMinor'];
    final storedCurrency = decoded['currency'];
    final storedAccount = decoded['accountId'];
    final storedSource = decoded['sourceIdentityId'];
    final superseded = decoded['supersededAnchorId'];
    final parsed = storedDate is String ? LocalDate.tryParse(storedDate) : null;
    if (decoded['kind'] != 'import.recordStatementBalance' ||
        anchorId is! String ||
        anchorId.isEmpty ||
        parsed == null ||
        storedMinor is! int ||
        storedCurrency is! String ||
        storedAccount is! String ||
        (storedSource != null && storedSource is! int) ||
        (superseded != null && superseded is! String)) {
      throw const ImportBalanceError(ImportBalanceErrorCode.invalidResult);
    }
    if (storedAccount != accountId ||
        parsed != date ||
        storedMinor != balanceMinor ||
        storedCurrency != currency ||
        storedSource != sourceIdentityId) {
      throw const ImportBalanceError(ImportBalanceErrorCode.replayMismatch);
    }
    return RecordedStatementBalance(
      anchorId: anchorId,
      date: parsed,
      balanceMinor: storedMinor,
      currency: storedCurrency,
      supersededAnchorId: superseded as String?,
    );
  }
}
