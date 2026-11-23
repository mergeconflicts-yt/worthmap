// P3-25 test doubles: a synthetic file, a local gateway and one account.
import 'dart:typed_data';

import 'package:contour/domain/importers/pdf/pdf_template.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/import/import_models.dart';

final class FakeImportGateway implements ImportGateway {
  FakeImportGateway({
    this.rows = 4,
    this.layoutsList = const <SavedLayout>[],
    this.historyList = const <ImportBatchView>[],
    this.failSend = false,
  });

  final int rows;
  List<SavedLayout> layoutsList;
  final List<ImportBatchView> historyList;
  final bool failSend;
  int undoCount = 0;
  int sendCount = 0;
  String? lastAccount;
  bool lastAllowReimport = false;

  @override
  Future<List<SavedLayout>> layouts() async => layoutsList;

  @override
  Future<SavedLayout> saveLayout(PdfTemplate template) async {
    final saved = SavedLayout(
      fingerprint: template.fingerprint,
      name: template.name,
      usedCount: 0,
      bands: template.bands,
    );
    layoutsList = <SavedLayout>[...layoutsList, saved];
    return saved;
  }

  @override
  Future<List<ImportBatchView>> history() async => historyList;

  @override
  Future<ImportSendResult> send({
    required String label,
    required List<int> fileDigest,
    required String accountId,
    required List<ImportDraftRow> rows,
    required String fingerprint,
    required bool allowReimport,
  }) async {
    sendCount++;
    lastAccount = accountId;
    lastAllowReimport = allowReimport;
    if (failSend) {
      throw const ImportIntakeError(ImportFailure.sendFailed);
    }
    return ImportSendResult(
      batchId: 'batch-1',
      staged: rows.length,
      existing: 0,
    );
  }

  @override
  Future<int> undo(String batchId) async {
    undoCount++;
    return rows;
  }
}

final class FakeIntake implements ImportFileIntake {
  FakeIntake(this.bytes, {this.name = 'First Bank statement, October.pdf'});

  final Uint8List bytes;
  final String name;

  @override
  Future<ImportedFile?> pickPdf() async =>
      ImportedFile(name: name, bytes: bytes);
}

final class FakeAccountsGateway implements AccountsGateway {
  FakeAccountsGateway({this.accounts = const <AccountSummary>[]});

  final List<AccountSummary> accounts;

  @override
  Future<List<AccountSummary>> listAccounts() async => accounts;

  @override
  Future<AccountSummary> createAccount(AccountSetup setup) async =>
      throw const AccountsError(AccountsErrorCode.notWired);
}

const AccountSummary checkingAccount = AccountSummary(
  id: '00000000-0000-7000-8000-0000000000a1',
  name: 'Checking',
  kind: AccountKind.bank,
  currencyCode: 'USD',
  balanceMinor: 645000,
);
