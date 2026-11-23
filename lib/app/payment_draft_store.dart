// P22 / SPEC 8.16: the X20 draft adapter over the P13 draft store.
//
// The payload is the payment draft codec JSON. A payload of another schema
// version is reported as unsupported and kept until an explicit Discard (P01).
library;

import 'dart:convert';

import '../data/repositories/drafts.dart';
import '../features/add/payment_draft.dart';

/// One stored payment draft, addressed by its P13 record id.
final class SqlPaymentDraftStore implements PaymentDraftStore {
  SqlPaymentDraftStore({
    required this.drafts,
    required this.newId,
  });

  static const String formType = 'payment';

  final DraftRepository drafts;
  final String Function() newId;

  String? _id;

  /// The current draft identity, for a caller that resolves a lost reply.
  String? get draftId => _id;

  @override
  Future<PaymentDraftLoad> load() async {
    final record = await drafts.find(formType: formType);
    if (record == null) {
      return const NoPaymentDraft();
    }
    _id = record.id;
    if (record.schemaVersion != PaymentDraftJson.schemaVersion) {
      return const UnsupportedPaymentDraft();
    }
    final payload = record.payloadJson;
    if (payload == null) {
      return const UnsupportedPaymentDraft();
    }
    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, Object?>) {
        return const UnsupportedPaymentDraft();
      }
      final draft = PaymentDraftJson.decode(json);
      return draft == null
          ? const UnsupportedPaymentDraft()
          : LoadedPaymentDraft(id: record.id, draft: draft);
    } on FormatException {
      return const UnsupportedPaymentDraft();
    }
  }

  @override
  Future<String> save(PaymentFormDraft draft) async {
    final id = _id ?? newId();
    _id = id;
    await drafts.save(
      id: id,
      formType: formType,
      schemaVersion: PaymentDraftJson.schemaVersion,
      payloadJson: jsonEncode(PaymentDraftJson.encode(draft)),
    );
    return id;
  }

  @override
  Future<void> discard() async {
    final id = _id;
    _id = null;
    if (id != null) {
      try {
        await drafts.discard(id);
      } on DraftError {
        // A committed draft is history; nothing to discard.
      }
    }
  }
}
