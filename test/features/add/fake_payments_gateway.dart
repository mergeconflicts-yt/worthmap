import 'package:contour/core/dates.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/add/payment_models.dart';

/// An in-memory payment port for the P22 tests. It writes no database.
final class FakePaymentsGateway implements PaymentsGateway {
  FakePaymentsGateway({
    List<AccountSummary>? accounts,
    List<CategorySummary>? expenseCategories,
    List<CategorySummary>? incomeCategories,
    List<TagSummary>? tags,
    this.lastCurrencyCode = 'USD',
  })  : accounts = accounts ?? <AccountSummary>[_checking],
        expenseCategories = expenseCategories ?? <CategorySummary>[_dining],
        incomeCategories = incomeCategories ?? <CategorySummary>[_salary],
        tags = tags ?? <TagSummary>[_household];

  static const AccountSummary _checking = AccountSummary(
    id: 'account-1',
    name: 'Checking',
    kind: AccountKind.bank,
    currencyCode: 'USD',
    balanceMinor: 645000,
  );

  static const CategorySummary _dining = CategorySummary(
    id: 'category-dining',
    name: 'Dining',
  );

  static const CategorySummary _salary = CategorySummary(
    id: 'category-salary',
    name: 'Salary',
  );

  static const TagSummary _household = TagSummary(
    id: 'tag-1',
    name: 'Household',
  );

  List<AccountSummary> accounts;
  List<CategorySummary> expenseCategories;
  List<CategorySummary> incomeCategories;
  List<TagSummary> tags;
  String lastCurrencyCode;

  final List<PaymentSetup> saved = <PaymentSetup>[];
  final List<String> payloads = <String>[];
  int loadCalls = 0;
  int undoCalls = 0;
  Object? loadFailure;
  Object? saveFailure;
  Object? undoFailure;

  @override
  Future<PaymentFormData> loadForm({required PaymentKind kind}) async {
    loadCalls += 1;
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return PaymentFormData(
      accounts: accounts,
      categories: kind.isIncome ? incomeCategories : expenseCategories,
      tags: tags,
      lastCurrencyCode: lastCurrencyCode,
    );
  }

  @override
  Future<SavedPayment> savePayment({
    required PaymentSetup setup,
    String? draftId,
    String? payloadJson,
  }) async {
    final failure = saveFailure;
    if (failure != null) {
      throw failure;
    }
    saved.add(setup);
    payloads.add(payloadJson ?? '');
    return SavedPayment(
      paymentId: setup.edit?.paymentId ?? 'payment-${saved.length}',
      eventId: setup.edit?.eventId ?? 'event-${saved.length}',
      operationId: 'operation-${saved.length}',
      amountMinor: setup.amountMinor,
      currencyCode: setup.currencyCode,
      kind: setup.kind,
      date: setup.date,
      edit: setup.edit != null,
    );
  }

  @override
  Future<void> undoPayment(SavedPayment saved) async {
    undoCalls += 1;
    final failure = undoFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

/// A prepared account row for a test.
AccountSummary testAccount({
  String id = 'account-1',
  String name = 'Checking',
  int? balanceMinor = 645000,
}) =>
    AccountSummary(
      id: id,
      name: name,
      kind: AccountKind.bank,
      currencyCode: 'USD',
      balanceMinor: balanceMinor,
    );

/// A prepared local date for a test.
LocalDate testToday() => LocalDate(2026, 11, 22);
