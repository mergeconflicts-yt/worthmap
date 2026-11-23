import 'package:contour/features/spending/spending_controller.dart';
import 'package:contour/features/spending/spending_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_spending_gateway.dart';

void main() {
  test('the month period reads the Appendix A values', () async {
    final controller = SpendingController(gateway: FakeSpendingGateway());
    await controller.load();

    final view = controller.view!;
    expect(view.moneyOutMinor, 394000);
    expect(view.limitMinor, 520000);
    expect(view.leftMinor, 126000);
    expect(view.sameDaysPreviousMinor, 400500);
    expect(view.monthDay, 13);
    expect(view.monthDays, 31);
    expect(
      view.categories.fold<int>(0, (sum, row) => sum + row.amountMinor),
      394000,
      reason: 'the category rows sum to the period spending',
    );
    expect(controller.limitFor('rent'), 180000);
    controller.dispose();
  });

  test('category shares add to exactly 100', () async {
    final controller = SpendingController(gateway: FakeSpendingGateway());
    await controller.load();

    final shares = controller.view!.categoryShares;
    final total = shares.fold<double>(0, (sum, p) => sum + p.value.toDouble());
    expect(total, closeTo(100, 0.0001));
    controller.dispose();
  });

  test('a chip selects another period with its own limit', () async {
    final controller = SpendingController(gateway: FakeSpendingGateway());
    await controller.load();

    await controller.selectPeriod(SpendingPeriod.sixMonths);

    expect(controller.period, SpendingPeriod.sixMonths);
    expect(controller.view!.moneyOutMinor, 2108000);
    expect(controller.view!.limitMinor, 2600000);
    controller.dispose();
  });

  test('a failed read is a safe failed state', () async {
    final gateway = FakeSpendingGateway()..loadFailure = StateError('closed');
    final controller = SpendingController(gateway: gateway);
    await controller.load();

    expect(controller.state, SpendingLoadState.failed);
    expect(controller.errorCode, SpendingErrorCode.loadFailed);
    controller.dispose();
  });

  test('the limits draft totals the positive limits', () async {
    final controller = LimitsController(gateway: FakeSpendingGateway());
    await controller.load();

    expect(controller.totalMinor, 520000);
    expect(controller.categoryCount, 8);
    expect(controller.limitFor('rent'), 180000);

    controller.setLimit('rent', 190000);
    expect(controller.totalMinor, 530000);
    expect(controller.categoryCount, 8);
    expect(controller.limitFor('rent'), 190000);
    controller.dispose();
  });

  test('SaveLimits sends the exact map once', () async {
    final gateway = FakeSpendingGateway();
    final controller = LimitsController(gateway: gateway);
    await controller.load();
    controller.setLimit('rent', 190000);
    controller.setLimit('other', 0);

    final saved = await controller.save();

    expect(saved, isTrue);
    expect(gateway.saveCalls, 1);
    expect(gateway.savedLimits!['rent'], 190000);
    expect(gateway.savedLimits!['other'], 0);
    expect(gateway.savedLimits, hasLength(8));
    controller.dispose();
  });

  test('a failed SaveLimits keeps the draft', () async {
    final gateway = FakeSpendingGateway()
      ..saveFailure = const SpendingError(SpendingErrorCode.saveFailed);
    final controller = LimitsController(gateway: gateway);
    await controller.load();
    controller.setLimit('rent', 190000);

    final saved = await controller.save();

    expect(saved, isFalse);
    expect(controller.errorCode, SpendingErrorCode.saveFailed);
    expect(controller.limitFor('rent'), 190000);
    controller.dispose();
  });
}
