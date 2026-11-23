import 'package:contour/app/accounts_gateway.dart';
import 'package:contour/core/dates.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/accounts.dart';
import 'package:contour/data/repositories/transfers.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

String _id(int n) =>
    '00000000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late TransferRepository transfers;
  late AccountSummary checking;
  late AccountSummary savings;
  var nextId = 700;
  const nowMs = 1700000000000;
  final today = LocalDate(2026, 10, 13);

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    await vault.database.customStatement(
      "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newOperationId: () => _id(nextId++),
    );
    final accounts = AccountRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    final gateway = SqlAccountsGateway(
      accounts: accounts,
      commands: commands,
      today: () => today,
      newId: () => _id(nextId++),
    );
    checking = await gateway.createAccount(
      AccountSetup(
        name: 'Checking',
        kind: AccountKind.bank,
        currencyCode: 'USD',
        openingBalanceMinor: 645000,
        openingDate: LocalDate(2026, 10, 12),
        countsAsCash: true,
        includeInNetWorth: true,
      ),
    );
    savings = await gateway.createAccount(
      AccountSetup(
        name: 'Savings',
        kind: AccountKind.bank,
        currencyCode: 'USD',
        openingBalanceMinor: 100000,
        openingDate: LocalDate(2026, 10, 12),
        countsAsCash: true,
        includeInNetWorth: true,
      ),
    );
    transfers = TransferRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<void> run(NewTransfer transfer) async {
    final plan = transfers.planCreate(transfer);
    final operationId = _id(nextId++);
    await commands.prepare(
      operationId: operationId,
      commandType: 'transfer.create',
      draftId: _id(nextId++),
      formType: 'transfer',
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

  NewTransfer transfer({String? feeId, int? feeMinor}) => NewTransfer(
        eventId: _id(nextId++),
        linkId: _id(nextId++),
        sendingId: _id(nextId++),
        receivingId: _id(nextId++),
        fromAccountId: checking.id,
        toAccountId: savings.id,
        date: '2026-10-13',
        amountMinor: 50000,
        currency: 'USD',
        feeId: feeId,
        feeMinor: feeMinor,
      );

  test('one charged fee posts once on the sending account (F05-D)', () async {
    await run(transfer(feeId: _id(nextId++), feeMinor: 1200));

    final rows = await vault.database
        .customSelect(
          'SELECT kind, account_id, amount_minor FROM transactions '
          'WHERE deleted_at IS NULL ORDER BY kind',
        )
        .get();
    expect(rows.length, 3);
    final fee = rows.firstWhere((row) => row.data['kind'] == 'fee');
    expect(fee.data['amount_minor'], -1200);
    expect(fee.data['account_id'], checking.id);
    final link = await vault.database
        .customSelect(
          'SELECT fee_transaction_id FROM transfer_links WHERE deleted_at IS NULL',
        )
        .getSingle();
    expect(link.data['fee_transaction_id'], isNotNull);
  });

  test('a transfer must move a positive amount between two accounts', () {
    expect(
      () => transfers.planCreate(
        NewTransfer(
          eventId: _id(nextId++),
          linkId: _id(nextId++),
          sendingId: _id(nextId++),
          receivingId: _id(nextId++),
          fromAccountId: checking.id,
          toAccountId: checking.id,
          date: '2026-10-13',
          amountMinor: 100,
          currency: 'USD',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => transfers.planCreate(
        NewTransfer(
          eventId: _id(nextId++),
          linkId: _id(nextId++),
          sendingId: _id(nextId++),
          receivingId: _id(nextId++),
          fromAccountId: checking.id,
          toAccountId: savings.id,
          date: '2026-10-13',
          amountMinor: 0,
          currency: 'USD',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('an unknown event cannot be undone', () async {
    expect(
      () => transfers.planUndoCreate(eventId: _id(nextId++)),
      throwsA(isA<TransferWriteError>()),
    );
  });
}
