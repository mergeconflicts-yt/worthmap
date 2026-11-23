// P23 / SPEC 8.16: the X26 draft adapter over the P13 draft store.
//
// The payload is the transfer draft codec JSON. A payload of another schema
// version is reported as unsupported and kept until an explicit Discard (P01).
library;

import 'dart:convert';

import '../data/repositories/drafts.dart';
import '../features/add/transfer_draft.dart';

/// One stored transfer draft, addressed by its P13 record id.
final class SqlTransferDraftStore implements TransferDraftStore {
  SqlTransferDraftStore({
    required this.drafts,
    required this.newId,
  });

  static const String formType = 'transfer';

  final DraftRepository drafts;
  final String Function() newId;

  String? _id;

  /// The current draft identity, for a caller that resolves a lost reply.
  String? get draftId => _id;

  @override
  Future<TransferDraftLoad> load() async {
    final record = await drafts.find(formType: formType);
    if (record == null) {
      return const NoTransferDraft();
    }
    _id = record.id;
    if (record.schemaVersion != TransferDraftJson.schemaVersion) {
      return const UnsupportedTransferDraft();
    }
    final payload = record.payloadJson;
    if (payload == null) {
      return const UnsupportedTransferDraft();
    }
    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, Object?>) {
        return const UnsupportedTransferDraft();
      }
      final draft = TransferDraftJson.decode(json);
      return draft == null
          ? const UnsupportedTransferDraft()
          : LoadedTransferDraft(id: record.id, draft: draft);
    } on FormatException {
      return const UnsupportedTransferDraft();
    }
  }

  @override
  Future<String> save(TransferFormDraft draft) async {
    final id = _id ?? newId();
    _id = id;
    await drafts.save(
      id: id,
      formType: formType,
      schemaVersion: TransferDraftJson.schemaVersion,
      payloadJson: jsonEncode(TransferDraftJson.encode(draft)),
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
