import 'package:contour/features/inbox/inbox_controller.dart';
import 'package:contour/features/inbox/inbox_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_inbox_gateway.dart';

void main() {
  test('load ticks ready rows only; unsure and decision rows stay unticked',
      () async {
    final controller = InboxController(gateway: FakeInboxGateway());
    await controller.load();

    expect(controller.rows, hasLength(4));
    expect(controller.pendingCount, 4);
    expect(controller.ticked, <int>{1, 4});
    expect(
      controller.ticked.contains(2),
      isFalse,
      reason: 'the unsure row is not ticked (F07-A)',
    );
    expect(controller.decision, isNotNull);
    expect(controller.tickedCount, 2);
    controller.dispose();
  });

  test('a decision owns the action and Confirm waits for it', () async {
    final gateway = FakeInboxGateway();
    final controller = InboxController(gateway: gateway);
    await controller.load();

    expect(controller.decisionOpen, isTrue);
    expect(controller.canConfirm, isFalse);

    await controller.decide(true);

    expect(gateway.decisions, <bool>[true]);
    expect(controller.decisionOpen, isFalse);
    expect(controller.ticked.contains(3), isTrue);
    expect(controller.canConfirm, isTrue);
    controller.dispose();
  });

  test('a rejected decision is not ticked and is not confirmed', () async {
    final gateway = FakeInboxGateway();
    final controller = InboxController(gateway: gateway);
    await controller.load();

    await controller.decide(false);
    final confirmation = await controller.confirm();

    expect(confirmation, isNotNull);
    expect(gateway.confirmed.single.contains(3), isFalse);
    expect(gateway.confirmed.single, <int>{1, 4});
    controller.dispose();
  });

  test('the confirm label reads the exact count and total (F07-B)', () async {
    final gateway = FakeInboxGateway();
    final controller = InboxController(gateway: gateway);
    await controller.load();

    expect(controller.totals!.count, 2);
    expect(controller.totals!.netMinor, -640 - 4218);

    await controller.toggle(4);
    expect(controller.totals!.count, 1);
    expect(controller.totals!.netMinor, -640);
    controller.dispose();
  });

  test('an unsure row cannot be ticked', () async {
    final controller = InboxController(gateway: FakeInboxGateway());
    await controller.load();

    await controller.toggle(2);

    expect(controller.ticked.contains(2), isFalse);
    controller.dispose();
  });

  test('confirm sends the ticked ids once and reloads', () async {
    final gateway = FakeInboxGateway();
    final controller = InboxController(gateway: gateway);
    await controller.load();
    await controller.decide(true);

    final confirmation = await controller.confirm();

    expect(confirmation!.count, 3);
    expect(gateway.confirmed.single, <int>{1, 3, 4});
    expect(controller.ticked, isEmpty);
    expect(controller.rows, hasLength(1), reason: 'only the unsure row stays');
    controller.dispose();
  });

  test('an over-limit batch keeps every row and reports a safe code', () async {
    final gateway = FakeInboxGateway()
      ..confirmFailure = const InboxViewError(InboxViewErrorCode.overLimit);
    final controller = InboxController(gateway: gateway);
    await controller.load();
    await controller.decide(true);

    final confirmation = await controller.confirm();

    expect(confirmation, isNull);
    expect(controller.errorCode, InboxViewErrorCode.overLimit);
    expect(controller.rows, hasLength(4));
    expect(controller.ticked, isNotEmpty);
    controller.dispose();
  });

  test('Delete removes the staged item and its tick', () async {
    final gateway = FakeInboxGateway();
    final controller = InboxController(gateway: gateway);
    await controller.load();
    final row = controller.rows.firstWhere((item) => item.id == 1);

    await controller.deleteRow(row);

    expect(gateway.deleted, <int>[1]);
    expect(controller.rows.any((item) => item.id == 1), isFalse);
    expect(controller.ticked.contains(1), isFalse);
    controller.dispose();
  });

  test('Undo compensates the whole batch', () async {
    final gateway = FakeInboxGateway();
    final controller = InboxController(gateway: gateway);
    await controller.load();
    await controller.decide(true);
    final confirmation = await controller.confirm();

    await controller.undo(confirmation!);

    expect(gateway.undoCount, 1);
    controller.dispose();
  });
}
