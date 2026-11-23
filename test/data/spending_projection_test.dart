// P15 (SPEC 4.4, 6.5; Q09-Q12): the spending projection.
//
// Appendix A on 13 October 2026: spent 3,940, limit 5,200, left 1,260,
// month gone 42%. A partial month is marked and not zero-filled. A limit
// change publishes a complete replacement generation; the old one retires.
// Category contributions count split parts once.

import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/core/percent.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/projections/spending.dart';
import 'package:contour/data/repositories/budgets.dart';
import 'package:contour/data/repositories/write_plan.dart';
import 'package:contour/domain/numbers/spending_budget.dart';
import 'package:contour/domain/numbers/spending_totals.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _account = '00000000-0000-7000-8000-0000000000a1';
const String _epoch = '00000000-0000-7000-8000-000000000001';
const String _seedReceipt = '00000000-0000-7000-8000-0000000000f2';

String _id(int n) => '00000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

String _categoryId(String name) => switch (name) {
      'rent' => '00000000-0000-7000-8000-0000000000c1',
      'groceries' => '00000000-0000-7000-8000-0000000000c2',
      'dining' => '00000000-0000-7000-8000-0000000000c3',
      'shopping' => '00000000-0000-7000-8000-0000000000c4',
      'transport' => '00000000-0000-7000-8000-0000000000c5',
      'utilities' => '00000000-0000-7000-8000-0000000000c6',
      'other' => '00000000-0000-7000-8000-0000000000c7',
      'subscriptions' => '00000000-0000-7000-8000-0000000000c8',
      _ => throw ArgumentError.value(name, 'name', 'Unknown category'),
    };

void main() {
  late Vault vault;
  late CommandRepository commands;
  late BudgetRepository budgets;
  late SpendingProjection projection;
  var nowMs = 1700000000000;
  var operation = 0;
  var nextId = 200;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => _epoch,
    );
    commands = CommandRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newOperationId: () {
        operation += 1;
        return _id(80 + operation);
      },
    );
    budgets = BudgetRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newId: () {
        nextId += 1;
        return _id(nextId);
      },
    );
    projection = SpendingProjection(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    operation = 0;
    nextId = 200;
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
    for (var index = 1; index <= 8; index++) {
      await vault.database.customStatement(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        'VALUES (?, ?, ?, NULL, 1, ?, NULL, ?, 0, 0)',
        [
          '00000000-0000-7000-8000-0000000000c$index',
          nowMs,
          nowMs,
          'Category $index',
          'expense',
        ],
      );
    }
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
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  var transactionSeed = 0;
  var eventSeed = 0;

  Future<String> insertPayment({
    required String date,
    required int amountMinor,
    required String kind,
    String? categoryId,
    List<({String part, String? categoryId, int amountMinor})> splits =
        const <({String part, String? categoryId, int amountMinor})>[],
  }) async {
    transactionSeed += 1;
    eventSeed += 1;
    final transaction = '00000000-0000-7000-8000-2'
        '${transactionSeed.toString().padLeft(11, '0')}';
    final event = '00000000-0000-7000-8000-1'
        '${eventSeed.toString().padLeft(11, '0')}';
    await vault.database.customStatement(
      'INSERT INTO financial_events (id, created_at, updated_at, deleted_at, '
      'revision, event_type, date, operation_id, supersedes_event_id) '
      'VALUES (?, ?, ?, NULL, 1, ?, ?, ?, NULL)',
      [
        event,
        nowMs,
        nowMs,
        kind == 'income' ? 'income' : 'payment',
        date,
        _seedReceipt,
      ],
    );
    await vault.database.customStatement(
      'INSERT INTO transactions (id, created_at, updated_at, deleted_at, '
      'revision, event_id, account_id, date, amount_minor, currency, kind, '
      'merchant_name, note, category_id, source, is_estimated) '
      "VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, 'USD', ?, NULL, NULL, ?, 'manual', 0)",
      [
        transaction,
        nowMs,
        nowMs,
        event,
        _account,
        date,
        amountMinor,
        kind,
        categoryId,
      ],
    );
    for (final split in splits) {
      await vault.database.customStatement(
        'INSERT INTO transaction_splits (id, created_at, updated_at, '
        'deleted_at, revision, transaction_id, category_id, amount_minor, '
        'currency, note) VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, NULL)',
        [
          split.part,
          nowMs,
          nowMs,
          transaction,
          split.categoryId,
          split.amountMinor,
          'USD',
        ],
      );
    }
    return transaction;
  }

  Future<void> insertAppendixA() async {
    final rows = <(String, int, String, String?)>[
      // October 2026 (1-13 Oct): money out 3,940.
      ('2026-10-01', -180000, 'expense', 'rent'),
      ('2026-10-01', 820000, 'income', null),
      ('2026-10-02', -32000, 'expense', 'groceries'),
      ('2026-10-03', -6000, 'expense', 'transport'),
      ('2026-10-04', -9000, 'expense', 'utilities'),
      ('2026-10-05', -7000, 'expense', 'dining'),
      ('2026-10-06', -4000, 'expense', 'shopping'),
      ('2026-10-07', -30000, 'expense', 'groceries'),
      ('2026-10-08', -34000, 'expense', 'dining'),
      ('2026-10-09', -34000, 'expense', 'shopping'),
      ('2026-10-10', -20000, 'expense', 'transport'),
      ('2026-10-11', -12000, 'expense', 'utilities'),
      ('2026-10-12', -17000, 'expense', 'other'),
      ('2026-10-13', -9000, 'expense', 'subscriptions'),
      // September 2026: 4,005 in 1-13 Sep.
      ('2026-09-01', -180000, 'expense', 'rent'),
      ('2026-09-02', -90000, 'expense', 'groceries'),
      ('2026-09-03', -60500, 'expense', 'dining'),
      ('2026-09-04', -70000, 'expense', 'other'),
      ('2026-09-20', -31500, 'expense', 'other'),
      // The other complete months: printed totals.
      ('2025-10-05', -390000, 'expense', 'other'),
      ('2025-11-05', -390000, 'expense', 'other'),
      ('2025-12-05', -410000, 'expense', 'other'),
      ('2026-01-05', -380000, 'expense', 'other'),
      ('2026-02-05', -370000, 'expense', 'other'),
      ('2026-03-05', -418000, 'expense', 'other'),
      ('2026-04-05', -340000, 'expense', 'other'),
      ('2026-05-05', -400000, 'expense', 'other'),
      ('2026-06-05', -400000, 'expense', 'other'),
      ('2026-07-05', -420000, 'expense', 'other'),
      ('2026-08-05', -456000, 'expense', 'other'),
    ];
    for (final row in rows) {
      await insertPayment(
        date: row.$1,
        amountMinor: row.$2,
        kind: row.$3,
        categoryId: row.$4 == null ? null : _categoryId(row.$4!),
      );
    }
  }

  Future<void> saveOctoberLimits() async {
    final plan = await budgets.planSaveLimits(
      month: '2026-10',
      currency: 'USD',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      limits: <String, int>{
        _categoryId('rent'): 180000,
        _categoryId('groceries'): 120000,
        _categoryId('dining'): 60000,
        _categoryId('shopping'): 50000,
        _categoryId('transport'): 40000,
        _categoryId('utilities'): 30000,
        _categoryId('other'): 30000,
        _categoryId('subscriptions'): 10000,
      },
    );
    await _run(commands, plan, operation);
    operation += 1;
  }

  SpendingRequest request(SpendingChip chip, {LocalDate? today}) =>
      SpendingRequest(
        chip: chip,
        today: today ?? LocalDate.parse('2026-10-13'),
        currency: Currency.usd,
        shareOfToday: Decimal.one,
      );

  test('Appendix A month: 3,940 of 5,200, 1,260 left and 42% month gone',
      () async {
    await insertAppendixA();
    await saveOctoberLimits();

    final snapshot = await projection.project(request(SpendingChip.month));

    expect(snapshot.rebuilt, isTrue);
    expect(snapshot.moneyOut, isA<KnownTotal>());
    expect(
      (snapshot.moneyOut as KnownTotal).amount,
      Money.fromMinor(394000, Currency.usd),
    );
    expect(snapshot.limit, Money.fromMinor(520000, Currency.usd));
    expect(snapshot.left, Money.fromMinor(126000, Currency.usd));
    expect(
      snapshot.monthGone,
      Percent.fromPoints(Decimal.parse('41.94')),
    );
    expect(snapshot.partial, isTrue);
    expect(snapshot.used!.value, Decimal.parse('75.77'));
    expect(snapshot.standing, isA<WithinLimit>());
  });

  test('category buckets sum to money out and list the largest first',
      () async {
    await insertAppendixA();
    await saveOctoberLimits();

    final snapshot = await projection.project(request(SpendingChip.month));
    final byCategory = <String, int>{
      for (final row in snapshot.categories) row.categoryId: row.amount.minor,
    };
    expect(byCategory[_categoryId('rent')], 180000);
    expect(byCategory[_categoryId('groceries')], 62000);
    expect(byCategory[_categoryId('dining')], 41000);
    expect(byCategory[_categoryId('shopping')], 38000);
    expect(byCategory[_categoryId('transport')], 26000);
    expect(byCategory[_categoryId('utilities')], 21000);
    expect(byCategory[_categoryId('other')], 17000);
    expect(byCategory[_categoryId('subscriptions')], 9000);
    expect(
      snapshot.categories.fold<int>(0, (sum, row) => sum + row.amount.minor),
      394000,
    );
    expect(snapshot.categories.first.categoryId, _categoryId('rent'));
  });

  test('the partial month has one daily bucket per elapsed day', () async {
    await insertAppendixA();
    await saveOctoberLimits();

    final snapshot = await projection.project(request(SpendingChip.month));
    expect(snapshot.level, 0);
    expect(snapshot.buckets, hasLength(13));
    expect(snapshot.buckets.first.firstDate, LocalDate.parse('2026-10-01'));
    expect(snapshot.buckets.last.lastDate, LocalDate.parse('2026-10-13'));
    expect(
      snapshot.buckets.fold<int>(
        0,
        (sum, bucket) => sum + (bucket.amount?.minor ?? 0),
      ),
      394000,
    );
    // Days after today are absent, not zero-filled.
    expect(
      snapshot.buckets.any(
        (bucket) =>
            bucket.firstDate.compareTo(LocalDate.parse('2026-10-13')) > 0,
      ),
      isFalse,
    );
  });

  test('an unchanged request reuses the same generation', () async {
    await insertAppendixA();
    await saveOctoberLimits();

    final first = await projection.project(request(SpendingChip.month));
    final second = await projection.project(request(SpendingChip.month));
    expect(second.rebuilt, isFalse);
    expect(second.generationId, first.generationId);

    final published = await vault.database.customSelect(
      'SELECT count(*) AS n FROM projection_generations WHERE status = ?',
      variables: [const Variable('published')],
    ).getSingle();
    expect(published.data['n'], 1);
    final current = await vault.database
        .customSelect('SELECT count(*) AS n FROM current_projections')
        .getSingle();
    expect(current.data['n'], 1);
  });

  test('a limit save publishes a complete replacement and retires the old one',
      () async {
    await insertAppendixA();
    await saveOctoberLimits();
    final first = await projection.project(request(SpendingChip.month));

    final before = await vault.database
        .customSelect('SELECT count(*) AS n FROM transactions')
        .getSingle();
    await _run(
      commands,
      await budgets.planSaveLimits(
        month: '2026-10',
        currency: 'USD',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        limits: <String, int>{
          _categoryId('rent'): 180000,
          _categoryId('groceries'): 120000,
        },
      ),
      operation,
    );
    operation += 1;
    final after = await projection.project(request(SpendingChip.month));

    expect(after.rebuilt, isTrue);
    expect(after.generationId, isNot(first.generationId));
    expect(after.limit, Money.fromMinor(300000, Currency.usd));
    expect(after.left, Money.fromMinor(-94000, Currency.usd));
    expect(after.standing, isA<OverLimit>());
    final transactions = await vault.database
        .customSelect('SELECT count(*) AS n FROM transactions')
        .getSingle();
    expect(transactions.data['n'], before.data['n']);

    final old = await vault.database.customSelect(
      'SELECT status FROM projection_generations WHERE id = ?',
      variables: [Variable(first.generationId)],
    ).getSingle();
    expect(old.data['status'], 'obsolete');
    final current = await vault.database
        .customSelect('SELECT count(*) AS n FROM current_projections')
        .getSingle();
    expect(current.data['n'], 1);
  });

  test('without a limit the comparison uses the same days last month',
      () async {
    await insertAppendixA();
    await saveOctoberLimits();
    await _run(
      commands,
      await budgets.planSaveLimits(
        month: '2026-10',
        currency: 'USD',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        limits: const <String, int>{},
      ),
      operation,
    );
    operation += 1;

    final snapshot = await projection.project(request(SpendingChip.month));
    expect(snapshot.limit, isNull);
    expect(snapshot.left, isNull);
    expect(snapshot.sameDaysPrevious, Money.fromMinor(400500, Currency.usd));
    expect(snapshot.standing, isA<ComparedWithoutLimit>());
    final comparison = snapshot.standing as ComparedWithoutLimit;
    expect(comparison.difference, Money.fromMinor(-6500, Currency.usd));
  });

  test('the six-month chip has six complete monthly buckets', () async {
    await insertAppendixA();
    await saveOctoberLimits();

    final snapshot = await projection.project(request(SpendingChip.sixMonths));
    expect(snapshot.level, 1);
    expect(snapshot.buckets, hasLength(6));
    expect(snapshot.partial, isFalse);
    expect(snapshot.buckets.first.firstDate, LocalDate.parse('2026-04-01'));
    expect(snapshot.buckets.last.lastDate, LocalDate.parse('2026-09-30'));
    expect(
      snapshot.buckets.fold<int>(
        0,
        (sum, bucket) => sum + (bucket.amount?.minor ?? 0),
      ),
      2448000,
    );
    expect(snapshot.limit, Money.fromMinor(3120000, Currency.usd));
  });

  test('a split payment contributes each part once', () async {
    await insertPayment(
      date: '2026-11-02',
      amountMinor: -5000,
      kind: 'expense',
      categoryId: _categoryId('groceries'),
      splits: <({String part, String? categoryId, int amountMinor})>[
        (
          part: '00000000-0000-7000-8000-0000000000d1',
          categoryId: _categoryId('groceries'),
          amountMinor: -3000,
        ),
        (
          part: '00000000-0000-7000-8000-0000000000d2',
          categoryId: _categoryId('dining'),
          amountMinor: -2000,
        ),
      ],
    );

    final snapshot = await projection.project(
      request(SpendingChip.month, today: LocalDate.parse('2026-11-13')),
    );
    expect((snapshot.moneyOut as KnownTotal).amount.minor, 5000);
    final contributions = await vault.database
        .customSelect(
          'SELECT count(*) AS n FROM category_postings',
        )
        .getSingle();
    expect(contributions.data['n'], 2);
    final total = await vault.database
        .customSelect(
          'SELECT SUM(amount_minor) AS total FROM category_postings',
        )
        .getSingle();
    expect(total.data['total'], 5000);
  });

  test('a purchase-month refund moves to the original month', () async {
    final original = await insertPayment(
      date: '2026-08-20',
      amountMinor: -10000,
      kind: 'expense',
      categoryId: _categoryId('groceries'),
    );
    final refund = await insertPayment(
      date: '2026-09-15',
      amountMinor: 4000,
      kind: 'refund',
      categoryId: _categoryId('groceries'),
    );
    await vault.database.customStatement(
      'INSERT INTO refund_links (id, created_at, updated_at, deleted_at, '
      'revision, refund_transaction_id, original_transaction_id, '
      'amount_minor, currency) VALUES (?, ?, ?, NULL, 1, ?, ?, 4000, ?)',
      [
        '00000000-0000-7000-8000-0000000000e1',
        nowMs,
        nowMs,
        refund,
        original,
        'USD',
      ],
    );

    final purchase = await projection.project(
      SpendingRequest(
        chip: SpendingChip.month,
        today: LocalDate.parse('2026-08-31'),
        currency: Currency.usd,
        refundRecognition: RefundRecognition.purchaseMonth,
      ),
    );
    expect((purchase.moneyOut as KnownTotal).amount.minor, 6000);

    final refundMonth = await projection.project(
      SpendingRequest(
        chip: SpendingChip.month,
        today: LocalDate.parse('2026-08-31'),
        currency: Currency.usd,
      ),
    );
    expect((refundMonth.moneyOut as KnownTotal).amount.minor, 10000);
  });

  test('an empty period is Missing and has a gap bucket, never zero', () async {
    await insertAppendixA();
    final snapshot = await projection.project(
      request(SpendingChip.month, today: LocalDate.parse('2026-12-13')),
    );
    expect(snapshot.moneyOut, isA<NoneRecordedTotal>());
    expect(snapshot.limit, isNull);
    expect(snapshot.buckets, hasLength(1));
    expect(snapshot.buckets.single.amount, isNull);
    expect(snapshot.standing, isA<BudgetNoneRecorded>());
  });
}

Future<void> _run(
  CommandRepository commands,
  WritePlan plan,
  int operation,
) async {
  final op = _id(60 + operation);
  await commands.prepare(
    operationId: op,
    commandType: 'budget.saveLimits',
    draftId: _id(40 + operation),
    formType: 'budget',
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
}
