import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/categories.dart';
import 'package:contour/data/repositories/write_plan.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

const String _category = '00000000-0000-7000-8000-0000000000c1';
const String _rule = '00000000-0000-7000-8000-0000000000e1';
const String _tag = '00000000-0000-7000-8000-0000000000d1';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late CategoryRepository categories;
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
        return '00000000-0000-7000-8000-0000000000b$operation';
      },
    );
    categories = CategoryRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    operation = 0;
  });

  tearDown(() async {
    await commands.dispose();
    await vault.close();
  });

  Future<void> run(WritePlan plan) async {
    final op = '00000000-0000-7000-8000-0000000000a$operation';
    await commands.prepare(
      operationId: op,
      commandType: 'test.write',
      draftId: '00000000-0000-7000-8000-0000000000f$operation',
      formType: 'test',
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

  test('create, rename and archive keep history and identity', () async {
    await run(
      categories.planCreateCategory(
        id: _category,
        name: 'Groceries',
        kind: 'expense',
      ),
    );
    var list = await categories.list(kind: 'expense');
    expect(list.single.name, 'Groceries');
    expect(list.single.revision, 1);

    await run(
      categories.planRenameCategory(
        id: _category,
        name: 'Food',
        expectedRevision: 1,
      ),
    );
    list = await categories.list(kind: 'expense');
    expect(list.single.name, 'Food');
    expect(list.single.revision, 2);

    await run(
      categories.planArchiveCategory(id: _category, expectedRevision: 2),
    );
    expect(await categories.list(kind: 'expense'), isEmpty);
    expect(
      await categories.list(kind: 'expense', includeArchived: true),
      hasLength(1),
    );
    final kinds = await vault.database.customSelect(
      'SELECT entity_kind FROM entity_registry WHERE id = ?',
      variables: [const Variable(_category)],
    ).getSingle();
    expect(kinds.data['entity_kind'], 'categories');
    final log = await vault.database.customSelect(
      'SELECT count(*) AS n FROM change_log WHERE entity_id = ?',
      variables: [const Variable(_category)],
    ).getSingle();
    expect(log.data['n'], 3);
  });

  test('a stale rename is rejected and changes nothing', () async {
    await run(
      categories.planCreateCategory(
        id: _category,
        name: 'Groceries',
        kind: 'expense',
      ),
    );
    await expectLater(
      run(
        categories.planRenameCategory(
          id: _category,
          name: 'Food',
          expectedRevision: 9,
        ),
      ),
      throwsA(anything),
    );
    expect((await categories.list(kind: 'expense')).single.name, 'Groceries');
  });

  test('a rule keeps its priority and origin', () async {
    await run(
      categories.planCreateCategory(
        id: _category,
        name: 'Groceries',
        kind: 'expense',
      ),
    );
    await run(
      categories.planCreateRule(
        id: _rule,
        matchType: 'merchantContains',
        pattern: 'market',
        categoryId: _category,
        createdFrom: 'user',
        priority: 5,
      ),
    );
    final rules = await categories.rules();
    expect(rules.single.pattern, 'market');
    expect(rules.single.priority, 5);
    expect(rules.single.createdFrom, 'user');
    expect(
      () => categories.planCreateRule(
        id: '00000000-0000-7000-8000-0000000000e2',
        matchType: 'unknown',
        pattern: 'x',
        categoryId: _category,
        createdFrom: 'user',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('a tag is unique while live', () async {
    await run(categories.planCreateTag(id: _tag, name: 'Household'));
    expect((await categories.tags()).single.name, 'Household');
    await expectLater(
      run(
        categories.planCreateTag(
          id: '00000000-0000-7000-8000-0000000000d2',
          name: 'Household',
        ),
      ),
      throwsA(anything),
    );
  });
}
