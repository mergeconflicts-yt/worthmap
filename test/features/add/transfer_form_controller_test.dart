import 'package:contour/core/dates.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/add/transfer_draft.dart';
import 'package:contour/features/add/transfer_form_controller.dart';
import 'package:contour/features/add/transfer_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transfer_gateway.dart';

Future<TransferFormController> _controller({
  FakeTransferGateway? gateway,
  TransferDraftStore? drafts,
}) async {
  final controller = TransferFormController(
    gateway: gateway ?? FakeTransferGateway(),
    today: transferTestToday(),
    drafts: drafts,
  );
  await controller.initialize();
  return controller;
}

void _type(TransferFormController controller, String digits) {
  for (final key in digits.split('')) {
    controller.pressKey(key);
  }
}

void main() {
  test('the form picks the first two accounts and needs an amount', () async {
    final controller = await _controller();

    expect(controller.from?.name, 'Checking');
    expect(controller.to?.name, 'Visa card');
    expect(controller.canSave, isFalse);

    _type(controller, '1240');
    expect(controller.enteredAmount!.minor, 124000);
    expect(controller.canSave, isTrue);
    controller.dispose();
  });

  test('one account cannot be both sides', () async {
    final controller = await _controller();
    _type(controller, '20');
    controller.selectTo(controller.from!);

    expect(controller.sameAccount, isTrue);
    expect(controller.canSave, isFalse);
    controller.dispose();
  });

  test('two currencies are rejected in this phase', () async {
    final gateway = FakeTransferGateway(
      accounts: const <AccountSummary>[
        AccountSummary(
          id: 'usd',
          name: 'Checking',
          kind: AccountKind.bank,
          currencyCode: 'USD',
          balanceMinor: 100000,
        ),
        AccountSummary(
          id: 'inr',
          name: 'Harbor Bank India',
          kind: AccountKind.bank,
          currencyCode: 'INR',
          balanceMinor: 5000000,
        ),
      ],
    );
    final controller = await _controller(gateway: gateway);
    _type(controller, '100');

    expect(controller.crossCurrency, isTrue);
    expect(controller.canSave, isFalse);
    controller.dispose();
  });

  test('Save sends the positive principal and the chosen date', () async {
    final gateway = FakeTransferGateway();
    final controller = await _controller(gateway: gateway);
    _type(controller, '1240');
    controller.setDate(LocalDate(2026, 10, 9));

    final saved = await controller.save();

    expect(saved, isNotNull, reason: '${controller.errorCode}');
    final setup = gateway.saved.single;
    expect(setup.amountMinor, 124000, reason: 'the principal is positive');
    expect(setup.fromAccountId, 'account-checking');
    expect(setup.toAccountId, 'account-card');
    expect(setup.date, LocalDate(2026, 10, 9));
    expect(setup.currencyCode, 'USD');
    controller.dispose();
  });

  test('a failure keeps every entry and shows a safe code', () async {
    final gateway = FakeTransferGateway()
      ..saveFailure = const TransferFormError(TransferErrorCode.saveFailed);
    final controller = await _controller(gateway: gateway);
    _type(controller, '50');

    final saved = await controller.save();

    expect(saved, isNull);
    expect(controller.status, TransferFormStatus.failed);
    expect(controller.errorCode, TransferErrorCode.saveFailed);
    expect(controller.amountText, '50');
    expect(controller.from, isNotNull);
    expect(controller.canSave, isTrue, reason: 'the retry is offered');
    controller.dispose();
  });

  test('a draft restores the amount and the two accounts', () async {
    final store = MemoryTransferDraftStore(
      draft: TransferFormDraft(
        amountText: '18.50',
        currencyCode: 'USD',
        date: LocalDate(2026, 10, 2),
        fromAccountId: 'account-card',
        toAccountId: 'account-checking',
      ),
    );
    final controller = await _controller(drafts: store);

    expect(controller.amountText, '18.50');
    expect(controller.date, LocalDate(2026, 10, 2));
    expect(controller.from?.id, 'account-card');
    expect(controller.to?.id, 'account-checking');
    expect(controller.hasDraft, isTrue);
    controller.dispose();
  });

  test('an unsupported draft keeps the form and offers Discard', () async {
    final store = _UnsupportedStore();
    final controller = await _controller(drafts: store);

    expect(controller.hasDraft, isTrue);
    expect(controller.draftUnsupported, isTrue);
    expect(controller.amountText, isEmpty);

    await controller.discardDraft();
    expect(store.discarded, isTrue);
    expect(controller.hasDraft, isFalse);
    controller.dispose();
  });

  test('Undo is one compensating call', () async {
    final gateway = FakeTransferGateway();
    final controller = await _controller(gateway: gateway);
    _type(controller, '10');
    final saved = await controller.save();

    await controller.undo(saved!);

    expect(gateway.undoCount, 1);
    controller.dispose();
  });
}

final class _UnsupportedStore implements TransferDraftStore {
  bool discarded = false;

  @override
  Future<TransferDraftLoad> load() async => const UnsupportedTransferDraft();

  @override
  Future<String> save(TransferFormDraft draft) async => 'draft';

  @override
  Future<void> discard() async => discarded = true;
}
