import 'package:contour/app/accounts_gateway.dart';
import 'package:contour/app/transfer_draft_store.dart';
import 'package:contour/app/transfers_gateway.dart';
import 'package:contour/core/dates.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/accounts.dart';
import 'package:contour/data/repositories/drafts.dart';
import 'package:contour/data/repositories/transfers.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/add/transfer_form_controller.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

String _id(int n) =>
    '00000000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late SqlTransfersGateway gateway;
  late SqlTransferDraftStore draftStore;
  late TransferFormController controller;
  late AccountSummary checking;
  late AccountSummary card;
  var nextId = 500;
  final today = LocalDate(2026, 10, 13);
  const nowMs = 1700000000000;

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
    final accountGateway = SqlAccountsGateway(
      accounts: accounts,
      commands: commands,
      today: () => today,
      newId: () => _id(nextId++),
    );
    checking = await accountGateway.createAccount(
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
    card = await accountGateway.createAccount(
      AccountSetup(
        name: 'Visa card',
        kind: AccountKind.card,
        currencyCode: 'USD',
        openingBalanceMinor: 124000,
        openingDate: LocalDate(2026, 10, 12),
        countsAsCash: false,
        includeInNetWorth: true,
      ),
    );
    gateway = SqlTransfersGateway(
      accounts: accounts,
      transfers: TransferRepository(
        db: vault.database,
        clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      ),
      commands: commands,
      today: () => today,
      newId: () => _id(nextId++),
    );
    draftStore = SqlTransferDraftStore(
      drafts: DraftRepository(
        db: vault.database,
        clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      ),
      newId: () => _id(nextId++),
    );
    controller = TransferFormController(
      gateway: gateway,
      today: today,
      drafts: draftStore,
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    await commands.dispose();
    await vault.close();
  });

  Future<int> count(String sql) async {
    final row = await vault.database.customSelect(sql).getSingle();
    return row.data.values.first! as int;
  }

  Future<int?> balanceOf(String accountId) async {
    final listed = (await gateway.loadForm())
        .accounts
        .firstWhere((account) => account.id == accountId);
    return listed.balanceMinor;
  }

  test('the card shows what it owes and the form picks both accounts',
      () async {
    final cardRow = (await gateway.loadForm())
        .accounts
        .firstWhere((account) => account.id == card.id);

    expect(cardRow.balanceMinor, -124000);
    expect(cardRow.owes, isTrue);
    expect(controller.from?.id, checking.id);
    expect(controller.to?.id, card.id);
  });

  test('one Save transfer writes two principals, one link and the event',
      () async {
    for (final key in '1240'.split('')) {
      controller.pressKey(key);
    }

    final saved = await controller.save();
    expect(saved, isNotNull, reason: '${controller.errorCode}');

    expect(await count('SELECT count(*) FROM financial_events'), 1);
    expect(await count('SELECT count(*) FROM transactions'), 2);
    expect(await count('SELECT count(*) FROM transfer_links'), 1);
    expect(
      await count(
        "SELECT count(*) FROM transactions WHERE kind = 'fee' "
        'AND deleted_at IS NULL',
      ),
      0,
      reason: 'X26 has no fee field in Phase 2',
    );

    final signed = await vault.database
        .customSelect(
          'SELECT sum(amount_minor) AS total FROM transactions '
          'WHERE deleted_at IS NULL',
        )
        .getSingle();
    expect(
      signed.data['total'],
      0,
      reason: 'the principal is neither income nor spending (F05-A)',
    );

    expect(await balanceOf(checking.id), 645000 - 124000);
    expect(await balanceOf(card.id), 0, reason: 'the card is paid off');

    final logged = await vault.database.customSelect(
      'SELECT count(*) AS n FROM change_log WHERE operation_id = ?',
      variables: [Variable(saved!.operationId)],
    ).getSingle();
    expect(logged.data['n'], 4, reason: 'event, two postings and the link');
    expect(controller.hasDraft, isFalse);
    final draft = await vault.database
        .customSelect(
          "SELECT status FROM draft_headers WHERE form_type = 'transfer'",
        )
        .getSingle();
    expect(draft.data['status'], 'committed');
  });

  test('Undo soft-deletes the event, both sides and the link', () async {
    for (final key in '1240'.split('')) {
      controller.pressKey(key);
    }
    final saved = await controller.save();
    expect(saved, isNotNull, reason: '${controller.errorCode}');

    await gateway.undoTransfer(saved!);

    expect(await balanceOf(checking.id), 645000);
    expect(await balanceOf(card.id), -124000);
    expect(
      await count('SELECT count(*) FROM transactions WHERE deleted_at IS NULL'),
      0,
    );
    expect(
      await count(
        'SELECT count(*) FROM transfer_links WHERE deleted_at IS NULL',
      ),
      0,
    );
    expect(
      await count('SELECT count(*) FROM transactions'),
      2,
      reason: 'soft delete keeps every identity',
    );
  });
}
