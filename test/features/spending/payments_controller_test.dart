import 'package:contour/features/spending/payments_controller.dart';
import 'package:contour/features/spending/payments_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_payments_read_gateway.dart';

void main() {
  test('the list loads the default filter', () async {
    final controller =
        PaymentsListController(gateway: FakePaymentsReadGateway());
    await controller.load();

    expect(controller.state, PaymentsViewState.ready);
    expect(controller.page!.items, hasLength(4));
    expect(controller.page!.count, 4);
    expect(controller.filter.period, PaymentPeriod.thisMonth);
    controller.dispose();
  });

  test('a returned filter is the only one applied (F08-A)', () async {
    final controller =
        PaymentsListController(gateway: FakePaymentsReadGateway());
    await controller.load();

    await controller.apply(
      const PaymentFilter(
        period: PaymentPeriod.thisMonth,
        show: PaymentShowFilter.moneyOut,
        categoryId: 'cat-coffee',
      ),
    );

    expect(controller.page!.items, hasLength(1));
    expect(controller.page!.items.single.merchantName, 'Starbucks');
    expect(controller.filter.categoryId, 'cat-coffee');
    controller.dispose();
  });

  test('the detail loads one payment with its splits and tags', () async {
    final controller = PaymentDetailController(
      gateway: FakePaymentsReadGateway(),
      paymentId: 'p3',
    );
    await controller.load();

    expect(controller.view, isNotNull);
    expect(controller.view!.splits, hasLength(3));
    expect(controller.view!.tags, <String>['Household']);
    expect(controller.view!.note, 'Weekly shop');
    controller.dispose();
  });

  test('delete returns the committed result and restore compensates it',
      () async {
    final gateway = FakePaymentsReadGateway();
    final controller = PaymentDetailController(
      gateway: gateway,
      paymentId: 'p1',
    );
    await controller.load();

    final deleted = await controller.delete();

    expect(deleted, isNotNull);
    expect(gateway.deleted, <String>['p1']);
    expect(gateway.items.any((item) => item.id == 'p1'), isFalse);

    await controller.restore(deleted!);
    expect(gateway.restored, <String>['p1']);
    controller.dispose();
  });

  test('a failed delete keeps the payment and reports a safe code', () async {
    final gateway = FakePaymentsReadGateway()
      ..deleteFailure = StateError('closed');
    final controller = PaymentDetailController(
      gateway: gateway,
      paymentId: 'p1',
    );
    await controller.load();

    final deleted = await controller.delete();

    expect(deleted, isNull);
    expect(controller.errorCode, PaymentsReadErrorCode.deleteFailed);
    expect(gateway.items, hasLength(4));
    controller.dispose();
  });

  test('the category detail loads its numbers', () async {
    final controller = CategoryDetailController(
      gateway: FakePaymentsReadGateway(),
      categoryId: 'cat-groceries',
    );
    await controller.load();

    expect(controller.view!.name, 'Groceries');
    expect(controller.view!.spentMinor, 62000);
    expect(controller.view!.limitMinor, 120000);
    expect(controller.view!.averageMinor, 70000);
    expect(controller.view!.months, hasLength(10));
    expect(controller.view!.merchants, hasLength(3));
    controller.dispose();
  });
}
