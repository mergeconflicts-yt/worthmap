import 'package:contour/core/dates.dart';
import 'package:contour/domain/importers/quick_add_parser.dart' show DraftField;
import 'package:contour/features/add/payment_draft.dart';
import 'package:contour/features/add/payment_form_controller.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_payments_gateway.dart';

Future<PaymentFormController> _controller({
  FakePaymentsGateway? gateway,
  PaymentDraftStore? drafts,
  PaymentEdit? editing,
  PaymentKind kind = PaymentKind.expense,
}) async {
  final controller = PaymentFormController(
    gateway: gateway ?? FakePaymentsGateway(),
    today: testToday(),
    drafts: drafts,
    editing: editing,
    kind: kind,
  );
  await controller.initialize();
  return controller;
}

void _type(PaymentFormController controller, String digits) {
  for (final key in digits.split('')) {
    controller.pressKey(key);
  }
}

void main() {
  test('amount first: no amount or no account keeps Save inactive', () async {
    final controller = await _controller();
    expect(controller.canSave, isFalse);

    _type(controller, '24');
    expect(controller.enteredAmount!.minor, 2400);
    expect(controller.canSave, isFalse, reason: 'no account yet');

    controller.selectAccount(controller.accounts.first);
    expect(controller.canSave, isTrue, reason: 'a category is optional');
    controller.dispose();
  });

  test('an expense is negative and income is positive', () async {
    final controller = await _controller();
    _type(controller, '24');
    controller.selectAccount(controller.accounts.first);
    expect(controller.signedAmountMinor, -2400);

    controller.setKind(PaymentKind.income);
    await pumpEventQueue();
    expect(controller.signedAmountMinor, 2400);
    controller.dispose();
  });

  test('a typed sentence fills amount, merchant, date and category', () async {
    final controller = await _controller();
    final parsed = await controller.parseSentence(
      'lunch 18 at subway yesterday',
    );

    expect(parsed.hasAmount, isTrue);
    expect(controller.amountText, '18.00');
    expect(controller.merchantText, 'subway');
    expect(controller.date, LocalDate(2026, 11, 21));
    expect(controller.category, isNull, reason: 'the name has no stored row');
    expect(
      controller.unsureFields,
      isEmpty,
    );
    controller.dispose();
  });

  test('a sentence with a stored category fills the chip', () async {
    final gateway = FakePaymentsGateway(
      expenseCategories: const <CategorySummary>[
        CategorySummary(id: 'c1', name: 'Dining'),
      ],
    );
    final controller = await _controller(gateway: gateway);
    await controller.parseSentence('coffee 4 #Dining');

    expect(controller.category?.id, 'c1');
    controller.dispose();
  });

  test('an income sentence switches the type and its categories', () async {
    final gateway = FakePaymentsGateway(
      incomeCategories: const <CategorySummary>[
        CategorySummary(id: 'i1', name: 'Salary'),
      ],
    );
    final controller = await _controller(gateway: gateway);
    await controller.parseSentence('salary 5000');

    expect(controller.kind, PaymentKind.income);
    expect(controller.signedAmountMinor, 500000);
    expect(controller.categories.single.id, 'i1');
    expect(gateway.loadCalls, greaterThanOrEqualTo(2));
    controller.dispose();
  });

  test('a split is exact only at zero remainder with two parts', () async {
    final controller = await _controller();
    _type(controller, '100');
    controller.selectAccount(controller.accounts.first);

    controller.setSplitParts(const <PaymentDraftSplit>[
      PaymentDraftSplit(categoryId: 'a', name: 'A', amountText: '50'),
      PaymentDraftSplit(categoryId: 'b', name: 'B', amountText: '50'),
    ]);
    expect(controller.splitRemainder!.isZero, isTrue);
    expect(controller.splitIsExact, isTrue);
    expect(controller.canSave, isTrue);

    controller.setSplitParts(const <PaymentDraftSplit>[
      PaymentDraftSplit(categoryId: 'a', name: 'A', amountText: '50'),
      PaymentDraftSplit(categoryId: 'b', name: 'B', amountText: '40'),
    ]);
    expect(controller.splitRemainder!.minor, 1000);
    expect(controller.canSave, isFalse);

    controller.setSplitParts(const <PaymentDraftSplit>[
      PaymentDraftSplit(categoryId: 'a', name: 'A', amountText: '100'),
    ]);
    expect(controller.splitIsExact, isFalse, reason: 'one part is a category');
    controller.dispose();
  });

  test('Save writes once, with the signed amount and no category', () async {
    final gateway = FakePaymentsGateway();
    final controller = await _controller(gateway: gateway);
    _type(controller, '24');
    controller.selectAccount(controller.accounts.first);

    final saved = await controller.save();
    expect(saved, isNotNull);
    expect(gateway.saved, hasLength(1));
    expect(gateway.saved.single.amountMinor, -2400);
    expect(gateway.saved.single.categoryId, isNull);
    expect(gateway.saved.single.date, testToday());
    expect(gateway.payloads.single, isNotEmpty);
    controller.dispose();
  });

  test('a typed value failure writes nothing and keeps the draft', () async {
    final gateway = FakePaymentsGateway()
      ..saveFailure = const PaymentsError(PaymentsErrorCode.notWired);
    final controller = await _controller(gateway: gateway);
    _type(controller, '24');
    controller.selectAccount(controller.accounts.first);

    final saved = await controller.save();
    expect(saved, isNull);
    expect(controller.status, PaymentFormStatus.failed);
    expect(controller.errorCode, PaymentsErrorCode.notWired);
    expect(controller.amountText, '24');
    expect(gateway.saved, isEmpty);
    controller.dispose();
  });

  test('an edit save carries the record identity', () async {
    final gateway = FakePaymentsGateway();
    final controller = await _controller(
      gateway: gateway,
      editing: const PaymentEdit(
        paymentId: 'p-1',
        eventId: 'e-1',
        expectedRevision: 3,
      ),
    );
    _type(controller, '40');
    controller.selectAccount(controller.accounts.first);

    final saved = await controller.save();
    expect(saved!.edit, isTrue);
    expect(saved.paymentId, 'p-1');
    expect(gateway.saved.single.edit!.expectedRevision, 3);
    controller.dispose();
  });

  test('a stored draft resumes its fields and Discard removes it', () async {
    final store = MemoryPaymentDraftStore()
      ..draft = PaymentFormDraft(
        kind: PaymentKind.expense,
        amountText: '18.50',
        currencyCode: 'USD',
        date: LocalDate(2026, 11, 20),
        accountId: 'account-1',
        categoryId: 'category-dining',
        tagIds: <String>['tag-1'],
        merchantText: 'Subway',
        splits: <PaymentDraftSplit>[],
        unsureFields: <DraftField>{},
      );
    final controller = await _controller(drafts: store);

    expect(controller.amountText, '18.50');
    expect(controller.merchantText, 'Subway');
    expect(controller.account?.id, 'account-1');
    expect(controller.category?.id, 'category-dining');
    expect(controller.selectedTagIds, contains('tag-1'));
    expect(controller.date, LocalDate(2026, 11, 20));
    expect(controller.hasDraft, isTrue);

    await controller.discardDraft();
    expect(store.draft, isNull);
    expect(controller.hasDraft, isFalse);
    controller.dispose();
  });

  test('a keystroke does not write the draft; a committed field does',
      () async {
    final store = MemoryPaymentDraftStore();
    final controller = await _controller(drafts: store);
    _type(controller, '24');
    await controller.pendingDraftWrite;
    expect(store.draft, isNull, reason: 'a keypad digit is not a write');

    controller.selectAccount(controller.accounts.first);
    await controller.pendingDraftWrite;
    expect(store.draft, isNotNull);
    expect(store.draft!.amountText, '24');
    expect(store.draft!.accountId, 'account-1');
    controller.dispose();
  });

  test('a kind change clears a category of the other type', () async {
    final controller = await _controller();
    controller.selectCategory(controller.categories.first);
    expect(controller.category, isNotNull);
    controller.setKind(PaymentKind.income);
    await pumpEventQueue();
    expect(controller.category, isNull);
    controller.dispose();
  });
}
