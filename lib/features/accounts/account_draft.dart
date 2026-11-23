// P21 / SPEC 8.16: the C01 draft contract.
//
// The draft holds the structured form fields only. It never holds an account
// identity, an operation id, a source text or a log line. The codec is pure
// and versioned; an unreadable or older payload is reported as unsupported,
// never silently re-read.
library;

import '../../core/dates.dart';
import 'account_models.dart';

/// One C01 draft payload.
final class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.amountText,
    required this.date,
    required this.countsAsCash,
    required this.includeInNetWorth,
  });

  final String name;
  final AccountKind? kind;
  final String currencyCode;
  final String amountText;
  final LocalDate date;
  final bool countsAsCash;
  final bool includeInNetWorth;
}

/// The result of reading a stored draft.
sealed class AccountDraftLoad {
  const AccountDraftLoad();
}

/// A readable draft of the current schema.
final class LoadedAccountDraft extends AccountDraftLoad {
  const LoadedAccountDraft(this.draft);
  final AccountDraft draft;
}

/// No draft is stored.
final class NoAccountDraft extends AccountDraftLoad {
  const NoAccountDraft();
}

/// A draft exists but its payload is from an older schema or unreadable.
final class UnsupportedAccountDraft extends AccountDraftLoad {
  const UnsupportedAccountDraft();
}

/// The draft store port. The app composition supplies a `DraftRepository`
/// adapter; tests supply a memory store.
abstract interface class AccountDraftStore {
  Future<AccountDraftLoad> load();
  Future<void> save(AccountDraft draft);
  Future<void> discard();
}

/// A store with no backing database. It is not the "unavailable" gateway
/// state: it simply keeps nothing.
final class NoAccountDraftStore implements AccountDraftStore {
  const NoAccountDraftStore();

  @override
  Future<AccountDraftLoad> load() async => const NoAccountDraft();

  @override
  Future<void> save(AccountDraft draft) async {}

  @override
  Future<void> discard() async {}
}

/// A memory store for tests and a preview.
final class MemoryAccountDraftStore implements AccountDraftStore {
  AccountDraft? draft;

  @override
  Future<AccountDraftLoad> load() async =>
      draft == null ? const NoAccountDraft() : LoadedAccountDraft(draft!);

  @override
  Future<void> save(AccountDraft value) async => draft = value;

  @override
  Future<void> discard() async => draft = null;
}

/// JSON keys of the C01 draft. The schema version is the first check.
abstract final class AccountDraftJson {
  const AccountDraftJson._();

  static const int schemaVersion = 1;

  static Map<String, Object?> encode(AccountDraft draft) => <String, Object?>{
        'schema': schemaVersion,
        'name': draft.name,
        'kind': draft.kind?.name,
        'currency': draft.currencyCode,
        'amount': draft.amountText,
        'date': draft.date.toString(),
        'cash': draft.countsAsCash,
        'netWorth': draft.includeInNetWorth,
      };

  /// Returns null for any payload that is not exactly this schema. The caller
  /// turns null into the unsupported state (P01).
  static AccountDraft? decode(Map<String, Object?> json) {
    if (json['schema'] != schemaVersion) {
      return null;
    }
    final name = json['name'];
    final currency = json['currency'];
    final amount = json['amount'];
    final dateText = json['date'];
    final cash = json['cash'];
    final netWorth = json['netWorth'];
    final kindName = json['kind'];
    if (name is! String ||
        currency is! String ||
        amount is! String ||
        dateText is! String ||
        cash is! bool ||
        netWorth is! bool) {
      return null;
    }
    final date = LocalDate.tryParse(dateText);
    if (date == null) {
      return null;
    }
    AccountKind? kind;
    if (kindName != null) {
      kind = null;
      for (final candidate in AccountKind.values) {
        if (candidate.name == kindName) {
          kind = candidate;
        }
      }
      if (kind == null) {
        return null;
      }
    }
    return AccountDraft(
      name: name,
      kind: kind,
      currencyCode: currency,
      amountText: amount,
      date: date,
      countsAsCash: cash,
      includeInNetWorth: netWorth,
    );
  }
}
