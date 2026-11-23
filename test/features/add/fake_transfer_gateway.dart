import 'package:contour/core/dates.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/add/transfer_models.dart';

/// An in-memory transfer port for the P23 tests. It writes no database.
final class FakeTransferGateway implements TransferGateway {
  FakeTransferGateway({
    List<AccountSummary>? accounts,
    this.currencyCode = 'USD',
  }) : accounts = accounts ??
            <AccountSummary>[
              _checking,
              _card,
            ];

  static const AccountSummary _checking = AccountSummary(
    id: 'account-checking',
    name: 'Checking',
    kind: AccountKind.bank,
    currencyCode: 'USD',
    balanceMinor: 645000,
  );

  static const AccountSummary _card = AccountSummary(
    id: 'account-card',
    name: 'Visa card',
    kind: AccountKind.card,
    currencyCode: 'USD',
    balanceMinor: -124000,
  );

  List<AccountSummary> accounts;
  String currencyCode;

  final List<TransferSetup> saved = <TransferSetup>[];
  final List<String> payloads = <String>[];
  int undoCount = 0;
  Object? loadFailure;
  Object? saveFailure;
  Object? undoFailure;

  @override
  Future<TransferFormData> loadForm() async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return TransferFormData(
      accounts: accounts,
      currencyCode: currencyCode,
    );
  }

  @override
  Future<SavedTransfer> saveTransfer({
    required TransferSetup setup,
    String? draftId,
    String? payloadJson,
  }) async {
    final failure = saveFailure;
    if (failure != null) {
      throw failure;
    }
    saved.add(setup);
    payloads.add(payloadJson ?? '');
    return SavedTransfer(
      eventId: 'event-${saved.length}',
      sendingId: 'sending-${saved.length}',
      receivingId: 'receiving-${saved.length}',
      operationId: 'operation-${saved.length}',
      amountMinor: setup.amountMinor,
      currencyCode: setup.currencyCode,
      date: setup.date,
    );
  }

  @override
  Future<void> undoTransfer(SavedTransfer saved) async {
    final failure = undoFailure;
    if (failure != null) {
      throw failure;
    }
    undoCount += 1;
  }
}

/// The fixed date of the P23 tests.
LocalDate transferTestToday() => LocalDate(2026, 10, 13);
