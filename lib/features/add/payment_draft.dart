// P22 / SPEC 8.16: the X20 payment draft contract.
//
// The draft holds the structured form fields only: type, amount, currency,
// date, account, category, tags, merchant text, split parts and the "please
// check" markers of a sentence fill. It never holds an amount in a log, an
// operation id, a transcript, a category colour or a raw source row. The codec
// is pure and versioned; an unreadable or older payload is reported as
// unsupported, never silently re-read.
library;

import '../../core/dates.dart';
import '../../domain/importers/quick_add_parser.dart';
import 'payment_models.dart';

/// One split part in the draft. The name keeps the chosen category visible
/// when its row is gone (F03 recovery).
final class PaymentDraftSplit {
  const PaymentDraftSplit({
    required this.categoryId,
    required this.name,
    required this.amountText,
  });

  final String categoryId;
  final String name;
  final String amountText;
}

/// One X20 draft payload (SPEC 8.16 field table).
final class PaymentFormDraft {
  const PaymentFormDraft({
    required this.kind,
    required this.amountText,
    required this.currencyCode,
    required this.date,
    required this.accountId,
    required this.categoryId,
    required this.tagIds,
    required this.merchantText,
    required this.splits,
    required this.unsureFields,
    this.edit,
  });

  final PaymentKind kind;
  final String amountText;
  final String currencyCode;
  final LocalDate date;
  final String? accountId;
  final String? categoryId;
  final List<String> tagIds;
  final String merchantText;
  final List<PaymentDraftSplit> splits;

  /// SPEC 8.10: the fields a sentence filled but the person must check.
  final Set<DraftField> unsureFields;

  /// F03 step 1: the record this draft edits, when the form is an edit.
  final PaymentEdit? edit;
}

/// The result of reading a stored draft.
sealed class PaymentDraftLoad {
  const PaymentDraftLoad();
}

/// A readable draft of the current schema.
final class LoadedPaymentDraft extends PaymentDraftLoad {
  const LoadedPaymentDraft({required this.id, required this.draft});

  final String id;
  final PaymentFormDraft draft;
}

/// No draft is stored.
final class NoPaymentDraft extends PaymentDraftLoad {
  const NoPaymentDraft();
}

/// A draft exists but its payload is from an older schema or unreadable.
final class UnsupportedPaymentDraft extends PaymentDraftLoad {
  const UnsupportedPaymentDraft();
}

/// The draft store port. The app composition supplies a `DraftRepository`
/// adapter; tests supply a memory store.
abstract interface class PaymentDraftStore {
  Future<PaymentDraftLoad> load();

  /// Writes the draft and returns its identity (P13 draft id).
  Future<String> save(PaymentFormDraft draft);

  Future<void> discard();
}

/// A store with no backing database. It keeps nothing and reports no draft.
final class NoPaymentDraftStore implements PaymentDraftStore {
  const NoPaymentDraftStore();

  @override
  Future<PaymentDraftLoad> load() async => const NoPaymentDraft();

  @override
  Future<String> save(PaymentFormDraft draft) async => '';

  @override
  Future<void> discard() async {}
}

/// A memory store for tests and a preview.
final class MemoryPaymentDraftStore implements PaymentDraftStore {
  MemoryPaymentDraftStore({this.id = 'draft-memory'});

  String id;
  PaymentFormDraft? draft;

  @override
  Future<PaymentDraftLoad> load() async => draft == null
      ? const NoPaymentDraft()
      : LoadedPaymentDraft(id: id, draft: draft!);

  @override
  Future<String> save(PaymentFormDraft value) async {
    draft = value;
    return id;
  }

  @override
  Future<void> discard() async => draft = null;
}

/// JSON keys of the X20 draft. The schema version is the first check.
abstract final class PaymentDraftJson {
  const PaymentDraftJson._();

  static const int schemaVersion = 1;

  static Map<String, Object?> encode(PaymentFormDraft draft) =>
      <String, Object?>{
        'schema': schemaVersion,
        'kind': draft.kind.name,
        'amount': draft.amountText,
        'currency': draft.currencyCode,
        'date': draft.date.toString(),
        'account': draft.accountId,
        'category': draft.categoryId,
        'tags': draft.tagIds,
        'merchant': draft.merchantText,
        'splits': <Map<String, Object?>>[
          for (final split in draft.splits)
            <String, Object?>{
              'category': split.categoryId,
              'name': split.name,
              'amount': split.amountText,
            },
        ],
        'unsure': <String>[
          for (final field in draft.unsureFields) field.name,
        ],
        'edit': draft.edit == null
            ? null
            : <String, Object?>{
                'payment': draft.edit!.paymentId,
                'event': draft.edit!.eventId,
                'revision': draft.edit!.expectedRevision,
              },
      };

  /// Returns null for any payload that is not exactly this schema. The caller
  /// turns null into the unsupported state (P01).
  static PaymentFormDraft? decode(Map<String, Object?> json) {
    if (json['schema'] != schemaVersion) {
      return null;
    }
    final kindName = json['kind'];
    final amount = json['amount'];
    final currency = json['currency'];
    final dateText = json['date'];
    final account = json['account'];
    final category = json['category'];
    final tags = json['tags'];
    final merchant = json['merchant'];
    final splitRows = json['splits'];
    final unsure = json['unsure'];
    if (amount is! String ||
        currency is! String ||
        dateText is! String ||
        merchant is! String ||
        tags is! List ||
        splitRows is! List ||
        unsure is! List) {
      return null;
    }
    if (account != null && account is! String) {
      return null;
    }
    if (category != null && category is! String) {
      return null;
    }
    final date = LocalDate.tryParse(dateText);
    if (date == null) {
      return null;
    }
    final kind = _kindOf(kindName);
    if (kind == null) {
      return null;
    }
    final tagIds = <String>[];
    for (final tag in tags) {
      if (tag is! String) {
        return null;
      }
      tagIds.add(tag);
    }
    final splits = <PaymentDraftSplit>[];
    for (final row in splitRows) {
      if (row is! Map) {
        return null;
      }
      final splitCategory = row['category'];
      final name = row['name'];
      final splitAmount = row['amount'];
      if (splitCategory is! String ||
          name is! String ||
          splitAmount is! String) {
        return null;
      }
      splits.add(
        PaymentDraftSplit(
          categoryId: splitCategory,
          name: name,
          amountText: splitAmount,
        ),
      );
    }
    final unsureFields = <DraftField>{};
    for (final field in unsure) {
      if (field is! String) {
        return null;
      }
      final match = _fieldOf(field);
      if (match == null) {
        return null;
      }
      unsureFields.add(match);
    }
    final editRow = json['edit'];
    PaymentEdit? edit;
    if (editRow != null) {
      if (editRow is! Map) {
        return null;
      }
      final paymentId = editRow['payment'];
      final eventId = editRow['event'];
      final revision = editRow['revision'];
      if (paymentId is! String || eventId is! String || revision is! int) {
        return null;
      }
      edit = PaymentEdit(
        paymentId: paymentId,
        eventId: eventId,
        expectedRevision: revision,
      );
    }
    return PaymentFormDraft(
      kind: kind,
      amountText: amount,
      currencyCode: currency,
      date: date,
      accountId: account as String?,
      categoryId: category as String?,
      tagIds: tagIds,
      merchantText: merchant,
      splits: splits,
      unsureFields: unsureFields,
      edit: edit,
    );
  }

  static PaymentKind? _kindOf(Object? name) {
    for (final kind in PaymentKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return null;
  }

  static DraftField? _fieldOf(String name) {
    for (final field in DraftField.values) {
      if (field.name == name) {
        return field;
      }
    }
    return null;
  }
}
