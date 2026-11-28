// P4-02 (SPEC 6.6; SPEC 9.2; DECISIONS CLOSED-G01): account reads.
//
// The tests use a real in-memory vault. They assert the account row, its
// institution, the known balance from the selected anchor, the Missing case
// and the create fields. They never read the wall clock.

import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/accounts.dart';
import 'package:contour/data/repositories/write_plan.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _checking = '00000000-0000-7000-8000-0000000000a1';
const String _visa = '00000000-0000-7000-8000-0000000000a2';

String _id(int n) =>
    '00000000-0000-7000-8000-0000000000${n.toString().padLeft(2, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late AccountRepository accounts;
  var nowMs = 1700000000000;
  var operation = 0;
  var seed = 0;
  late String receipt;
  late String event;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newOperationId: () => _id(80 + operation),
    );
    accounts = AccountRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    operation = 0;
    seed += 1;
    receipt = _id(90 + seed);
    event = _id(70 + seed);
    await vault.database.customStatement(
      "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
    );
    await vault.database.customStatement(
      'INSERT INTO operation_intents (operation_id, command_type, '
      'payload_digest, payload_version, draft_id, submitted_at, state, '
      "state_version) VALUES (?, 'seed', randomblob(32), 1, NULL, 0, "
      "'committed', 1)",
      [receipt],
    );
    await vault.database.customStatement(
      'INSERT INTO operation_receipts (operation_id, commit_sequence, '
      "committed_at, result_version, result_json) VALUES (?, 1000, 0, 1, '{}')",
      [receipt],
    );
    await vault.database.customStatement(
      'INSERT INTO financial_events (id, created_at, updated_at, deleted_at, '
      'revision, event_type, date, operation_id, supersedes_event_id) '
      "VALUES (?, ?, ?, NULL, 1, 'payment', '2026-10-14', ?, NULL)",
      [event, nowMs, nowMs, receipt],
    );
    await vault.database.customStatement(
      'INSERT INTO accounts (id, created_at, updated_at, deleted_at, '
      'revision, name, type, currency, institution, is_liability, is_liquid, '
      'include_in_net_worth, archived) '
      "VALUES (?, ?, ?, NULL, 1, 'Checking', 'bank', 'USD', 'First Bank', "
      '0, 1, 1, 0)',
      [_checking, nowMs, nowMs],
    );
    await vault.database.customStatement(
      'INSERT INTO accounts (id, created_at, updated_at, deleted_at, '
      'revision, name, type, currency, institution, is_liability, is_liquid, '
      'include_in_net_worth, archived) '
      "VALUES (?, ?, ?, NULL, 1, 'Visa card', 'card', 'USD', NULL, "
      '1, 0, 1, 0)',
      [_visa, nowMs, nowMs],
    );
    await vault.database.customStatement(
      'INSERT INTO balance_anchors (id, created_at, updated_at, deleted_at, '
      'revision, account_id, date, balance_minor, currency, source, '
      'source_identity_id, inclusive, supersedes_anchor_id) '
      "VALUES (?, ?, ?, NULL, 1, ?, '2026-10-13', 645000, 'USD', 'manual', "
      'NULL, 1, NULL)',
      [_id(1), nowMs, nowMs, _checking],
    );
    await vault.database.customStatement(
      'INSERT INTO current_balance_anchors (account_id, anchor_id, '
      'selected_operation_id) VALUES (?, ?, ?)',
      [_checking, _id(1), receipt],
    );
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<void> run(WritePlan plan) async {
    final op = _id(60 + operation);
    await commands.prepare(
      operationId: op,
      commandType: 'account.write',
      draftId: _id(40 + operation),
      formType: 'account',
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

  Future<void> post(String id, String date, int minor) async {
    await vault.database.customStatement(
      'INSERT INTO transactions (id, created_at, updated_at, deleted_at, '
      'revision, event_id, account_id, date, amount_minor, currency, kind, '
      'merchant_name, note, category_id, source, is_estimated) '
      "VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, 'USD', 'expense', NULL, NULL, "
      "NULL, 'manual', 0)",
      [id, nowMs, nowMs, event, _checking, date, minor],
    );
  }

  test('a known account carries its institution and balance', () async {
    await post(_id(2), '2026-10-14', -4500);
    final detail = await accounts.findById(
      id: _checking,
      asOf: '2026-10-14',
    );
    expect(detail, isNotNull);
    expect(detail!.account.name, 'Checking');
    expect(detail.account.institution, 'First Bank');
    expect(detail.account.isLiquid, isTrue);
    expect(detail.account.isLiability, isFalse);
    final balance = detail.balance as KnownBalance;
    expect(balance.amount.minor, 640500);
    expect(balance.anchorDate, '2026-10-13');
  });

  test('a read before the anchor is Missing, never the anchor', () async {
    final detail = await accounts.findById(
      id: _checking,
      asOf: '2026-10-12',
    );
    expect(detail!.balance, isA<MissingBalance>());
  });

  test('an unknown or deleted account is not a detail', () async {
    expect(
      await accounts.findById(id: _visa, asOf: '2026-10-14'),
      isNotNull,
    );
    await vault.database.customStatement(
      'UPDATE accounts SET deleted_at = ?, revision = 2 WHERE id = ?',
      [nowMs, _visa],
    );
    expect(
      await accounts.findById(id: _visa, asOf: '2026-10-14'),
      isNull,
    );
    expect(
      await accounts.findById(id: _id(99), asOf: '2026-10-14'),
      isNull,
    );
  });

  test('create stores the institution and the optional limits', () async {
    await run(
      accounts.planCreateAccount(
        id: _id(3),
        name: 'Harbor savings',
        type: 'bank',
        currency: 'USD',
        institution: 'Harbor Bank',
        ownershipPercent: '40',
        minimumBalanceMinor: 50000,
        overdraftLimitMinor: 200000,
        isLiquid: true,
      ),
    );
    final detail = await accounts.findById(id: _id(3), asOf: '2026-10-14');
    expect(detail!.account.institution, 'Harbor Bank');
    expect(detail.account.isLiquid, isTrue);
    final row = await vault.database.customSelect(
      'SELECT ownership_percent_decimal, minimum_balance_minor, '
      'overdraft_limit_minor FROM accounts WHERE id = ?',
      variables: [Variable(_id(3))],
    ).getSingle();
    expect(row.data['ownership_percent_decimal'], '40');
    expect(row.data['minimum_balance_minor'], 50000);
    expect(row.data['overdraft_limit_minor'], 200000);
  });

  test('a value rule round-trips and an edit bumps the revision', () async {
    await run(
      accounts.planSaveRule(
        id: _id(5),
        accountId: _checking,
        method: 'interest',
        parametersJson: '{"annualRate":"0.041"}',
      ),
    );
    final first = await accounts.ruleFor(_checking);
    expect(first, isNotNull);
    expect(first!.method, 'interest');
    expect(first.parametersJson, '{"annualRate":"0.041"}');
    expect(first.revision, 1);

    await run(
      accounts.planSaveRule(
        id: _id(5),
        accountId: _checking,
        method: 'contribution',
        parametersJson: '{"monthlyMinor":50000}',
        current: first,
      ),
    );
    final second = await accounts.ruleFor(_checking);
    expect(second!.method, 'contribution');
    expect(second.revision, 2);
    expect(second.id, first.id);
  });

  test('an unknown method or a non-object payload is rejected', () async {
    expect(
      () => accounts.planSaveRule(
        id: _id(6),
        accountId: _checking,
        method: 'guess',
        parametersJson: '{}',
      ),
      throwsArgumentError,
    );
    expect(
      () => accounts.planSaveRule(
        id: _id(6),
        accountId: _checking,
        method: 'manual',
        parametersJson: '[1]',
      ),
      throwsArgumentError,
    );
  });

  test('create defaults to full ownership and no institution', () async {
    await run(
      accounts.planCreateAccount(
        id: _id(4),
        name: 'Wallet',
        type: 'cash',
        currency: 'USD',
      ),
    );
    final detail = await accounts.findById(id: _id(4), asOf: '2026-10-14');
    expect(detail!.account.institution, isNull);
    final row = await vault.database.customSelect(
      'SELECT ownership_percent_decimal, minimum_balance_minor, '
      'overdraft_limit_minor FROM accounts WHERE id = ?',
      variables: [Variable(_id(4))],
    ).getSingle();
    expect(row.data['ownership_percent_decimal'], '100');
    expect(row.data['minimum_balance_minor'], isNull);
    expect(row.data['overdraft_limit_minor'], isNull);
  });
}
