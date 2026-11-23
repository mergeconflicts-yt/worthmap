// P16 (SPEC 8.17; F05-C): obligations and settlement.
//
// 1,240 - 500 = 740. An over-allocation is rejected with the remaining amount
// and never clamped. A full settlement marks the obligation settled. A
// cross-currency settlement stays unavailable.

import 'dart:async';

import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/occurrences.dart';
import 'package:contour/data/repositories/settlements.dart';
import 'package:contour/data/repositories/write_plan.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _account = '00000000-0000-7000-8000-0000000000a1';
const String _seedReceipt = '00000000-0000-7000-8000-0000000000f2';
const String _event = '00000000-0000-7000-8000-0000000000e1';
const String _transaction = '00000000-0000-7000-8000-500000000001';
const String _transaction2 = '00000000-0000-7000-8000-500000000002';

String _uuid(String prefix, int n) =>
    '00000000-0000-7000-8000-$prefix${n.toString().padLeft(11, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late SettlementRepository settlements;
  var nowMs = 1700000000000;
  var operation = 0;

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
        return _uuid('a', operation);
      },
    );
    settlements = SettlementRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    operation = 0;
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
    await vault.database.customStatement(
      'INSERT INTO operation_intents (operation_id, command_type, '
      'payload_digest, payload_version, draft_id, submitted_at, state, '
      "state_version) VALUES (?, 'seed', randomblob(32), 1, NULL, 0, "
      "'committed', 1)",
      [_seedReceipt],
    );
    await vault.database.customStatement(
      'INSERT INTO operation_receipts (operation_id, commit_sequence, '
      "committed_at, result_version, result_json) VALUES (?, 1000, 0, 1, '{}')",
      [_seedReceipt],
    );
    await vault.database.customStatement(
      'INSERT INTO financial_events (id, created_at, updated_at, deleted_at, '
      'revision, event_type, date, operation_id, supersedes_event_id) '
      "VALUES (?, ?, ?, NULL, 1, 'payment', '2026-10-05', ?, NULL)",
      [_event, nowMs, nowMs, _seedReceipt],
    );
    for (final id in <String>[_transaction, _transaction2]) {
      await vault.database.customStatement(
        'INSERT INTO transactions (id, created_at, updated_at, deleted_at, '
        'revision, event_id, account_id, date, amount_minor, currency, kind, '
        'merchant_name, note, category_id, source, is_estimated) '
        "VALUES (?, ?, ?, NULL, 1, ?, ?, '2026-10-05', -124000, 'USD', "
        "'expense', NULL, NULL, NULL, 'manual', 0)",
        [id, nowMs, nowMs, _event, _account],
      );
    }
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<void> run(FutureOr<WritePlan> pending) async {
    final plan = await pending;
    final op = _uuid('b', operation);
    await commands.prepare(
      operationId: op,
      commandType: 'settlement.command',
      draftId: _uuid('c', operation),
      formType: 'settlement',
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

  Future<String> createObligation() async {
    final id = _uuid('d', 1);
    await run(
      settlements.planCreateObligation(
        id: id,
        date: '2026-10-25',
        direction: 'out',
        amountMinor: 124000,
        currency: 'USD',
        accountId: _account,
      ),
    );
    return id;
  }

  test('a 500 settlement leaves 740 unpaid', () async {
    final obligation = await createObligation();
    await run(
      settlements.planSettle(
        allocationId: _uuid('e', 1),
        obligationId: obligation,
        transactionId: _transaction,
        amountMinor: 50000,
        currency: 'USD',
      ),
    );
    expect(await settlements.unpaidMinor(obligation), 74000);
    final row = await settlements.obligation(obligation);
    expect(row!.status, 'open');
  });

  test('an over-allocation is rejected with the remaining amount', () async {
    final obligation = await createObligation();
    await run(
      settlements.planSettle(
        allocationId: _uuid('e', 2),
        obligationId: obligation,
        transactionId: _transaction,
        amountMinor: 50000,
        currency: 'USD',
      ),
    );
    final error = await settlements
        .planSettle(
          allocationId: _uuid('e', 20),
          obligationId: obligation,
          transactionId: _transaction2,
          amountMinor: 80000,
          currency: 'USD',
        )
        .then<Object?>((_) => null)
        .catchError((Object error) => error);
    expect(error, isA<ScheduleError>());
    expect(
      (error! as ScheduleError).code,
      ScheduleErrorCode.overAllocation,
    );
    expect((error as ScheduleError).remainingMinor, 74000);
    expect(await settlements.acceptedMinor(obligation), 50000);
    expect(await settlements.unpaidMinor(obligation), 74000);
  });

  test('a second allocation cannot exceed the remainder', () async {
    final obligation = await createObligation();
    await run(
      settlements.planSettle(
        allocationId: _uuid('e', 3),
        obligationId: obligation,
        transactionId: _transaction,
        amountMinor: 50000,
        currency: 'USD',
      ),
    );
    final error = await settlements
        .planSettle(
          allocationId: _uuid('e', 4),
          obligationId: obligation,
          transactionId: _transaction,
          amountMinor: 74001,
          currency: 'USD',
        )
        .then<Object?>((_) => null)
        .catchError((Object error) => error);
    expect(error, isA<ScheduleError>());
    expect((error as ScheduleError).remainingMinor, 74000);
  });

  test('a full settlement marks the obligation settled', () async {
    final obligation = await createObligation();
    await run(
      settlements.planSettle(
        allocationId: _uuid('e', 5),
        obligationId: obligation,
        transactionId: _transaction,
        amountMinor: 50000,
        currency: 'USD',
      ),
    );
    await run(
      settlements.planSettle(
        allocationId: _uuid('e', 6),
        obligationId: obligation,
        transactionId: _transaction2,
        amountMinor: 74000,
        currency: 'USD',
      ),
    );
    expect(await settlements.unpaidMinor(obligation), 0);
    final row = await settlements.obligation(obligation);
    expect(row!.status, 'settled');
    expect(row.revision, 2);
    final allocations = await vault.database.customSelect(
      'SELECT count(*) AS n FROM settlement_allocations '
      'WHERE obligation_id = ?',
      variables: [Variable(obligation)],
    ).getSingle();
    expect(allocations.data['n'], 2);
  });

  test('a settled obligation takes no further allocation', () async {
    final obligation = await createObligation();
    await run(
      settlements.planSettle(
        allocationId: _uuid('e', 7),
        obligationId: obligation,
        transactionId: _transaction,
        amountMinor: 124000,
        currency: 'USD',
      ),
    );
    final error = await settlements
        .planSettle(
          allocationId: _uuid('e', 8),
          obligationId: obligation,
          transactionId: _transaction,
          amountMinor: 1,
          currency: 'USD',
        )
        .then<Object?>((_) => null)
        .catchError((Object error) => error);
    expect(error, isA<ScheduleError>());
    expect(
      (error! as ScheduleError).code,
      ScheduleErrorCode.invalidTransition,
    );
  });

  test('a cross-currency settlement is unavailable', () async {
    final obligation = await createObligation();
    final error = await settlements
        .planSettle(
          allocationId: _uuid('e', 9),
          obligationId: obligation,
          transactionId: _transaction,
          amountMinor: 10000,
          currency: 'EUR',
        )
        .then<Object?>((_) => null)
        .catchError((Object error) => error);
    expect(error, isA<ScheduleError>());
    expect(
      (error! as ScheduleError).code,
      ScheduleErrorCode.invalidTransition,
    );
  });

  test('a larger payment keeps its unallocated part', () async {
    final obligation = await createObligation();
    // The payment is 1,240 but only 500 is allocated to this obligation.
    await run(
      settlements.planSettle(
        allocationId: _uuid('e', 10),
        obligationId: obligation,
        transactionId: _transaction,
        amountMinor: 50000,
        currency: 'USD',
      ),
    );
    final unpaid = await settlements.unpaidMinor(obligation);
    // The unallocated part stays outside the obligation; the remainder is
    // never zero silently.
    expect(unpaid, 74000);
    final allocation = await vault.database.customSelect(
      'SELECT amount_minor, transaction_id FROM settlement_allocations '
      'WHERE id = ?',
      variables: [Variable(_uuid('e', 10))],
    ).getSingle();
    expect(allocation.data['amount_minor'], 50000);
    expect(allocation.data['transaction_id'], _transaction);
  });
}
