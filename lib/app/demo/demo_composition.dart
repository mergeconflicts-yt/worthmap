// P29 demo composition (PF-01: synthetic data only; never a release path).
//
// This is the development wiring: it opens an in-memory vault, seeds synthetic
// data, builds every Phase 2 gateway and hands them to one router. Nothing is
// written to disk, no key is used and no personal data can exist. The release
// path stays in `main.dart` behind `kDebugMode` and still waits for DB-A,
// PF-01 and the tab shell.
//
// DECISION-PENDING: PF-01, T07-CIPHER-BUILD.
library;

import 'package:flutter/foundation.dart';

import '../../core/dates.dart';
import '../../data/db/db.dart';
import '../../data/projections/category_read.dart';
import '../../data/projections/money_in.dart';
import '../../data/projections/spending.dart';
import '../../data/repositories/accounts.dart';
import '../../data/repositories/budgets.dart';
import '../../data/repositories/categories.dart';
import '../../data/repositories/drafts.dart';
import '../../data/repositories/history.dart';
import '../../data/repositories/imports.dart';
import '../../data/repositories/inbox.dart';
import '../../data/repositories/occurrences.dart';
import '../../data/repositories/payments.dart';
import '../../data/repositories/payments_read.dart';
import '../../data/repositories/schedules.dart';
import '../../data/repositories/transfers.dart';
import '../../data/repositories/write_plan.dart';
import '../../domain/periods/budget_month.dart';
import '../../domain/periods/period_math.dart';
import '../../domain/periods/period_range.dart';
import '../../features/import/import_models.dart';
import '../account_draft_store.dart';
import '../accounts_gateway.dart';
import '../history_gateway.dart';
import '../home_gateway.dart';
import '../import_gateway.dart';
import '../inbox_gateway.dart';
import '../payment_draft_store.dart';
import '../payments_gateway.dart';
import '../payments_read_gateway.dart';
import '../plan_gateway.dart';
import '../repeating_gateway.dart';
import '../router.dart';
import '../spending_gateway.dart';
import '../transfer_draft_store.dart';
import '../transfers_gateway.dart';
import '../wealth_gateway.dart';
import 'demo_gallery.dart';
import 'sample_statement.dart';

/// Builds the in-memory demo router with synthetic data.
final class DemoComposition {
  const DemoComposition._();

  static Future<ContourRouter> build({
    String? dbPath,
    void Function(Vault vault)? onVault,
  }) async {
    assert(kDebugMode, 'The demo composition is a debug-only path');
    final today = _localToday();
    final ids = _IdSource();
    String nextId() => ids.next();

    final Vault vault;
    if (dbPath == null || dbPath.isEmpty) {
      vault = await Vault.openInMemory(
        cipher: const UnverifiedOpenCipher(),
        keySource: () => '00' * 32,
        dbEpochFactory: nextId,
      );
    } else {
      // A real SQLite file, debug only. The cipher is the synthetic adapter
      // until DB-A and PF-01 close (DECISIONS P4-LOCAL-DEMO-VAULT).
      vault = await Vault.open(
        path: dbPath,
        cipher: const UnverifiedOpenCipher(),
        keySource: () => '00' * 32,
        dbEpochFactory: nextId,
      );
    }
    final db = vault.database;
    onVault?.call(vault);
    final rows =
        await db.customSelect('SELECT COUNT(*) AS n FROM accounts').getSingle();
    final needsSeed = (rows.data['n'] as int) == 0;

    DateTime clockUtc() => DateTime.now().toUtc();
    final commands = CommandRepository(
      db: db,
      clockUtc: clockUtc,
      newOperationId: nextId,
    );
    final accounts = AccountRepository(db: db, clockUtc: clockUtc);
    final categories = CategoryRepository(db: db, clockUtc: clockUtc);
    final payments = PaymentRepository(db: db, clockUtc: clockUtc);
    final transfers = TransferRepository(db: db, clockUtc: clockUtc);
    final drafts = DraftRepository(db: db, clockUtc: clockUtc);
    final budgets = BudgetRepository(
      db: db,
      clockUtc: clockUtc,
      newId: nextId,
    );
    final schedules = ScheduleRepository(
      db: db,
      clockUtc: clockUtc,
      newId: nextId,
    );
    final occurrences = OccurrenceRepository(
      db: db,
      clockUtc: clockUtc,
      newId: nextId,
    );
    final spendingProjection = SpendingProjection(db: db, clockUtc: clockUtc);
    final moneyIn = MoneyInProjection(db: db);
    final inboxRepository = InboxRepository(
      db: db,
      commands: commands,
      clockUtc: clockUtc,
      newEntityId: nextId,
    );
    final historyRepository = HistoryRepository(db: db);
    final importStaging = ImportStagingRepository(
      db: db,
      clockUtc: clockUtc,
      newEntityId: nextId,
    );

    Future<void> run(
      WritePlan plan,
      String commandType,
      String formType,
      String resultJson,
    ) async {
      final operationId = nextId();
      await commands.prepare(
        operationId: operationId,
        commandType: commandType,
        draftId: nextId(),
        formType: formType,
        payloadJson: '{"v":1}',
        payloadVersion: 1,
        codecVersion: 1,
        schemaVersion: 1,
      );
      await commands.execute(
        operationId: operationId,
        changes: plan.changes,
        effects: plan.apply,
        resultJson: resultJson,
      );
    }

    // Accounts.
    if (needsSeed) {
      await db.customStatement(
        "INSERT INTO currencies (code, minor_digits) VALUES ('USD', 2)",
      );

      Future<String> createAccount(
        String name,
        String type,
        String currency,
        int openingMinor, {
        bool liability = false,
        bool liquid = false,
      }) async {
        final id = nextId();
        final anchorId = nextId();
        final create = accounts.planCreateAccount(
          id: id,
          name: name,
          type: type,
          currency: currency,
          isLiability: liability,
          isLiquid: liquid,
        );
        final opening = accounts.planSetOpeningBalance(
          accountId: id,
          anchorId: anchorId,
          date:
              addMonths(LocalDate(today.year, today.month, 1), -13).toString(),
          balanceMinor: liability ? -openingMinor : openingMinor,
          currency: currency,
        );
        await run(
          WritePlan(
            changes: <ChangeLogEntry>[...create.changes, ...opening.changes],
            apply: () async {
              await create.apply();
              await opening.apply();
            },
          ),
          'account.create',
          'account',
          '{"account":"$id"}',
        );
        return id;
      }

      final checking = await createAccount(
        'Checking',
        'bank',
        'USD',
        645000,
        liquid: true,
      );
      final savings = await createAccount(
        'Savings',
        'bank',
        'USD',
        1500000,
        liquid: true,
      );
      final card = await createAccount(
        'Visa card',
        'card',
        'USD',
        124000,
        liability: true,
      );
      final brokerage = await createAccount(
        'Brokerage',
        'brokerage',
        'USD',
        12980000,
      );
      // Keep the brokerage id used by the closing balance read.
      assert(brokerage.isNotEmpty);

      // Categories.
      const expenseNames = <String>[
        'Rent',
        'Groceries',
        'Dining',
        'Coffee',
        'Transport',
        'Shopping',
        'Utilities',
        'Subscriptions',
      ];
      final expenseIds = <String, String>{};
      const essentials = <String>{
        'Rent',
        'Groceries',
        'Transport',
        'Utilities',
      };
      for (var index = 0; index < expenseNames.length; index++) {
        final id = nextId();
        expenseIds[expenseNames[index]] = id;
        await run(
          categories.planCreateCategory(
            id: id,
            name: expenseNames[index],
            kind: 'expense',
            sortOrder: index,
            isEssential: essentials.contains(expenseNames[index]),
          ),
          'category.create',
          'category',
          '{"category":"$id"}',
        );
      }
      final salaryId = nextId();
      await run(
        categories.planCreateCategory(
          id: salaryId,
          name: 'Salary',
          kind: 'income',
          sortOrder: 0,
        ),
        'category.create',
        'category',
        '{"category":"$salaryId"}',
      );

      // Budget limits for this month.
      final month = BudgetMonth.containing(today);
      final monthKey = '${month.start.year.toString().padLeft(4, '0')}-'
          '${month.start.month.toString().padLeft(2, '0')}';
      await run(
        await budgets.planSaveLimits(
          month: monthKey,
          currency: 'USD',
          startDate: month.start.toString(),
          endDate: month.end.toString(),
          limits: <String, int>{
            expenseIds['Rent']!: 180000,
            expenseIds['Groceries']!: 120000,
            expenseIds['Dining']!: 60000,
            expenseIds['Shopping']!: 50000,
            expenseIds['Transport']!: 40000,
            expenseIds['Utilities']!: 30000,
            expenseIds['Subscriptions']!: 10000,
          },
        ),
        'budget.saveLimits',
        'budget',
        '{"month":"$monthKey"}',
      );

      // Payments of this month.
      LocalDate day(int value) => LocalDate(
            today.year,
            today.month,
            value > today.day ? today.day : value,
          );
      Future<void> payment({
        required String accountId,
        required String date,
        required int amountMinor,
        required String kind,
        String? merchant,
        String? categoryId,
      }) async {
        final id = nextId();
        await run(
          payments.planCreate(
            NewPayment(
              id: id,
              eventId: nextId(),
              accountId: accountId,
              date: date,
              amountMinor: amountMinor,
              currency: 'USD',
              kind: kind,
              merchantName: merchant,
              categoryId: categoryId,
            ),
          ),
          'payment.create',
          'payment',
          '{"payment":"$id"}',
        );
      }

      // Twelve earlier months, so the net worth line has real points.
      for (var back = 12; back >= 1; back--) {
        final base = addMonths(month.start, -back);
        await payment(
          accountId: checking,
          date: LocalDate(base.year, base.month, 1).toString(),
          amountMinor: 400000,
          kind: 'income',
          merchant: 'Acme salary',
          categoryId: salaryId,
        );
        await payment(
          accountId: checking,
          date: LocalDate(base.year, base.month, 2).toString(),
          amountMinor: -120000,
          kind: 'expense',
          merchant: 'Rent',
          categoryId: expenseIds['Rent'],
        );
        await payment(
          accountId: checking,
          date: LocalDate(base.year, base.month, 6).toString(),
          amountMinor: -45000,
          kind: 'expense',
          merchant: 'Whole Foods',
          categoryId: expenseIds['Groceries'],
        );
      }

      await payment(
        accountId: checking,
        date: day(1).toString(),
        amountMinor: 820000,
        kind: 'income',
        merchant: 'Acme salary',
        categoryId: salaryId,
      );
      await payment(
        accountId: checking,
        date: day(1).toString(),
        amountMinor: -180000,
        kind: 'expense',
        merchant: 'Rent',
        categoryId: expenseIds['Rent'],
      );
      await payment(
        accountId: card,
        date: day(5).toString(),
        amountMinor: -8412,
        kind: 'expense',
        merchant: 'Whole Foods',
        categoryId: expenseIds['Groceries'],
      );
      await payment(
        accountId: card,
        date: day(9).toString(),
        amountMinor: -5200,
        kind: 'expense',
        merchant: 'Cafe Nero',
        categoryId: expenseIds['Dining'],
      );
      await payment(
        accountId: checking,
        date: day(8).toString(),
        amountMinor: -12000,
        kind: 'expense',
        merchant: 'City power',
        categoryId: expenseIds['Utilities'],
      );
      await payment(
        accountId: card,
        date: day(15).toString(),
        amountMinor: -24000,
        kind: 'expense',
        merchant: 'Uniqlo',
        categoryId: expenseIds['Shopping'],
      );
      await payment(
        accountId: checking,
        date: day(18).toString(),
        amountMinor: -3000,
        kind: 'expense',
        merchant: 'Metro',
        categoryId: expenseIds['Transport'],
      );
      await payment(
        accountId: card,
        date: day(18).toString(),
        amountMinor: -1799,
        kind: 'expense',
        merchant: 'Netflix',
        categoryId: expenseIds['Subscriptions'],
      );
      await payment(
        accountId: checking,
        date: day(20).toString(),
        amountMinor: -3175,
        kind: 'expense',
        merchant: 'PX Market',
        categoryId: expenseIds['Groceries'],
      );
      await payment(
        accountId: card,
        date: day(21).toString(),
        amountMinor: -640,
        kind: 'expense',
        merchant: 'Starbucks',
        categoryId: expenseIds['Coffee'],
      );

      // One transfer between two owned accounts.
      final transferEvent = nextId();
      await run(
        transfers.planCreate(
          NewTransfer(
            eventId: transferEvent,
            linkId: nextId(),
            sendingId: nextId(),
            receivingId: nextId(),
            fromAccountId: checking,
            toAccountId: savings,
            date: day(10).toString(),
            amountMinor: 50000,
            currency: 'USD',
          ),
        ),
        'transfer.create',
        'transfer',
        '{"event":"$transferEvent"}',
      );

      // Repeating payments.
      Future<void> schedule(
        String name,
        int amountMinor,
        String rrule,
        String startDate, {
        String kind = 'subscription',
      }) async {
        final id = nextId();
        await run(
          schedules.planCreate(
            scheduleId: id,
            fields: ScheduleFields(
              name: name,
              kind: kind,
              currency: 'USD',
              accountId: card,
              amountMinor: amountMinor,
              startDate: startDate,
              rrule: rrule,
            ),
          ),
          'schedule.create',
          'schedule',
          '{"schedule":"$id"}',
        );
      }

      await schedule(
        'Netflix',
        1799,
        'FREQ=MONTHLY;BYMONTHDAY=18',
        day(18).toString(),
      );
      await schedule(
        'Rent',
        180000,
        'FREQ=MONTHLY;BYMONTHDAY=1',
        day(1).toString(),
        kind: 'bill',
      );
      await schedule(
        'Car insurance',
        78000,
        'FREQ=YEARLY;BYMONTH=${(today.month + 3 - 1) % 12 + 1};'
            'BYMONTHDAY=4',
        LocalDate(
          today.month > 9 ? today.year + 1 : today.year,
          (today.month + 3 - 1) % 12 + 1,
          4,
        ).toString(),
        kind: 'premium',
      );

      // Expected occurrences for this month.
      final generator = OccurrenceGenerator(
        db: db,
        clockUtc: clockUtc,
        newId: nextId,
      );
      await generator.generate(
        window: DateRange(month.start, addDays(today, 30)),
      );

      // Rules.
      Future<void> rule(String pattern, String categoryId) async {
        final id = nextId();
        await run(
          categories.planCreateRule(
            id: id,
            matchType: 'merchantContains',
            pattern: pattern,
            categoryId: categoryId,
            createdFrom: 'user',
          ),
          'categoryRule.create',
          'categoryRule',
          '{"rule":"$id"}',
        );
      }

      await rule('Whole Foods', expenseIds['Groceries']!);
      await rule('Uber', expenseIds['Transport']!);
    } // needsSeed

    // Gateways.
    final accountsGateway = SqlAccountsGateway(
      accounts: accounts,
      commands: commands,
      today: () => today,
      newId: nextId,
    );
    final paymentsGateway = SqlPaymentsGateway(
      accounts: accounts,
      categories: categories,
      payments: payments,
      commands: commands,
      today: () => today,
      newId: nextId,
      lastCurrency: () => 'USD',
    );
    final transfersGateway = SqlTransfersGateway(
      accounts: accounts,
      transfers: transfers,
      commands: commands,
      today: () => today,
      newId: nextId,
    );
    final paymentsReadGateway = SqlPaymentsReadGateway(
      payments: payments,
      paymentReads: PaymentReadRepository(db: db),
      categoryReads: CategoryReadRepository(db: db),
      budgets: budgets,
      accounts: accounts,
      categories: categories,
      commands: commands,
      today: () => today,
      newOperationId: nextId,
    );
    final repeatingGateway = SqlRepeatingGateway(
      schedules: schedules,
      occurrences: occurrences,
      categories: categories,
      accounts: accounts,
      commands: commands,
      today: () => today,
      newOperationId: nextId,
    );
    final spendingGateway = SqlSpendingGateway(
      spending: spendingProjection,
      moneyIn: moneyIn,
      budgets: budgets,
      categories: categories,
      commands: commands,
      today: () => today,
      newOperationId: nextId,
      repeating: repeatingGateway,
      paymentsRead: paymentsReadGateway,
    );
    final inboxGateway = SqlInboxGateway(
      inbox: inboxRepository,
      today: () => today,
      newId: nextId,
    );
    final importGateway = SqlImportGateway(imports: importStaging);
    final homeGateway = SqlHomeGateway(
      accounts: accounts,
      categories: categories,
      inbox: inboxRepository,
      schedules: schedules,
      occurrences: occurrences,
      spending: spendingGateway,
      today: () => today,
      // Synthetic demo target (SPEC 13.2 sample). The release path passes
      // none until the goals record ships (G09, v1.1).
      netWorthTargetMinor: 100000000,
      netWorthTargetDate: LocalDate(2040, 12, 1),
      // Synthetic demo "today" change for the Quick look investment line.
      // Real holdings and prices arrive in Phase 5.
      investmentsTodayMinor: 55000,
    );
    final planGateway = SqlPlanGateway(
      occurrences: occurrences,
      today: () => today,
    );
    final wealthGateway = SqlWealthGateway(
      accounts: accounts,
      inbox: inboxRepository,
      today: () => today,
      // The same synthetic demo target as Home (SPEC 13.2 sample).
      targetMinor: 100000000,
      targetDate: LocalDate(2040, 12, 1),
      // Synthetic "Not in net worth" values from the SCREENS X40 sample.
      // The release path passes none until the records exist.
      unvestedMinor: 3159500,
      owedToYouMinor: 264000,
      dividendsMinor: 24500,
    );
    final historyGateway = SqlHistoryGateway(
      history: historyRepository,
      payments: payments,
      transfers: transfers,
      inbox: inboxRepository,
      commands: commands,
      newId: nextId,
    );

    return ContourRouter(
      accounts: accountsGateway,
      accountDrafts: SqlAccountDraftStore(drafts: drafts, newId: nextId),
      payments: paymentsGateway,
      paymentDrafts: SqlPaymentDraftStore(drafts: drafts, newId: nextId),
      transfers: transfersGateway,
      transferDrafts: SqlTransferDraftStore(drafts: drafts, newId: nextId),
      inbox: inboxGateway,
      spending: spendingGateway,
      paymentsRead: paymentsReadGateway,
      repeating: repeatingGateway,
      history: historyGateway,
      home: homeGateway,
      wealth: wealthGateway,
      plan: planGateway,
      imports: importGateway,
      importFiles: const SyntheticFileIntake(),
      importPasswords: MemoryImportPasswordVault(),
      initialLocation: const String.fromEnvironment(
        'DEMO_ROUTE',
        defaultValue: '/x03',
      ),
      demoEntries: true,
      gallery: const DemoGallery(),
    );
  }
}

LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}

/// A deterministic UUID v7 source for the demo rows.
final class _IdSource {
  int _value = 0;

  String next() {
    _value += 1;
    return '00000000-0000-7000-8000-${_value.toRadixString(16).padLeft(12, '0')}';
  }
}
