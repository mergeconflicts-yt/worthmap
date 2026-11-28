import 'dart:convert';

import 'package:contour/app/accounts_gateway.dart';
import 'package:contour/core/dates.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/accounts.dart';
import 'package:contour/domain/values/value_projection.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/accounts/account_setup_controller.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

String _id(int n) =>
    '00000000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late AccountRepository repository;
  late SqlAccountsGateway gateway;
  var nextId = 100;
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
      newOperationId: () => _id(80 + operation++),
    );
    repository = AccountRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    gateway = SqlAccountsGateway(
      accounts: repository,
      commands: commands,
      today: () => LocalDate(2026, 10, 13),
      newId: () => _id(nextId++),
    );
    await vault.database.customStatement(
      "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
    );
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<AccountSummary> save(
    AccountSetupController controller,
  ) async {
    final account = await controller.save();
    expect(account, isNotNull, reason: '${controller.errorCode}');
    return account!;
  }

  test('one save writes the account, the inclusive anchor and ChangeLog',
      () async {
    final controller = AccountSetupController(
      gateway: gateway,
      today: LocalDate(2026, 10, 13),
      kind: AccountKind.bank,
    )
      ..setName('Checking')
      ..setDate(LocalDate(2026, 10, 13));
    for (final key in <String>['6', '4', '5', '0']) {
      controller.pressKey(key);
    }
    final saved = await save(controller);

    expect(saved.name, 'Checking');
    expect(saved.balanceMinor, 645000);
    expect(saved.owes, isFalse);

    final accounts = await gateway.listAccounts();
    expect(accounts, hasLength(1));
    expect(accounts.single.name, 'Checking');
    expect(accounts.single.balanceMinor, 645000);

    final counts = await vault.database
        .customSelect(
          'SELECT (SELECT count(*) FROM accounts) AS accounts, '
          '(SELECT count(*) FROM balance_anchors) AS anchors, '
          '(SELECT count(*) FROM current_balance_anchors) AS selected, '
          '(SELECT count(*) FROM change_log) AS changes',
        )
        .getSingle();
    expect(counts.data['accounts'], 1);
    expect(counts.data['anchors'], 1);
    expect(counts.data['selected'], 1);
    expect(counts.data['changes'], 2);
  });

  test('an entered zero is a real anchor, not Missing', () async {
    final controller = AccountSetupController(
      gateway: gateway,
      today: LocalDate(2026, 10, 13),
      kind: AccountKind.cash,
    )
      ..setName('Wallet')
      ..pressKey('0');
    final saved = await save(controller);
    expect(saved.balanceMinor, 0);
    expect((await gateway.listAccounts()).single.balanceMinor, 0);
  });

  test('a card stores a liability and shows the owed amount', () async {
    final controller = AccountSetupController(
      gateway: gateway,
      today: LocalDate(2026, 10, 13),
      kind: AccountKind.card,
    )..setName('Visa');
    for (final key in <String>['1', '2', '4', '0']) {
      controller.pressKey(key);
    }
    final saved = await save(controller);
    expect(saved.balanceMinor, -124000);
    expect(saved.owes, isTrue);
    expect(saved.balance!.minor, -124000);

    final listed = (await gateway.listAccounts()).single;
    expect(listed.balanceMinor, -124000);
    expect(listed.owes, isTrue);
  });

  test('a posting on the anchor date is not added twice', () async {
    final controller = AccountSetupController(
      gateway: gateway,
      today: LocalDate(2026, 10, 13),
      kind: AccountKind.bank,
    )
      ..setName('Checking')
      ..setDate(LocalDate(2026, 10, 13));
    for (final key in <String>['6', '4', '5', '0']) {
      controller.pressKey(key);
    }
    final saved = await save(controller);
    final seedReceipt = _id(900);
    await vault.database.customStatement(
      'INSERT INTO operation_intents (operation_id, command_type, '
      'payload_digest, payload_version, draft_id, submitted_at, state, '
      "state_version) VALUES (?, 'seed', randomblob(32), 1, NULL, 0, "
      "'committed', 1)",
      [seedReceipt],
    );
    await vault.database.customStatement(
      'INSERT INTO operation_receipts (operation_id, commit_sequence, '
      "committed_at, result_version, result_json) VALUES (?, 1000, 0, 1, '{}')",
      [seedReceipt],
    );
    await vault.database.customStatement(
      'INSERT INTO financial_events (id, created_at, updated_at, deleted_at, '
      'revision, event_type, date, operation_id, supersedes_event_id) '
      "VALUES (?, ?, ?, NULL, 1, 'payment', '2026-10-13', ?, NULL)",
      [_id(500), nowMs, nowMs, seedReceipt],
    );
    await vault.database.customStatement(
      'INSERT INTO transactions (id, created_at, updated_at, deleted_at, '
      'revision, event_id, account_id, date, amount_minor, currency, kind, '
      'merchant_name, note, category_id, source, is_estimated) '
      "VALUES (?, ?, ?, NULL, 1, ?, ?, '2026-10-13', -1000, 'USD', "
      "'expense', NULL, NULL, NULL, 'manual', 0)",
      [_id(501), nowMs, nowMs, _id(500), saved.id],
    );
    final listed = (await gateway.listAccounts()).single;
    expect(listed.balanceMinor, 645000);
  });

  test('a deposit save writes the account, the anchor and the interest rule',
      () async {
    final saved = await gateway.createDeposit(
      DepositSetup(
        name: 'Harbor term deposit',
        currencyCode: 'USD',
        amountMinor: 1000000,
        annualRate: Decimal.parse('0.041'),
        compounding: Compounding.monthly,
        start: LocalDate(2026, 2, 12),
        maturity: LocalDate(2026, 11, 12),
      ),
    );
    expect(saved.kind, AccountKind.deposit);
    final listed = await gateway.listAccounts();
    expect(listed.single.kind, AccountKind.deposit);
    expect(listed.single.balanceMinor, 1000000);

    final rule = await repository.ruleFor(saved.id);
    expect(rule, isNotNull);
    expect(rule!.method, 'interest');
    final parameters = jsonDecode(rule.parametersJson) as Map<String, Object?>;
    expect(parameters['annualRate'], '0.041');
    expect(parameters['compounding'], 'monthly');
    expect(parameters['start'], '2026-02-12');
    expect(parameters['maturity'], '2026-11-12');
    expect(parameters['renewsAutomatically'], isFalse);

    final balance = await repository.balanceAt(
      accountId: saved.id,
      asOf: '2026-10-13',
    ) as KnownBalance;
    expect(balance.anchorDate, '2026-02-12');

    final row = await vault.database.customSelect(
      'SELECT is_liquid FROM accounts WHERE id = ?',
      variables: <Variable<Object>>[Variable<String>(saved.id)],
    ).getSingle();
    expect(row.data['is_liquid'], 0);
  });

  test('a deposit with a maturity before the start is rejected', () async {
    await expectLater(
      gateway.createDeposit(
        DepositSetup(
          name: 'Broken deposit',
          currencyCode: 'USD',
          amountMinor: 100,
          annualRate: Decimal.parse('0.04'),
          compounding: Compounding.simple,
          start: LocalDate(2026, 2, 12),
          maturity: LocalDate(2026, 2, 1),
        ),
      ),
      throwsArgumentError,
    );
    expect(await gateway.listAccounts(), isEmpty);
  });
}
