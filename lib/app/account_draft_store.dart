// P21 / SPEC 8.16: the C01 draft adapter over the P13 draft store.
//
// The payload is the C01 codec JSON. A payload of another schema version is
// reported as unsupported and kept until an explicit Discard (P01).
library;

import 'dart:convert';

import '../data/repositories/drafts.dart';
import '../features/accounts/account_draft.dart';

/// One stored C01 draft, addressed by its P13 record id.
final class SqlAccountDraftStore implements AccountDraftStore {
  SqlAccountDraftStore({
    required this.drafts,
    required this.newId,
  });

  static const String formType = 'account';

  final DraftRepository drafts;
  final String Function() newId;

  String? _id;

  @override
  Future<AccountDraftLoad> load() async {
    final record = await drafts.find(formType: formType);
    if (record == null) {
      return const NoAccountDraft();
    }
    _id = record.id;
    if (record.schemaVersion != AccountDraftJson.schemaVersion) {
      return const UnsupportedAccountDraft();
    }
    final payload = record.payloadJson;
    if (payload == null) {
      return const UnsupportedAccountDraft();
    }
    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, Object?>) {
        return const UnsupportedAccountDraft();
      }
      final draft = AccountDraftJson.decode(json);
      return draft == null
          ? const UnsupportedAccountDraft()
          : LoadedAccountDraft(draft);
    } on FormatException {
      return const UnsupportedAccountDraft();
    }
  }

  @override
  Future<void> save(AccountDraft draft) async {
    final id = _id ?? newId();
    _id = id;
    await drafts.save(
      id: id,
      formType: formType,
      schemaVersion: AccountDraftJson.schemaVersion,
      payloadJson: jsonEncode(AccountDraftJson.encode(draft)),
    );
  }

  @override
  Future<void> discard() async {
    final id = _id;
    _id = null;
    if (id != null) {
      await drafts.discard(id);
    }
  }
}
