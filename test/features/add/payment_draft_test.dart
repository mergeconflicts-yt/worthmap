import 'package:contour/core/dates.dart';
import 'package:contour/domain/importers/quick_add_parser.dart' show DraftField;
import 'package:contour/features/add/payment_draft.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentFormDraft _draft() => PaymentFormDraft(
      kind: PaymentKind.expense,
      amountText: '121.30',
      currencyCode: 'USD',
      date: LocalDate(2026, 10, 5),
      accountId: 'account-1',
      categoryId: 'category-1',
      tagIds: const <String>['tag-1'],
      merchantText: 'Whole Foods',
      splits: const <PaymentDraftSplit>[
        PaymentDraftSplit(
          categoryId: 'category-1',
          name: 'Groceries',
          amountText: '84.12',
        ),
        PaymentDraftSplit(
          categoryId: 'category-2',
          name: 'Household',
          amountText: '37.18',
        ),
      ],
      unsureFields: const <DraftField>{DraftField.account},
      edit: const PaymentEdit(
        paymentId: 'payment-1',
        eventId: 'event-1',
        expectedRevision: 4,
      ),
    );

void main() {
  test('the codec round trip keeps every field', () {
    final encoded = PaymentDraftJson.encode(_draft());
    final decoded = PaymentDraftJson.decode(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.kind, PaymentKind.expense);
    expect(decoded.amountText, '121.30');
    expect(decoded.currencyCode, 'USD');
    expect(decoded.date, LocalDate(2026, 10, 5));
    expect(decoded.accountId, 'account-1');
    expect(decoded.categoryId, 'category-1');
    expect(decoded.tagIds, <String>['tag-1']);
    expect(decoded.merchantText, 'Whole Foods');
    expect(decoded.splits, hasLength(2));
    expect(decoded.splits.last.name, 'Household');
    expect(decoded.splits.last.amountText, '37.18');
    expect(decoded.unsureFields, <DraftField>{DraftField.account});
    expect(decoded.edit!.paymentId, 'payment-1');
    expect(decoded.edit!.expectedRevision, 4);
  });

  test('a create draft has no edit identity', () {
    final draft = PaymentFormDraft(
      kind: PaymentKind.income,
      amountText: '5000',
      currencyCode: 'USD',
      date: LocalDate(2026, 11, 22),
      accountId: null,
      categoryId: null,
      tagIds: const <String>[],
      merchantText: '',
      splits: const <PaymentDraftSplit>[],
      unsureFields: const <DraftField>{},
    );
    final decoded = PaymentDraftJson.decode(PaymentDraftJson.encode(draft));
    expect(decoded!.edit, isNull);
    expect(decoded.kind, PaymentKind.income);
  });

  test('another schema version is not read as the current draft', () {
    final encoded = PaymentDraftJson.encode(_draft());
    encoded['schema'] = 2;
    expect(PaymentDraftJson.decode(encoded), isNull);
  });

  test('a malformed payload is unreadable, not a partial draft', () {
    final encoded = PaymentDraftJson.encode(_draft());
    encoded['splits'] = <Object?>[
      <String, Object?>{'category': 1},
    ];
    expect(PaymentDraftJson.decode(encoded), isNull);

    final badDate = PaymentDraftJson.encode(_draft())..['date'] = '2026-13-40';
    expect(PaymentDraftJson.decode(badDate), isNull);

    final badKind = PaymentDraftJson.encode(_draft())..['kind'] = 'transfer';
    expect(PaymentDraftJson.decode(badKind), isNull);
  });

  test('the memory store reports no draft, a draft, then none', () async {
    final store = MemoryPaymentDraftStore(id: 'draft-7');
    expect(await store.load(), isA<NoPaymentDraft>());

    final id = await store.save(_draft());
    expect(id, 'draft-7');
    final loaded = await store.load();
    expect(loaded, isA<LoadedPaymentDraft>());
    expect((loaded as LoadedPaymentDraft).id, 'draft-7');
    expect(loaded.draft.amountText, '121.30');

    await store.discard();
    expect(await store.load(), isA<NoPaymentDraft>());
  });
}
