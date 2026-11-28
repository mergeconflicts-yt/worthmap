// P3-18 (SPEC 8.6; DECISIONS P3-BALANCE-ROWS): statement balance observations.
//
// The tests use a real in-memory vault and the Appendix A accounts. They
// assert one anchor per accepted row, no payment, the covered case, the
// correction path and the inclusive date boundary through the P14 read.
import 'package:contour/core/dates.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/accounts.dart';
import 'package:contour/data/repositories/import_balances.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _checking = '00000000-0000-7000-8000-0000000000a1';
const String _visa = '00000000-0000-7000-8000-0000000000a2';

String _id(int n) => '00000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late ImportBalanceRepository balances;
  late AccountRepository accounts;
  var entity = 0;
  final now = DateTime.utc(2026, 10, 20, 12);
  final nowMs = now.millisecondsSinceEpoch;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => now,
    );
    balances = ImportBalanceRepository(
      db: vault.database,
      commands: commands,
      clockUtc: () => now,
      newEntityId: () {
        entity += 1;
        return _id(6000 + entity);
      },
    );
    accounts = AccountRepository(
      db: vault.database,
      clockUtc: () => now,
    );
    entity = 0;
    await vault.database.customStatement(
      "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
    );
    for (final (index, id) in <String>[_checking, _visa].indexed) {
      await vault.database.customStatement(
        'INSERT INTO accounts (id, created_at, updated_at, deleted_at, '
        'revision, name, type, currency, institution, is_liability, '
        'is_liquid, include_in_net_worth, archived) '
        "VALUES (?, ?, ?, NULL, 1, ?, ?, 'USD', NULL, ?, ?, 1, 0)",
        <Object?>[
          id,
          nowMs,
          nowMs,
          index == 0 ? 'First Bank checking' : 'Visa card',
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

  Future<int> count(String table) async {
    final row = await vault.database
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.data['n'] as int;
  }

  Future<String> selectedAnchor(String accountId) async {
    final row = await vault.database.customSelect(
      'SELECT anchor_id FROM current_balance_anchors WHERE account_id = ?',
      variables: <Variable<Object>>[Variable<String>(accountId)],
    ).getSingle();
    return row.data['anchor_id'] as String;
  }

  Future<void> seedEvent({
    required String eventId,
    required String receiptId,
    required String date,
  }) async {
    await vault.database.customStatement(
      'INSERT INTO operation_intents (operation_id, command_type, '
      'payload_digest, payload_version, draft_id, submitted_at, state, '
      "state_version) VALUES (?, 'seed', randomblob(32), 1, NULL, 0, "
      "'committed', 1)",
      <Object?>[receiptId],
    );
    await vault.database.customStatement(
      'INSERT INTO operation_receipts (operation_id, commit_sequence, '
      "committed_at, result_version, result_json) VALUES (?, 1000, 0, 1, '{}')",
      <Object?>[receiptId],
    );
    await vault.database.customStatement(
      'INSERT INTO financial_events (id, created_at, updated_at, deleted_at, '
      'revision, event_type, date, operation_id, supersedes_event_id) '
      "VALUES (?, ?, ?, NULL, 1, 'payment', ?, ?, NULL)",
      <Object?>[eventId, nowMs, nowMs, date, receiptId],
    );
  }

  Future<void> insertTransaction({
    required String id,
    required String eventId,
    required String date,
    required int minor,
  }) async {
    await vault.database.customStatement(
      'INSERT INTO transactions (id, created_at, updated_at, deleted_at, '
      'revision, event_id, account_id, date, amount_minor, currency, kind, '
      'merchant_name, note, category_id, source, is_estimated) '
      "VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, 'USD', 'expense', NULL, NULL, "
      "NULL, 'manual', 0)",
      <Object?>[id, nowMs, nowMs, eventId, _checking, date, minor],
    );
  }

  test('records one imported anchor and no payment', () async {
    final result = await balances.record(
      operationId: _id(80),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 645000,
      currency: 'USD',
    );

    expect(result, isA<RecordedStatementBalance>());
    final recorded = result as RecordedStatementBalance;
    expect(recorded.supersededAnchorId, isNull);
    expect(recorded.balanceMinor, 645000);

    expect(await count('balance_anchors'), 1);
    expect(await count('transactions'), 0);
    final anchor = await vault.database
        .customSelect('SELECT source, balance_minor, date FROM balance_anchors')
        .getSingle();
    expect(anchor.data['source'], 'imported');
    expect(anchor.data['balance_minor'], 645000);
    expect(anchor.data['date'], '2026-10-12');
    expect(await selectedAnchor(_checking), recorded.anchorId);

    final change = await vault.database
        .customSelect('SELECT change_kind FROM change_log')
        .getSingle();
    expect(change.data['change_kind'], 'create');

    final balance = await accounts.balanceAt(
      accountId: _checking,
      asOf: '2026-10-12',
    );
    expect(balance, isA<KnownBalance>());
    expect((balance as KnownBalance).amount.minor, 645000);
  });

  test('a liability keeps its signed balance', () async {
    await balances.record(
      operationId: _id(80),
      accountId: _visa,
      date: LocalDate(2026, 10, 12),
      balanceMinor: -124000,
      currency: 'USD',
    );

    final balance = await accounts.balanceAt(
      accountId: _visa,
      asOf: '2026-10-12',
    );
    expect(balance, isA<KnownBalance>());
    expect((balance as KnownBalance).amount.minor, -124000);
  });

  test('a zero row is a real anchor', () async {
    await balances.record(
      operationId: _id(80),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 0,
      currency: 'USD',
    );

    expect(await count('balance_anchors'), 1);
    final balance = await accounts.balanceAt(
      accountId: _checking,
      asOf: '2026-10-12',
    );
    expect((balance as KnownBalance).amount.minor, 0);
  });

  test('a covered row writes nothing', () async {
    final first = await balances.record(
      operationId: _id(80),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 645000,
      currency: 'USD',
    ) as RecordedStatementBalance;

    final earlier = await balances.record(
      operationId: _id(81),
      accountId: _checking,
      date: LocalDate(2026, 10, 5),
      balanceMinor: 650000,
      currency: 'USD',
    );
    expect(earlier, isA<CoveredStatementBalance>());
    expect(earlier.anchorId, first.anchorId);
    expect(earlier.date, LocalDate(2026, 10, 12));
    expect(await commands.receiptOf(_id(81)), isNull);

    final same = await balances.record(
      operationId: _id(82),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 645000,
      currency: 'USD',
    );
    expect(same, isA<CoveredStatementBalance>());

    expect(await count('balance_anchors'), 1);
    expect(await count('change_log'), 1);
    expect(await selectedAnchor(_checking), first.anchorId);
  });

  test('a correction supersedes the selected anchor', () async {
    final first = await balances.record(
      operationId: _id(80),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 645000,
      currency: 'USD',
    ) as RecordedStatementBalance;

    final correction = await balances.record(
      operationId: _id(81),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 640000,
      currency: 'USD',
    );
    expect(correction, isA<RecordedStatementBalance>());
    expect(
      (correction as RecordedStatementBalance).supersededAnchorId,
      first.anchorId,
    );

    expect(await count('balance_anchors'), 2);
    final old = await vault.database.customSelect(
      'SELECT balance_minor, supersedes_anchor_id FROM balance_anchors '
      'WHERE id = ?',
      variables: <Variable<Object>>[Variable<String>(first.anchorId)],
    ).getSingle();
    expect(old.data['balance_minor'], 645000);
    expect(old.data['supersedes_anchor_id'], isNull);

    final selected = await vault.database.customSelect(
      'SELECT a.id, a.balance_minor, a.supersedes_anchor_id '
      'FROM current_balance_anchors c JOIN balance_anchors a ON a.id = c.anchor_id '
      'WHERE c.account_id = ?',
      variables: <Variable<Object>>[const Variable<String>(_checking)],
    ).getSingle();
    expect(selected.data['id'], correction.anchorId);
    expect(selected.data['balance_minor'], 640000);
    expect(selected.data['supersedes_anchor_id'], first.anchorId);
    expect(await count('change_log'), 2);
  });

  test('the inclusive date boundary holds', () async {
    final first = await balances.record(
      operationId: _id(80),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 645000,
      currency: 'USD',
    ) as RecordedStatementBalance;

    await seedEvent(
      eventId: _id(700),
      receiptId: _id(701),
      date: '2026-10-12',
    );
    await insertTransaction(
      id: _id(702),
      eventId: _id(700),
      date: '2026-10-12',
      minor: -1000,
    );
    await insertTransaction(
      id: _id(703),
      eventId: _id(700),
      date: '2026-10-13',
      minor: -2000,
    );

    final onDate = await accounts.balanceAt(
      accountId: _checking,
      asOf: '2026-10-12',
    );
    expect((onDate as KnownBalance).amount.minor, 645000);
    final after = await accounts.balanceAt(
      accountId: _checking,
      asOf: '2026-10-13',
    );
    expect((after as KnownBalance).amount.minor, 643000);

    final later = await balances.record(
      operationId: _id(81),
      accountId: _checking,
      date: LocalDate(2026, 10, 13),
      balanceMinor: 643000,
      currency: 'USD',
    );
    expect(later, isA<RecordedStatementBalance>());
    expect(
      (later as RecordedStatementBalance).supersededAnchorId,
      isNull,
    );
    expect(await selectedAnchor(_checking), later.anchorId);

    final earlier = await balances.record(
      operationId: _id(82),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 645000,
      currency: 'USD',
    );
    expect(earlier, isA<CoveredStatementBalance>());
    expect(earlier.anchorId, later.anchorId);
    expect(await count('balance_anchors'), 2);
    expect(first.anchorId, isNot(later.anchorId));
  });

  test('a wrong currency writes nothing', () async {
    await expectLater(
      balances.record(
        operationId: _id(80),
        accountId: _checking,
        date: LocalDate(2026, 10, 12),
        balanceMinor: 645000,
        currency: 'EUR',
      ),
      throwsA(
        isA<ImportBalanceError>().having(
          (error) => error.code,
          'code',
          ImportBalanceErrorCode.currencyMismatch,
        ),
      ),
    );
    expect(await count('balance_anchors'), 0);
    expect(await commands.receiptOf(_id(80)), isNull);
  });

  test('an unknown account writes nothing', () async {
    await expectLater(
      balances.record(
        operationId: _id(80),
        accountId: _id(99),
        date: LocalDate(2026, 10, 12),
        balanceMinor: 645000,
        currency: 'USD',
      ),
      throwsA(
        isA<ImportBalanceError>().having(
          (error) => error.code,
          'code',
          ImportBalanceErrorCode.accountNotFound,
        ),
      ),
    );
    expect(await count('balance_anchors'), 0);
  });

  test('a retry returns the first anchor, a changed input is refused',
      () async {
    final first = await balances.record(
      operationId: _id(80),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 645000,
      currency: 'USD',
    ) as RecordedStatementBalance;

    final retry = await balances.record(
      operationId: _id(80),
      accountId: _checking,
      date: LocalDate(2026, 10, 12),
      balanceMinor: 645000,
      currency: 'USD',
    );
    expect(retry, isA<RecordedStatementBalance>());
    expect(retry.anchorId, first.anchorId);

    await expectLater(
      balances.record(
        operationId: _id(80),
        accountId: _checking,
        date: LocalDate(2026, 10, 12),
        balanceMinor: 999999,
        currency: 'USD',
      ),
      throwsA(
        isA<ImportBalanceError>().having(
          (error) => error.code,
          'code',
          ImportBalanceErrorCode.replayMismatch,
        ),
      ),
    );

    expect(await count('balance_anchors'), 1);
    expect(await count('change_log'), 1);
  });
}
