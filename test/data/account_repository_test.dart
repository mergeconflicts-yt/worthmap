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
      "VALUES (?, ?, ?, NULL, 1, 'payment', '2026-10-01', ?, NULL)",
      [event, nowMs, nowMs, receipt],
    );
    for (final (index, id) in <String>[_checking, _visa].indexed) {
      await vault.database.customStatement(
        'INSERT INTO accounts (id, created_at, updated_at, deleted_at, '
        'revision, name, type, currency, institution, is_liability, '
        'is_liquid, include_in_net_worth, archived) '
        "VALUES (?, ?, ?, NULL, 1, ?, ?, 'USD', NULL, ?, ?, 1, 0)",
        [
          id,
          nowMs,
          nowMs,
          'Account $index',
          index == 0 ? 'bank' : 'card',
          index == 0 ? 0 : 1,
          index == 0 ? 1 : 0,
        ],
      );
    }
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

  test('an account is created and listed', () async {
    await run(
      accounts.planCreateAccount(
        id: _id(1),
        name: 'Savings',
        type: 'bank',
        currency: 'USD',
        isLiquid: true,
      ),
    );
    final list = await accounts.list();
    expect(list.map((row) => row.name), contains('Savings'));
    expect(list.firstWhere((row) => row.id == _id(1)).isLiquid, isTrue);
  });

  test('no anchor is Missing, never zero', () async {
    expect(
      await accounts.balanceAt(accountId: _checking, asOf: '2026-10-13'),
      isA<MissingBalance>(),
    );
  });

  test('an anchor plus postings strictly after its date', () async {
    await run(
      accounts.planSetOpeningBalance(
        accountId: _checking,
        anchorId: _id(1),
        date: '2026-10-13',
        balanceMinor: 645000,
        currency: 'USD',
      ),
    );
    await post(_id(2), '2026-10-13', -10000);
    await post(_id(3), '2026-10-14', -10000);

    final asOf13 =
        await accounts.balanceAt(accountId: _checking, asOf: '2026-10-13');
    expect((asOf13 as KnownBalance).amount.minor, 645000);
    final asOf14 =
        await accounts.balanceAt(accountId: _checking, asOf: '2026-10-14');
    expect((asOf14 as KnownBalance).amount.minor, 635000);
  });

  test('a date before the anchor is Missing, not the anchor balance', () async {
    await run(
      accounts.planSetOpeningBalance(
        accountId: _checking,
        anchorId: _id(1),
        date: '2026-10-13',
        balanceMinor: 645000,
        currency: 'USD',
      ),
    );
    expect(
      await accounts.balanceAt(accountId: _checking, asOf: '2026-10-12'),
      isA<MissingBalance>(),
    );
  });

  test('an entered zero is a real anchor', () async {
    await run(
      accounts.planSetOpeningBalance(
        accountId: _checking,
        anchorId: _id(1),
        date: '2026-10-13',
        balanceMinor: 0,
        currency: 'USD',
      ),
    );
    final balance =
        await accounts.balanceAt(accountId: _checking, asOf: '2026-10-13');
    expect((balance as KnownBalance).amount.minor, 0);
  });

  test('a liability anchor is signed; the owed amount is positive', () async {
    await run(
      accounts.planSetOpeningBalance(
        accountId: _visa,
        anchorId: _id(1),
        date: '2026-10-12',
        balanceMinor: -124000,
        currency: 'USD',
      ),
    );
    final balance =
        await accounts.balanceAt(accountId: _visa, asOf: '2026-10-13');
    expect((balance as KnownBalance).amount.minor, -124000);
    expect(-balance.amount.minor, 124000);
  });

  test('a correction supersedes and moves the selected pointer', () async {
    await run(
      accounts.planSetOpeningBalance(
        accountId: _checking,
        anchorId: _id(1),
        date: '2026-09-30',
        balanceMinor: 100000,
        currency: 'USD',
      ),
    );
    await run(
      accounts.planSetOpeningBalance(
        accountId: _checking,
        anchorId: _id(2),
        date: '2026-10-05',
        balanceMinor: 700000,
        currency: 'USD',
        supersedesAnchorId: _id(1),
      ),
    );
    final balance =
        await accounts.balanceAt(accountId: _checking, asOf: '2026-10-13');
    expect((balance as KnownBalance).amount.minor, 700000);
    final anchors = await vault.database.customSelect(
      'SELECT count(*) AS n FROM balance_anchors WHERE account_id = ?',
      variables: [const Variable(_checking)],
    ).getSingle();
    expect(anchors.data['n'], 2);
    final log = await vault.database
        .customSelect(
          'SELECT count(*) AS n FROM change_log',
        )
        .getSingle();
    expect(log.data['n'], 2);
  });
}
