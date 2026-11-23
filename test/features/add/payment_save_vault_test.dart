import 'package:contour/app/accounts_gateway.dart';
import 'package:contour/app/payment_draft_store.dart';
import 'package:contour/app/payments_gateway.dart';
import 'package:contour/core/dates.dart';
import 'package:contour/data/db/db.dart';
import 'package:contour/data/repositories/accounts.dart';
import 'package:contour/data/repositories/categories.dart';
import 'package:contour/data/repositories/drafts.dart';
import 'package:contour/data/repositories/payments.dart';
import 'package:contour/domain/importers/quick_add_parser.dart' show DraftField;
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/add/payment_draft.dart';
import 'package:contour/features/add/payment_form_controller.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

String _id(int n) =>
    '00000000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

void main() {
  late Vault vault;
  late CommandRepository commands;
  late SqlPaymentsGateway gateway;
  late SqlPaymentDraftStore draftStore;
  late PaymentFormController controller;
  late AccountSummary checking;
  var nextId = 200;
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
    final categories = CategoryRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
    final payments = PaymentRepository(
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
    gateway = SqlPaymentsGateway(
      accounts: accounts,
      categories: categories,
      payments: payments,
      commands: commands,
      today: () => today,
      newId: () => _id(nextId++),
      lastCurrency: () => 'USD',
    );
    draftStore = SqlPaymentDraftStore(
      drafts: DraftRepository(
        db: vault.database,
        clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      ),
      newId: () => _id(nextId++),
    );
    for (final (index, name) in <String>['Groceries', 'Household'].indexed) {
      await vault.database.customStatement(
        'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
        'revision, name, parent_id, kind, sort_order, archived) '
        'VALUES (?, ?, ?, NULL, 1, ?, NULL, ?, 0, 0)',
        [_id(300 + index), nowMs, nowMs, name, 'expense'],
      );
    }
    await vault.database.customStatement(
      'INSERT INTO tags (id, created_at, updated_at, deleted_at, revision, '
      "name) VALUES (?, ?, ?, NULL, 1, 'Household')",
      [_id(320), nowMs, nowMs],
    );
    controller = PaymentFormController(
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

  Future<int?> balance() async {
    final listed = (await gateway.loadForm(kind: PaymentKind.expense))
        .accounts
        .firstWhere((account) => account.id == checking.id);
    return listed.balanceMinor;
  }

  test('one Save writes the payment, its splits, the event and ChangeLog',
      () async {
    for (final key in '121.30'.split('')) {
      controller.pressKey(key);
    }
    controller
      ..selectAccount(checking)
      ..setMerchant('Whole Foods')
      ..setSplitParts(const <PaymentDraftSplit>[
        PaymentDraftSplit(
          categoryId: '00000000-0000-7000-8000-00000000012c',
          name: 'Groceries',
          amountText: '84.12',
        ),
        PaymentDraftSplit(
          categoryId: '00000000-0000-7000-8000-00000000012d',
          name: 'Household',
          amountText: '37.18',
        ),
      ]);

    final saved = await controller.save();
    expect(saved, isNotNull, reason: '${controller.errorCode}');

    expect(await count('SELECT count(*) FROM transactions'), 1);
    expect(
      await count('SELECT count(*) FROM transaction_splits'),
      2,
    );
    expect(await count('SELECT count(*) FROM financial_events'), 1);
    final logged = await vault.database.customSelect(
      'SELECT count(*) AS n FROM change_log WHERE operation_id = ?',
      variables: [Variable(saved!.operationId)],
    ).getSingle();
    expect(logged.data['n'], 4);
    expect(await balance(), 645000 - 12130);
    expect(controller.hasDraft, isFalse, reason: 'Save clears the draft');
    final draft = await vault.database
        .customSelect(
          "SELECT status FROM draft_headers WHERE form_type = 'payment'",
        )
        .getSingle();
    expect(draft.data['status'], 'committed');
  });

  test('a repeated Save of one draft returns one receipt and one payment',
      () async {
    final draftId = await draftStore.save(
      PaymentFormDraft(
        kind: PaymentKind.expense,
        amountText: '24',
        currencyCode: 'USD',
        date: today,
        accountId: checking.id,
        categoryId: null,
        tagIds: const <String>[],
        merchantText: '',
        splits: const <PaymentDraftSplit>[],
        unsureFields: const <DraftField>{},
      ),
    );
    const payload = '{"schema":1,"amount":"24"}';
    final setup = PaymentSetup(
      kind: PaymentKind.expense,
      amountMinor: -2400,
      currencyCode: 'USD',
      date: today,
      accountId: checking.id,
      merchantName: null,
      tagIds: const <String>[],
      splits: const <PaymentSplitSetup>[],
    );

    final first = await gateway.savePayment(
      setup: setup,
      draftId: draftId,
      payloadJson: payload,
    );
    final second = await gateway.savePayment(
      setup: setup,
      draftId: draftId,
      payloadJson: payload,
    );

    expect(second.operationId, first.operationId);
    expect(second.paymentId, first.paymentId);
    expect(await count('SELECT count(*) FROM transactions'), 1);
    final receipts = await vault.database.customSelect(
      'SELECT count(*) AS n FROM operation_receipts WHERE operation_id = ?',
      variables: [Variable(first.operationId)],
    ).getSingle();
    expect(receipts.data['n'], 1);
  });

  test('an edit changes the record once and keeps its identity', () async {
    for (final key in '40'.split('')) {
      controller.pressKey(key);
    }
    controller.selectAccount(checking);
    final created = await controller.save();
    expect(created, isNotNull, reason: '${controller.errorCode}');

    final edit = PaymentEdit(
      paymentId: created!.paymentId,
      eventId: created.eventId,
      expectedRevision: 1,
    );
    final editor = PaymentFormController(
      gateway: gateway,
      today: today,
      editing: edit,
    );
    await editor.initialize();
    for (final key in '55'.split('')) {
      editor.pressKey(key);
    }
    editor.selectAccount(checking);
    final edited = await editor.save();
    editor.dispose();

    expect(edited, isNotNull, reason: '${editor.errorCode}');
    expect(edited!.paymentId, created.paymentId);
    expect(edited.edit, isTrue);
    expect(await count('SELECT count(*) FROM transactions'), 1);
    expect(await count('SELECT count(*) FROM financial_events'), 1);
    final row = await vault.database
        .customSelect('SELECT amount_minor, revision FROM transactions')
        .getSingle();
    expect(row.data['amount_minor'], -5500);
    expect(row.data['revision'], 2);
    expect(await balance(), 645000 - 5500);
  });

  test('Undo soft-deletes the payment and its splits and restores the balance',
      () async {
    for (final key in '80'.split('')) {
      controller.pressKey(key);
    }
    controller
      ..selectAccount(checking)
      ..setSplitParts(const <PaymentDraftSplit>[
        PaymentDraftSplit(
          categoryId: '00000000-0000-7000-8000-00000000012c',
          name: 'Groceries',
          amountText: '50',
        ),
        PaymentDraftSplit(
          categoryId: '00000000-0000-7000-8000-00000000012d',
          name: 'Household',
          amountText: '30',
        ),
      ]);
    final saved = await controller.save();
    expect(saved, isNotNull, reason: '${controller.errorCode}');
    expect(await balance(), 645000 - 8000);

    await gateway.undoPayment(saved!);

    expect(await balance(), 645000);
    expect(
      await count(
        'SELECT count(*) FROM transactions WHERE deleted_at IS NULL',
      ),
      0,
    );
    expect(
      await count(
        'SELECT count(*) FROM transaction_splits WHERE deleted_at IS NULL',
      ),
      0,
    );
    expect(
      await count(
        'SELECT count(*) FROM financial_events WHERE deleted_at IS NULL',
      ),
      0,
    );
    // Undo keeps every identity and writes its own compensating ChangeLog.
    final soft = await vault.database
        .customSelect(
          "SELECT count(*) AS n FROM change_log WHERE change_kind = 'softDelete'",
        )
        .getSingle();
    expect(soft.data['n'], 4, reason: 'event, payment and two splits');
  });
}
