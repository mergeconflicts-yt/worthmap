// P23 (SPEC 4.2, 4.10, 6.3, 8.16; flow F05 steps 1–2): the X26 controller.
//
// The controller holds the draft, validates it and calls the one gateway. It
// writes nothing before Save. A failed Save keeps every entry. Money uses
// Decimal and Money; no `double` and no formatting (AGENTS 2.3, 6.4).
//
// A transfer between two owned accounts needs two different accounts in one
// currency (SPEC 6.3). Cross-currency is X26b and stays v1.1.
library;

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../accounts/account_models.dart';
import 'transfer_draft.dart';
import 'transfer_models.dart';

/// The lifecycle of one X26 Save.
enum TransferFormStatus { loading, editing, saving, saved, failed }

/// The draft and its save state. The widget listens and calls the setters.
final class TransferFormController extends ChangeNotifier {
  TransferFormController({
    required this.gateway,
    required this.today,
    this.drafts,
    String currencyCode = 'USD',
  })  : _currencyCode = currencyCode,
        _date = today;

  final TransferGateway gateway;

  /// The local date used for the default transfer date.
  final LocalDate today;

  /// The draft store. Null keeps the form in memory only.
  final TransferDraftStore? drafts;

  String _amountText = '';
  String _currencyCode;
  LocalDate _date;
  AccountSummary? _from;
  AccountSummary? _to;

  List<AccountSummary> _accounts = const <AccountSummary>[];

  TransferFormStatus _status = TransferFormStatus.loading;
  TransferErrorCode? _errorCode;
  String? _draftId;
  bool _hasDraft = false;
  bool _unsupportedDraft = false;
  bool _userEdited = false;
  bool _loaded = false;
  Future<void> _persistChain = Future<void>.value();

  String get amountText => _amountText;
  String get currencyCode => _currencyCode;
  LocalDate get date => _date;
  AccountSummary? get from => _from;
  AccountSummary? get to => _to;
  List<AccountSummary> get accounts => _accounts;
  TransferFormStatus get status => _status;
  TransferErrorCode? get errorCode => _errorCode;

  /// A draft exists for this form (the Discard action is offered).
  bool get hasDraft => _hasDraft;

  /// The stored draft is from another schema or unreadable. It is kept until
  /// an explicit Discard (P01) and no new draft is written over it.
  bool get draftUnsupported => _unsupportedDraft;

  /// True once the form data is loaded.
  bool get loaded => _loaded;

  /// Tests await this to see the last queued draft write.
  Future<void> get pendingDraftWrite => _persistChain;

  Currency get currency => Currency.of(_currencyCode);

  /// The entered magnitude, or null while the field is empty.
  Money? get enteredAmount => _parseAmount(_amountText);

  /// True when both accounts are chosen and they are the same account.
  bool get sameAccount => _from != null && _from!.id == _to?.id;

  /// True when the two accounts use different currencies (v1.1).
  bool get crossCurrency =>
      _from != null && _to != null && _from!.currencyCode != _to!.currencyCode;

  /// SPEC 3.1 / F05 step 1: an amount, a sending account and a receiving
  /// account that differs from it. Same-currency transfers only in Phase 2.
  bool get canSave =>
      _status != TransferFormStatus.saving &&
      _status != TransferFormStatus.saved &&
      _status != TransferFormStatus.loading &&
      enteredAmount != null &&
      enteredAmount!.minor > 0 &&
      _from != null &&
      _to != null &&
      !sameAccount &&
      !crossCurrency;

  /// Reads the accounts, then one stored draft.
  Future<void> initialize() async {
    try {
      final data = await gateway.loadForm();
      _accounts = data.accounts;
      if (!_userEdited && _currencyCode == 'USD') {
        _currencyCode = data.currencyCode;
      }
    } on Object {
      _accounts = const <AccountSummary>[];
    }
    _status = TransferFormStatus.editing;
    _loaded = true;
    notifyListeners();
    await loadDraft();
    _pickDefaultAccounts();
  }

  /// The form starts with the first two accounts when they exist.
  void _pickDefaultAccounts() {
    if (_userEdited || _from != null || _accounts.length < 2) {
      return;
    }
    final first = _accounts.first;
    final second = _accounts.firstWhere(
      (account) => account.id != first.id,
    );
    _from = first;
    _to = second;
    _currencyCode = first.currencyCode;
    notifyListeners();
  }

  /// SPEC 8.16: reads the stored draft once. A user edit made before the read
  /// completes wins; the draft never overwrites newer input.
  Future<void> loadDraft() async {
    final store = drafts;
    if (store == null) {
      return;
    }
    final loaded = await store.load();
    switch (loaded) {
      case LoadedTransferDraft(:final id, :final draft):
        _draftId = id;
        if (!_userEdited) {
          _amountText = draft.amountText;
          _currencyCode = draft.currencyCode;
          _date = draft.date;
          _from = _accountById(draft.fromAccountId);
          _to = _accountById(draft.toAccountId);
        }
        _hasDraft = true;
      case UnsupportedTransferDraft():
        _hasDraft = true;
        _unsupportedDraft = true;
      case NoTransferDraft():
        _hasDraft = false;
    }
    notifyListeners();
  }

  /// Deletes the stored draft and clears the flag. The form fields stay.
  Future<void> discardDraft() async {
    final store = drafts;
    await _persistChain;
    _hasDraft = false;
    _unsupportedDraft = false;
    _draftId = null;
    if (store != null) {
      try {
        await store.discard();
      } on Object {
        // A committed or missing draft has nothing to discard.
      }
    }
    notifyListeners();
  }

  void setDate(LocalDate value) => _update(() => _date = value);

  /// The sending account. It decides the transfer currency.
  void selectFrom(AccountSummary value) => _update(() {
        _from = value;
        _currencyCode = value.currencyCode;
      });

  void selectTo(AccountSummary value) => _update(() => _to = value);

  /// One keypad press: a digit or the decimal point.
  void pressKey(String key) => _update(
        () {
          if (key == '.') {
            if (_amountText.contains('.') || currency.minorUnits == 0) {
              return;
            }
            _amountText = _amountText.isEmpty ? '0.' : '$_amountText.';
            return;
          }
          if (!RegExp(r'^\d$').hasMatch(key)) {
            return;
          }
          if (_amountText.contains('.') &&
              _digitsAfterPoint >= currency.minorUnits) {
            return;
          }
          if (!_amountText.contains('.') && _integerDigits >= 12) {
            return;
          }
          _amountText = _amountText == '0' ? key : '$_amountText$key';
        },
        persist: false,
      );

  void deleteKey() => _update(
        () {
          if (_amountText.isNotEmpty) {
            _amountText = _amountText.substring(0, _amountText.length - 1);
          }
        },
        persist: false,
      );

  /// SPEC 8.16: amount entry ends when a sheet opens or Save runs.
  void commitAmount() {
    if (_hasDraft || _amountText.isNotEmpty) {
      _schedulePersist();
    }
  }

  int get _digitsAfterPoint {
    final point = _amountText.indexOf('.');
    return point < 0 ? 0 : _amountText.length - point - 1;
  }

  int get _integerDigits {
    final point = _amountText.indexOf('.');
    final whole = point < 0 ? _amountText : _amountText.substring(0, point);
    return whole.replaceFirst('-', '').length;
  }

  Money? _parseAmount(String text) {
    if (text.isEmpty || text == '.') {
      return null;
    }
    try {
      return Money.fromDecimal(Decimal.parse(text), currency);
    } on Object {
      return null;
    }
  }

  /// F05 step 2: one Save.
  ///
  /// Returns the confirmed transfer, or null on a failure. A failure keeps the
  /// draft and sets [errorCode]; nothing is written on a validation failure.
  Future<SavedTransfer?> save() async {
    if (_status == TransferFormStatus.saving ||
        _status == TransferFormStatus.saved) {
      return null;
    }
    if (!canSave) {
      _errorCode = TransferErrorCode.invalidTransfer;
      _status = TransferFormStatus.failed;
      notifyListeners();
      return null;
    }
    final setup = TransferSetup(
      fromAccountId: _from!.id,
      toAccountId: _to!.id,
      amountMinor: enteredAmount!.minor,
      currencyCode: _currencyCode,
      date: _date,
    );
    _status = TransferFormStatus.saving;
    _errorCode = null;
    notifyListeners();

    final snapshot = _snapshot();
    final payloadJson = jsonEncode(TransferDraftJson.encode(snapshot));
    var draftId = _draftId;
    final store = drafts;
    if (store != null && !_unsupportedDraft) {
      try {
        draftId = await store.save(snapshot);
        _draftId = draftId;
        _hasDraft = true;
      } on Object {
        // A failed draft write does not block the confirmed Save.
        draftId = null;
      }
    }
    try {
      final saved = await gateway.saveTransfer(
        setup: setup,
        draftId: draftId,
        payloadJson: payloadJson,
      );
      _status = TransferFormStatus.saved;
      await _discardAfterSave();
      notifyListeners();
      return saved;
    } on TransferFormError catch (error) {
      _errorCode = error.code;
      _status = TransferFormStatus.failed;
      notifyListeners();
      return null;
    } on Object {
      _errorCode = TransferErrorCode.saveFailed;
      _status = TransferFormStatus.failed;
      notifyListeners();
      return null;
    }
  }

  /// SPEC 8.18: one compensating command for the confirmed transfer.
  Future<void> undo(SavedTransfer saved) async {
    try {
      await gateway.undoTransfer(saved);
    } on Object {
      // The record stays; the caller refreshes to its current state.
    }
  }

  void _update(VoidCallback change, {bool persist = true}) {
    if (_status == TransferFormStatus.saved) {
      return;
    }
    change();
    _userEdited = true;
    if (_status == TransferFormStatus.failed) {
      _status = TransferFormStatus.editing;
      _errorCode = null;
    }
    if (persist) {
      _schedulePersist();
    }
    notifyListeners();
  }

  AccountSummary? _accountById(String? id) {
    if (id == null) {
      return null;
    }
    for (final account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  TransferFormDraft _snapshot() => TransferFormDraft(
        amountText: _amountText,
        currencyCode: _currencyCode,
        date: _date,
        fromAccountId: _from?.id,
        toAccountId: _to?.id,
      );

  void _schedulePersist() {
    final store = drafts;
    if (store == null || _unsupportedDraft) {
      return;
    }
    final snapshot = _snapshot();
    _hasDraft = true;
    _persistChain = _persistChain.then((_) => _writeDraft(store, snapshot));
  }

  Future<void> _writeDraft(
    TransferDraftStore store,
    TransferFormDraft snapshot,
  ) async {
    try {
      _draftId = await store.save(snapshot);
    } on Object {
      // A failed draft write keeps the fields; the next edit tries again.
    }
  }

  Future<void> _discardAfterSave() async {
    _hasDraft = false;
    _unsupportedDraft = false;
    _draftId = null;
    final store = drafts;
    if (store == null) {
      return;
    }
    try {
      await store.discard();
    } on Object {
      // The draft header may already be committed; nothing else to clear.
    }
  }
}
