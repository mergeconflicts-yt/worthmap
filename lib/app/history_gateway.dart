// P29 (SPEC 8.18): the app composition for the activity history.
//
// The adapter reads operation receipts and maps four command families to their
// compensating command: payment create, transfer create, payment delete and an
// Inbox batch. A settings, category or rule change is listed as a change with
// no Undo. A dependency block is not evaluated here (P29-HISTORY-BLOCKED).
library;

import 'dart:convert';

import '../data/db/command_repository.dart';
import '../data/repositories/history.dart';
import '../data/repositories/inbox.dart';
import '../data/repositories/payments.dart';
import '../data/repositories/transfers.dart';
import '../data/repositories/write_plan.dart';
import '../features/history/history_models.dart';

/// The P29 history adapter.
final class SqlHistoryGateway implements HistoryGateway {
  SqlHistoryGateway({
    required this.history,
    required this.payments,
    required this.transfers,
    required this.inbox,
    required this.commands,
    required this.newId,
  });

  final HistoryRepository history;
  final PaymentRepository payments;
  final TransferRepository transfers;
  final InboxRepository inbox;
  final CommandRepository commands;
  final String Function() newId;

  @override
  Future<List<HistoryEntry>> load() async {
    final rows = await history.list();
    final entries = <HistoryEntry>[];
    for (final row in rows) {
      final state = await _state(row);
      entries.add(
        HistoryEntry(
          operationId: row.operationId,
          commandType: row.commandType,
          committedAtMs: row.committedAtMs,
          state: state,
        ),
      );
    }
    return entries;
  }

  Future<HistoryEntryState> _state(HistoryOperationRow row) async {
    final json = _result(row.resultJson);
    switch (row.commandType) {
      case 'payment.create':
        final id = json['payment'] as String?;
        if (id == null || id.isEmpty) {
          return HistoryEntryState.change;
        }
        return await history.paymentDeleted(id)
            ? HistoryEntryState.reversed
            : HistoryEntryState.reversible;
      case 'transfer.create':
        final id = json['event'] as String?;
        if (id == null || id.isEmpty) {
          return HistoryEntryState.change;
        }
        return await history.eventDeleted(id)
            ? HistoryEntryState.reversed
            : HistoryEntryState.reversible;
      case 'payment.delete':
        final id = json['payment'] as String?;
        if (id == null || id.isEmpty) {
          return HistoryEntryState.change;
        }
        return await history.paymentDeleted(id)
            ? HistoryEntryState.reversible
            : HistoryEntryState.reversed;
      case 'inbox.confirm':
        return row.compensated
            ? HistoryEntryState.reversed
            : HistoryEntryState.reversible;
      default:
        return HistoryEntryState.change;
    }
  }

  @override
  Future<bool> undo(HistoryEntry entry) async {
    try {
      switch (entry.commandType) {
        case 'payment.create':
        case 'payment.delete':
          final rows = await history.list(limit: 200);
          final row = rows.firstWhere(
            (item) => item.operationId == entry.operationId,
          );
          final id = _result(row.resultJson)['payment'] as String?;
          if (id == null || id.isEmpty) {
            return false;
          }
          final plan = entry.commandType == 'payment.create'
              ? await payments.planUndoCreate(paymentId: id)
              : await payments.planRestore(paymentId: id);
          await _run(
            commandType: entry.commandType == 'payment.create'
                ? 'payment.undo'
                : 'payment.restore',
            plan: plan,
          );
          return true;
        case 'transfer.create':
          final rows = await history.list(limit: 200);
          final row = rows.firstWhere(
            (item) => item.operationId == entry.operationId,
          );
          final id = _result(row.resultJson)['event'] as String?;
          if (id == null || id.isEmpty) {
            return false;
          }
          final plan = await transfers.planUndoCreate(eventId: id);
          await _run(commandType: 'transfer.undo', plan: plan);
          return true;
        case 'inbox.confirm':
          await inbox.undoBatch(
            operationId: newId(),
            originalOperationId: entry.operationId,
          );
          return true;
        default:
          return false;
      }
    } on Object {
      return false;
    }
  }

  Future<void> _run({
    required String commandType,
    required WritePlan plan,
  }) async {
    final operationId = newId();
    await commands.prepare(
      operationId: operationId,
      commandType: commandType,
      draftId: newId(),
      formType: 'historyUndo',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    await commands.execute(
      operationId: operationId,
      changes: plan.changes,
      effects: plan.apply,
      resultJson: '{}',
    );
  }

  Map<String, Object?> _result(String json) {
    try {
      final parsed = jsonDecode(json);
      if (parsed is Map) {
        return Map<String, Object?>.from(parsed);
      }
    } on FormatException {
      // A receipt without fields is not reversible.
    }
    return const <String, Object?>{};
  }
}
