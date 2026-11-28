import 'package:contour/app/spending_gateway.dart';
import 'package:contour/core/dates.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/projections/money_in.dart';
import 'package:contour/data/projections/spending.dart';
import 'package:contour/data/repositories/budgets.dart';
import 'package:contour/data/repositories/categories.dart';
import 'package:flutter_test/flutter_test.dart';

String _id(int n) =>
    '00000000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late SqlSpendingGateway gateway;
  var nextId = 900;
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
    final categories = CategoryRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    for (final (index, name) in <String>[
      'Rent',
      'Groceries',
      'Dining',
    ].indexed) {
      await vault.database.customStatement(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        "VALUES (?, ?, ?, NULL, 1, ?, NULL, 'expense', 0, 0)",
        [_id(950 + index), nowMs, nowMs, name],
      );
    }
    gateway = SqlSpendingGateway(
      spending: SpendingProjection(
        db: vault.database,
        clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      ),
      moneyIn: MoneyInProjection(db: vault.database),
      budgets: BudgetRepository(
        db: vault.database,
        clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
        newId: () => _id(nextId++),
      ),
      categories: categories,
      commands: commands,
      today: () => today,
      newOperationId: () => _id(nextId++),
    );
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<int> count(String sql) async {
    final row = await vault.database.customSelect(sql).getSingle();
    return row.data.values.first! as int;
  }

  test('SaveLimits writes the limits and no payment (F08-E)', () async {
    final limits = await gateway.loadLimits();
    expect(limits.rows, hasLength(3));
    expect(limits.totalMinor, isNull, reason: 'no limit is set yet');

    await gateway.saveLimits(<String, int>{
      limits.rows[0].categoryId: 180000,
      limits.rows[1].categoryId: 120000,
    });

    final saved = await gateway.loadLimits();
    expect(saved.totalMinor, 300000);
    expect(saved.categoryCount, 2);
    expect(await count('SELECT count(*) FROM budget_limits'), 2);
    expect(await count('SELECT count(*) FROM transactions'), 0);
  });

  test('loadRows reads the budget month and the empty summaries', () async {
    final rows = await gateway.loadRows();
    expect(rows.month, LocalDate(2026, 10, 1));
    expect(rows.whereCount, 0);
    expect(rows.leftMinor, isNull);
    expect(rows.limitMinor, isNull);
    expect(rows.moneyInMinor, isNull);
    expect(rows.moneyInAverageMinor, isNull);
    expect(rows.paymentsCount, isNull);
    expect(rows.repeatingCount, 0);
    expect(rows.repeatingChanges, 0);
    expect(rows.repeatingMonthlyMinor, isNull);
  });

  test('a fresh save is one command with a receipt', () async {
    await gateway.saveLimits(<String, int>{
      '00000000-0000-7000-8000-0000000003b6': 100000,
    });
    expect(await count('SELECT count(*) FROM operation_receipts'), 1);
  });
}
