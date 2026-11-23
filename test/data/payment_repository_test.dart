import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/payments.dart';
import 'package:contour/data/repositories/write_plan.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _account = '00000000-0000-7000-8000-0000000000a1';
const String _groceries = '00000000-0000-7000-8000-0000000000c1';
const String _dining = '00000000-0000-7000-8000-0000000000c2';
const String _tag = '00000000-0000-7000-8000-0000000000d1';

String _id(int n) =>
    '00000000-0000-7000-8000-0000000000${n.toString().padLeft(2, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late PaymentRepository payments;
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
        return _id(80 + operation);
      },
    );
    payments = PaymentRepository(
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
    for (final (index, id) in <String>[_groceries, _dining].indexed) {
      await vault.database.customStatement(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        'VALUES (?, ?, ?, NULL, 1, ?, NULL, ?, 0, 0)',
        [id, nowMs, nowMs, 'Category $index', 'expense'],
      );
    }
    await vault.database.customStatement(
      'INSERT INTO tags (id, created_at, updated_at, deleted_at, revision, '
      "name) VALUES (?, ?, ?, NULL, 1, 'Household')",
      [_tag, nowMs, nowMs],
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
      commandType: 'payment.create',
      draftId: _id(40 + operation),
      formType: 'payment',
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

  NewPayment paymentFor({
    required String id,
    required String eventId,
    required int amountMinor,
    String date = '2026-10-05',
    List<PaymentSplitInput> splits = const <PaymentSplitInput>[],
    List<String> tagIds = const <String>[],
    String? categoryId,
  }) =>
      NewPayment(
        id: id,
        eventId: eventId,
        accountId: _account,
        date: date,
        amountMinor: amountMinor,
        currency: 'USD',
        kind: 'expense',
        merchantName: 'PX Market',
        categoryId: categoryId,
        splits: splits,
        tagIds: tagIds,
      );

  test('a payment, its splits and its tag commit in one command', () async {
    final id = _id(1);
    final event = _id(2);
    await run(
      payments.planCreate(
        paymentFor(
          id: id,
          eventId: event,
          amountMinor: -12130,
          categoryId: _groceries,
          splits: <PaymentSplitInput>[
            PaymentSplitInput(
              id: _id(3),
              categoryId: _groceries,
              amountMinor: -8412,
            ),
            PaymentSplitInput(
              id: _id(4),
              categoryId: _dining,
              amountMinor: -3718,
            ),
          ],
          tagIds: <String>[_tag],
        ),
      ),
    );
    final page = await payments.page(accountId: _account);
    expect(page.single.id, id);
    expect(page.single.amountMinor, -12130);
    final splits = await vault.database.customSelect(
      'SELECT count(*) AS n FROM transaction_splits WHERE transaction_id = ?',
      variables: [Variable(id)],
    ).getSingle();
    expect(splits.data['n'], 2);
    final tags = await vault.database.customSelect(
      'SELECT count(*) AS n FROM transaction_tags WHERE transaction_id = ?',
      variables: [Variable(id)],
    ).getSingle();
    expect(tags.data['n'], 1);
    final log = await vault.database
        .customSelect(
          'SELECT count(*) AS n FROM change_log',
        )
        .getSingle();
    expect(log.data['n'], 4); // event + payment + 2 splits
    final revision = await vault.database
        .customSelect(
          'SELECT revision FROM dependency_revisions',
        )
        .getSingle();
    expect(revision.data['revision'], 1);
  });

  test('category totals count split contributions once', () async {
    await run(
      payments.planCreate(
        paymentFor(
          id: _id(1),
          eventId: _id(2),
          amountMinor: -5000,
          categoryId: _groceries,
        ),
      ),
    );
    await run(
      payments.planCreate(
        paymentFor(
          id: _id(3),
          eventId: _id(4),
          amountMinor: -5000,
          categoryId: _groceries,
          splits: <PaymentSplitInput>[
            PaymentSplitInput(
              id: _id(5),
              categoryId: _groceries,
              amountMinor: -3000,
            ),
            PaymentSplitInput(
              id: _id(6),
              categoryId: _dining,
              amountMinor: -2000,
            ),
          ],
        ),
      ),
    );
    final totals = await payments.categoryTotals(
      from: '2026-10-01',
      to: '2026-10-31',
    );
    final byCategory = <String?, int>{
      for (final row in totals) row.categoryId: row.amountMinor,
    };
    expect(byCategory[_groceries], -8000);
    expect(byCategory[_dining], -2000);
  });

  test('the page is keyset paged newest first', () async {
    for (final (index, date) in <String>[
      '2026-10-03',
      '2026-10-05',
      '2026-10-07',
    ].indexed) {
      await run(
        payments.planCreate(
          paymentFor(
            id: _id(10 + index),
            eventId: _id(20 + index),
            amountMinor: -1000 - index,
            date: date,
          ),
        ),
      );
    }
    final first = await payments.page(accountId: _account, limit: 2);
    expect(first.map((row) => row.date), <String>['2026-10-07', '2026-10-05']);
    final next = await payments.page(
      accountId: _account,
      limit: 2,
      before: (date: first.last.date, id: first.last.id),
    );
    expect(next.single.date, '2026-10-03');
  });

  test('a soft delete keeps the identity and hides the row', () async {
    final id = _id(1);
    await run(
      payments.planCreate(
        paymentFor(
          id: id,
          eventId: _id(2),
          amountMinor: -1000,
        ),
      ),
    );
    await run(payments.planSoftDelete(id: id, expectedRevision: 1));
    expect(await payments.page(accountId: _account), isEmpty);
    final row = await vault.database.customSelect(
      'SELECT deleted_at, revision FROM transactions WHERE id = ?',
      variables: [Variable(id)],
    ).getSingle();
    expect(row.data['deleted_at'], isNotNull);
    expect(row.data['revision'], 2);
    final registry = await vault.database.customSelect(
      'SELECT count(*) AS n FROM entity_registry WHERE id = ?',
      variables: [Variable(id)],
    ).getSingle();
    expect(registry.data['n'], 1);
  });

  test('splits must add to the payment amount', () {
    expect(
      () => payments.planCreate(
        paymentFor(
          id: _id(1),
          eventId: _id(2),
          amountMinor: -1000,
          splits: <PaymentSplitInput>[
            PaymentSplitInput(
              id: _id(3),
              categoryId: _groceries,
              amountMinor: -900,
            ),
          ],
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
