import 'package:contour/app/payments_read_gateway.dart';
import 'package:contour/core/dates.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/projections/category_read.dart';
import 'package:contour/data/repositories/accounts.dart';
import 'package:contour/data/repositories/budgets.dart';
import 'package:contour/data/repositories/categories.dart';
import 'package:contour/data/repositories/payments.dart';
import 'package:contour/data/repositories/payments_read.dart';
import 'package:contour/features/spending/payments_models.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

String _id(int n) =>
    '00000000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late PaymentRepository payments;
  late SqlPaymentsReadGateway gateway;
  var nextId = 1200;
  final today = LocalDate(2026, 11, 22);
  const nowMs = 1700000000000;
  late String accountId;
  late String paymentId;

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
    payments = PaymentRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    accountId = _id(1100);
    await vault.database.customStatement(
      'INSERT INTO accounts (id, created_at, updated_at, deleted_at, revision, '
      'name, type, currency, is_liability, is_liquid, include_in_net_worth) '
      "VALUES (?, ?, ?, NULL, 1, 'Checking', 'bank', 'USD', 0, 1, 1)",
      [accountId, nowMs, nowMs],
    );
    await vault.database.customStatement(
      'INSERT INTO balance_anchors (id, created_at, updated_at, deleted_at, '
      'revision, account_id, date, balance_minor, currency, source, '
      'source_identity_id, inclusive, supersedes_anchor_id) '
      "VALUES (?, ?, ?, NULL, 1, ?, '2026-11-01', 100000, 'USD', 'manual', "
      'NULL, 1, NULL)',
      [_id(1101), nowMs, nowMs, accountId],
    );
    paymentId = _id(1102);
    final plan = payments.planCreate(
      NewPayment(
        id: paymentId,
        eventId: _id(1103),
        accountId: accountId,
        date: '2026-11-20',
        amountMinor: -4218,
        currency: 'USD',
        kind: 'expense',
        merchantName: 'Whole Foods',
      ),
    );
    final operationId = _id(1104);
    await commands.prepare(
      operationId: operationId,
      commandType: 'payment.create',
      draftId: _id(1105),
      formType: 'payment',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    await commands.execute(
      operationId: operationId,
      changes: plan.changes,
      effects: plan.apply,
      resultJson: '{"payment":"$paymentId"}',
    );
    gateway = SqlPaymentsReadGateway(
      payments: payments,
      paymentReads: PaymentReadRepository(db: vault.database),
      categoryReads: CategoryReadRepository(db: vault.database),
      budgets: BudgetRepository(
        db: vault.database,
        clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      ),
      accounts: accounts,
      categories: CategoryRepository(
        db: vault.database,
        clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      ),
      commands: commands,
      today: () => today,
      newOperationId: () => _id(nextId++),
    );
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<int> balance() async {
    final row = await vault.database.customSelect(
      'SELECT balance_minor FROM balance_anchors WHERE account_id = ? '
      'AND deleted_at IS NULL',
      variables: [Variable(accountId)],
    ).getSingle();
    final anchor = row.data['balance_minor'] as int;
    final postings = await vault.database.customSelect(
      'SELECT coalesce(sum(amount_minor), 0) AS n FROM transactions '
      "WHERE account_id = ? AND deleted_at IS NULL AND date > '2026-11-01'",
      variables: [Variable(accountId)],
    ).getSingle();
    return anchor + (postings.data['n'] as int);
  }

  test('delete and Undo change the balance once (F08-C)', () async {
    final before = await balance();
    final detail = await gateway.loadPayment(paymentId);
    expect(detail, isNotNull);

    final deleted = await gateway.deletePayment(detail!);

    expect(await balance(), before + 4218);
    expect(await gateway.loadPayment(paymentId), isNull);

    await gateway.restorePayment(deleted);

    expect(await balance(), before);
    expect(await gateway.loadPayment(paymentId), isNotNull);
  });

  test('the list count follows the delete and the restore', () async {
    const filter = PaymentFilter(
      period: PaymentPeriod.thisMonth,
      show: PaymentShowFilter.moneyOut,
    );
    expect((await gateway.loadPayments(filter)).count, 1);

    final detail = await gateway.loadPayment(paymentId);
    final deleted = await gateway.deletePayment(detail!);
    expect((await gateway.loadPayments(filter)).count, 0);

    await gateway.restorePayment(deleted);
    expect((await gateway.loadPayments(filter)).count, 1);
  });
}
