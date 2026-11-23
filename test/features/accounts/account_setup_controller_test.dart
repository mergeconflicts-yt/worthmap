import 'package:contour/core/dates.dart';
import 'package:contour/features/accounts/account_draft.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/accounts/account_setup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeGateway implements AccountsGateway {
  AccountSetup? last;
  int calls = 0;
  Object? failure;
  List<AccountSummary> accounts = <AccountSummary>[];

  @override
  Future<List<AccountSummary>> listAccounts() async => accounts;

  @override
  Future<AccountSummary> createAccount(AccountSetup setup) async {
    calls += 1;
    last = setup;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return AccountSummary(
      id: 'account-1',
      name: setup.name,
      kind: setup.kind,
      currencyCode: setup.currencyCode,
      balanceMinor: setup.kind.isLiability
          ? -setup.openingBalanceMinor
          : setup.openingBalanceMinor,
    );
  }
}

AccountSetupController _controller(
  _FakeGateway gateway, {
  LocalDate? today,
  AccountKind? kind,
}) =>
    AccountSetupController(
      gateway: gateway,
      today: today ?? LocalDate(2026, 11, 22),
      kind: kind,
    );

void main() {
  final today = LocalDate(2026, 11, 22);

  test('a fresh draft is Missing and cannot save', () {
    final controller = _controller(_FakeGateway());
    expect(controller.openingAmount, isNull);
    expect(controller.openingDate, today);
    expect(controller.canSave, isFalse);
  });

  test('the keypad builds a whole amount and a decimal amount', () {
    final controller = _controller(_FakeGateway());
    for (final key in <String>['6', '4', '5', '0']) {
      controller.pressKey(key);
    }
    expect(controller.openingAmount!.minor, 645000);
    expect(controller.amountText, '6450');

    controller.deleteKey();
    controller.deleteKey();
    controller.deleteKey();
    controller.deleteKey();
    expect(controller.openingAmount, isNull);

    for (final key in <String>['1', '2', '.', '3', '4']) {
      controller.pressKey(key);
    }
    expect(controller.openingAmount!.minor, 1234);
    controller.pressKey('5');
    expect(controller.openingAmount!.minor, 1234);
  });

  test('an entered zero is real, not Missing', () {
    final controller = _controller(_FakeGateway());
    controller.pressKey('0');
    expect(controller.openingAmount, isNotNull);
    expect(controller.openingAmount!.isZero, isTrue);
    expect(controller.amountInvalid, isFalse);
  });

  test('a card kind does not count as cash', () {
    final controller = _controller(_FakeGateway());
    expect(controller.countsAsCash, isTrue);
    controller.setKind(AccountKind.card);
    expect(controller.countsAsCash, isFalse);
    controller.setKind(AccountKind.cash);
    expect(controller.countsAsCash, isTrue);
  });

  test('a valid save sends one setup with the inclusive date', () async {
    final gateway = _FakeGateway();
    final controller = _controller(gateway)
      ..setName('  Checking  ')
      ..setKind(AccountKind.bank)
      ..setDate(LocalDate(2026, 10, 13));
    for (final key in <String>['6', '4', '5', '0']) {
      controller.pressKey(key);
    }
    expect(controller.canSave, isTrue);

    final saved = await controller.save();
    expect(saved, isNotNull);
    expect(controller.status, AccountSetupStatus.saved);
    expect(gateway.calls, 1);
    expect(gateway.last!.name, 'Checking');
    expect(gateway.last!.kind, AccountKind.bank);
    expect(gateway.last!.currencyCode, 'USD');
    expect(gateway.last!.openingBalanceMinor, 645000);
    expect(gateway.last!.openingDate, LocalDate(2026, 10, 13));
    expect(gateway.last!.countsAsCash, isTrue);
    expect(gateway.last!.includeInNetWorth, isTrue);
  });

  test('a card save sends the owed amount as a positive number', () async {
    final gateway = _FakeGateway();
    final controller = _controller(gateway)..setKind(AccountKind.card);
    controller.setName('Visa');
    for (final key in <String>['1', '2', '4', '0']) {
      controller.pressKey(key);
    }
    await controller.save();
    expect(gateway.last!.openingBalanceMinor, 124000);
    expect(gateway.last!.countsAsCash, isFalse);
    expect(gateway.last!.kind.isLiability, isTrue);
  });

  test('a missing amount stops the save and writes nothing', () async {
    final gateway = _FakeGateway();
    final controller = _controller(gateway)
      ..setName('Checking')
      ..setKind(AccountKind.bank);
    expect(controller.canSave, isFalse);
    final saved = await controller.save();
    expect(saved, isNull);
    expect(controller.errorCode, AccountsErrorCode.invalidSetup);
    expect(gateway.calls, 0);
  });

  test('a failed save keeps the draft and a later edit clears the error',
      () async {
    final gateway = _FakeGateway()
      ..failure = const AccountsError(
        AccountsErrorCode.notWired,
      );
    final controller = _controller(gateway)
      ..setName('Checking')
      ..setKind(AccountKind.bank);
    controller.pressKey('5');
    final saved = await controller.save();
    expect(saved, isNull);
    expect(controller.status, AccountSetupStatus.failed);
    expect(controller.errorCode, AccountsErrorCode.notWired);
    expect(controller.name, 'Checking');
    expect(controller.amountText, '5');

    controller.setName('Checking 2');
    expect(controller.status, AccountSetupStatus.editing);
    expect(controller.errorCode, isNull);
  });

  test('the inclusive date is today by default and can change', () {
    final controller = _controller(_FakeGateway());
    expect(controller.openingDate, today);
    controller.setDate(LocalDate(2026, 10, 13));
    expect(controller.openingDate, LocalDate(2026, 10, 13));
    expect(controller.canSave, isFalse);
  });

  test('a currency change keeps the entered digits and reads them anew', () {
    final controller = _controller(_FakeGateway());
    for (final key in <String>['1', '0', '0', '0']) {
      controller.pressKey(key);
    }
    expect(controller.openingAmount!.minor, 100000);
    controller.setCurrency('JPY');
    expect(controller.currencyCode, 'JPY');
    expect(controller.openingAmount!.minor, 1000);
  });

  test('a stored draft resumes and a new edit writes it again', () async {
    final store = MemoryAccountDraftStore()
      ..draft = AccountDraft(
        name: 'Savings',
        kind: AccountKind.bank,
        currencyCode: 'USD',
        amountText: '1200',
        date: LocalDate(2026, 10, 1),
        countsAsCash: true,
        includeInNetWorth: true,
      );
    final controller = AccountSetupController(
      gateway: _FakeGateway(),
      today: today,
      drafts: store,
    );
    await controller.loadDraft();
    expect(controller.name, 'Savings');
    expect(controller.amountText, '1200');
    expect(controller.openingAmount!.minor, 120000);
    expect(controller.openingDate, LocalDate(2026, 10, 1));
    expect(controller.hasDraft, isTrue);

    controller.pressKey('3');
    await controller.pendingDraftWrite;
    expect(store.draft!.amountText, '12003');
  });

  test('a successful save discards the draft', () async {
    final store = MemoryAccountDraftStore();
    final controller = AccountSetupController(
      gateway: _FakeGateway(),
      today: today,
      drafts: store,
    );
    controller.setName('Checking');
    controller.setKind(AccountKind.bank);
    controller.pressKey('5');
    await controller.pendingDraftWrite;
    expect(store.draft, isNotNull);

    await controller.save();
    expect(store.draft, isNull);
    expect(controller.hasDraft, isFalse);
  });

  test('an unsupported draft is kept and blocks new writes', () async {
    final store = _UnsupportedDraftStore();
    final controller = AccountSetupController(
      gateway: _FakeGateway(),
      today: today,
      drafts: store,
    );
    await controller.loadDraft();
    expect(controller.draftUnsupported, isTrue);
    expect(controller.hasDraft, isTrue);

    controller.setName('Checking');
    await controller.pendingDraftWrite;
    expect(store.saves, 0);

    await controller.discardDraft();
    expect(store.discards, 1);
    expect(controller.hasDraft, isFalse);
    expect(controller.draftUnsupported, isFalse);
  });

  test('a user edit before the draft read wins', () async {
    final store = MemoryAccountDraftStore()
      ..draft = AccountDraft(
        name: 'Old name',
        kind: AccountKind.bank,
        currencyCode: 'USD',
        amountText: '10',
        date: today,
        countsAsCash: true,
        includeInNetWorth: true,
      );
    final controller = AccountSetupController(
      gateway: _FakeGateway(),
      today: today,
      drafts: store,
    );
    controller.setName('New name');
    await controller.loadDraft();
    expect(controller.name, 'New name');
  });
}

/// Reports an unsupported draft and counts writes.
final class _UnsupportedDraftStore implements AccountDraftStore {
  int saves = 0;
  int discards = 0;

  @override
  Future<AccountDraftLoad> load() async => const UnsupportedAccountDraft();

  @override
  Future<void> save(AccountDraft draft) async => saves += 1;

  @override
  Future<void> discard() async => discards += 1;
}
