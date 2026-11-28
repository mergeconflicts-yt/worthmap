// P23 (flow F05; SPEC 8.16, 8.18): the app composition for the transfer form.
//
// This is the only adapter between the transfer feature port and the data
// layer. It holds no state and logs nothing (AGENTS 2.6). One Save is one
// command on the single writer: an intent, a receipt, the event, both
// principals, the link, ChangeLog rows and, when a draft exists, the sealed
// draft (P13).
//
// A typed failure resolves through the receipt first (a lost reply is a
// success), then releases the uncommitted attempt so the next Save allocates a
// new operation id (P13-DRAFTS).
library;

import 'dart:convert';
import 'dart:math';

import '../core/dates.dart';
import '../core/ids.dart';
import '../data/db/command_repository.dart';
import '../data/repositories/accounts.dart';
import '../data/repositories/transfers.dart';
import '../features/accounts/account_models.dart';
import '../features/add/transfer_models.dart';

/// P23 + P14 + the single command writer behind the transfer port.
final class SqlTransfersGateway implements TransferGateway {
  SqlTransfersGateway({
    required this.accounts,
    required this.transfers,
    required this.commands,
    required this.today,
    required this.newId,
  });

  final AccountRepository accounts;
  final TransferRepository transfers;
  final CommandRepository commands;

  /// The cut-off for a listed balance and the default transfer date.
  final LocalDate Function() today;

  /// A UUID v7 source. The app boundary supplies the clock and randomness.
  final String Function() newId;

  @override
  Future<TransferFormData> loadForm() async {
    final asOf = today().toString();
    final rows = await accounts.list();
    final accountRows = <AccountSummary>[
      for (final row in rows)
        AccountSummary(
          id: row.id,
          name: row.name,
          kind: _kind(row.type),
          currencyCode: row.currency,
          balanceMinor: await _balance(row.id, asOf),
        ),
    ];
    return TransferFormData(
      accounts: accountRows,
      currencyCode:
          accountRows.isEmpty ? 'USD' : accountRows.first.currencyCode,
    );
  }

  @override
  Future<SavedTransfer> saveTransfer({
    required TransferSetup setup,
    String? draftId,
    String? payloadJson,
  }) async {
    if (draftId != null) {
      final committed = await commands.committedOutcomeOf(draftId);
      if (committed != null) {
        return _saved(committed, setup);
      }
    }
    final eventId = newId();
    final sendingId = newId();
    final receivingId = newId();
    final plan = transfers.planCreate(
      NewTransfer(
        eventId: eventId,
        linkId: newId(),
        sendingId: sendingId,
        receivingId: receivingId,
        fromAccountId: setup.fromAccountId,
        toAccountId: setup.toAccountId,
        date: setup.date.toString(),
        amountMinor: setup.amountMinor,
        currency: setup.currencyCode,
        note: setup.note,
      ),
    );
    final resultJson = jsonEncode(<String, Object?>{
      'event': eventId,
      'sending': sendingId,
      'receiving': receivingId,
    });
    final operationId = newId();
    try {
      if (draftId != null && payloadJson != null) {
        final outcome = await commands.saveDraft(
          draftId: draftId,
          commandType: 'transfer.create',
          payloadJson: payloadJson,
          payloadVersion: 1,
          codecVersion: 1,
          changes: plan.changes,
          effects: plan.apply,
          resultJson: resultJson,
        );
        return _saved(outcome, setup);
      }
      await commands.prepare(
        operationId: operationId,
        commandType: 'transfer.create',
        draftId: newId(),
        formType: 'transfer',
        payloadJson: payloadJson ?? '{"v":1}',
        payloadVersion: 1,
        codecVersion: 1,
        schemaVersion: 1,
      );
      final outcome = await commands.execute(
        operationId: operationId,
        changes: plan.changes,
        effects: plan.apply,
        resultJson: resultJson,
      );
      return _saved(outcome, setup);
    } on Object {
      final resolved = draftId == null
          ? await _resolveWithoutDraft(operationId)
          : await _resolveDraft(draftId);
      if (resolved != null) {
        return _saved(resolved, setup);
      }
      throw const TransferFormError(TransferErrorCode.saveFailed);
    }
  }

  @override
  Future<void> undoTransfer(SavedTransfer saved) async {
    final plan = await transfers.planUndoCreate(eventId: saved.eventId);
    final operationId = newId();
    await commands.prepare(
      operationId: operationId,
      commandType: 'transfer.undo',
      draftId: newId(),
      formType: 'transferUndo',
      payloadJson: jsonEncode(<String, Object?>{'undoOf': saved.operationId}),
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    try {
      await commands.execute(
        operationId: operationId,
        changes: plan.changes,
        effects: plan.apply,
        resultJson: '{}',
      );
    } on Object {
      final receipt = await commands.receiptOf(operationId);
      if (receipt == null) {
        throw const TransferFormError(TransferErrorCode.undoFailed);
      }
    }
  }

  SavedTransfer _saved(CommandOutcome outcome, TransferSetup setup) {
    String? eventId;
    String? sendingId;
    String? receivingId;
    try {
      final result = jsonDecode(outcome.resultJson);
      if (result is Map<String, Object?>) {
        eventId = result['event'] as String?;
        sendingId = result['sending'] as String?;
        receivingId = result['receiving'] as String?;
      }
    } on FormatException {
      // A receipt without fields still names the committed operation.
    }
    return SavedTransfer(
      eventId: eventId ?? '',
      sendingId: sendingId ?? '',
      receivingId: receivingId ?? '',
      operationId: outcome.operationId,
      amountMinor: setup.amountMinor,
      currencyCode: setup.currencyCode,
      date: setup.date,
    );
  }

  Future<CommandOutcome?> _resolveDraft(String draftId) async {
    final operationId = await commands.activeOperationId(draftId);
    if (operationId == null) {
      return null;
    }
    final receipt = await commands.receiptOf(operationId);
    if (receipt != null) {
      return receipt;
    }
    try {
      await commands.releaseUncommitted(operationId);
    } on Object {
      // A concurrent commit is resolved by the next receipt read.
    }
    return commands.receiptOf(operationId);
  }

  Future<CommandOutcome?> _resolveWithoutDraft(String operationId) async {
    final receipt = await commands.receiptOf(operationId);
    if (receipt != null) {
      return receipt;
    }
    try {
      await commands.releaseUncommitted(operationId);
    } on Object {
      // Nothing to release; the Save failed before an intent existed.
    }
    return null;
  }

  Future<int?> _balance(String accountId, String asOf) async {
    final balance = await accounts.balanceAt(accountId: accountId, asOf: asOf);
    return switch (balance) {
      KnownBalance(:final amount) => amount.minor,
      MissingBalance() => null,
    };
  }

  static AccountKind _kind(String type) => AccountKind.fromDatabase(type);
}

/// A UUID v7 from the wall clock and secure randomness, for the app boundary.
String newTransferId() {
  final now = DateTime.now().toUtc();
  final random = Random.secure();
  return UuidV7.generate(
    unixMillis: now.millisecondsSinceEpoch,
    randomBytes: List<int>.generate(10, (_) => random.nextInt(256)),
  ).toString();
}
