// P21 (SPEC 6.6; flow C01; SPEC 8.16): the C01 account setup controller.
//
// The controller holds the draft, validates it and calls the one gateway. It
// writes nothing until Save. A failed save keeps every entry, so the person
// can correct one field and try again. Money uses Decimal and Money; no
// `double` and no formatting (AGENTS 2.3, 6.4).
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import 'account_draft.dart';
import 'account_models.dart';

/// The lifecycle of one C01 save.
enum AccountSetupStatus { editing, saving, saved, failed }

/// The draft and its save state. The widget listens and calls the setters.
final class AccountSetupController extends ChangeNotifier {
  AccountSetupController({
    required this.gateway,
    required this.today,
    AccountKind? kind,
    this.drafts,
  })  : _kind = kind,
        _date = today {
    if (kind != null) {
      _countsAsCash = !kind.isLiability;
    }
  }

  final AccountsGateway gateway;

  /// The draft store. Null keeps the form in memory only.
  final AccountDraftStore? drafts;

  /// The local date used for the default inclusive anchor.
  final LocalDate today;

  String _name = '';
  AccountKind? _kind;
  String _currencyCode = 'USD';
  String _amountText = '';
  LocalDate _date;
  bool _countsAsCash = true;
  bool _includeInNetWorth = true;
  AccountSetupStatus _status = AccountSetupStatus.editing;
  AccountsErrorCode? _errorCode;
  bool _hasDraft = false;
  bool _unsupportedDraft = false;
  bool _loadingDraft = false;
  bool _userEdited = false;
  Future<void> _persistChain = Future<void>.value();

  String get name => _name;
  AccountKind? get kind => _kind;
  String get currencyCode => _currencyCode;
  String get amountText => _amountText;
  LocalDate get openingDate => _date;
  bool get countsAsCash => _countsAsCash;
  bool get includeInNetWorth => _includeInNetWorth;
  AccountSetupStatus get status => _status;
  AccountsErrorCode? get errorCode => _errorCode;

  /// A draft exists for this form (the Discard action is offered).
  bool get hasDraft => _hasDraft;

  /// The stored draft is from another schema or unreadable. It is kept until
  /// an explicit Discard (P01) and no new draft is written over it.
  bool get draftUnsupported => _unsupportedDraft;

  /// Tests await this to see the last queued draft write.
  Future<void> get pendingDraftWrite => _persistChain;

  Currency get _currency => Currency.of(_currencyCode);

  /// The entered balance, or null while the field is empty ("Missing").
  Money? get openingAmount => _parseAmount(_amountText);

  /// A non-empty amount that cannot be read is invalid, not Missing.
  bool get amountInvalid =>
      _amountText.isNotEmpty && _amountText != '.' && openingAmount == null;

  /// SPEC 6.6: name, type and balance today are required. An entered zero is
  /// a real balance (G01-E).
  bool get canSave =>
      _status != AccountSetupStatus.saving &&
      _name.trim().isNotEmpty &&
      _kind != null &&
      openingAmount != null;

  /// SPEC 8.16: reads the stored draft once. A user edit made before the read
  /// completes wins; the draft never overwrites newer input.
  Future<void> loadDraft() async {
    final store = drafts;
    if (store == null || _loadingDraft) {
      return;
    }
    _loadingDraft = true;
    try {
      final loaded = await store.load();
      switch (loaded) {
        case LoadedAccountDraft(:final draft):
          if (!_userEdited) {
            _name = draft.name;
            _kind = draft.kind;
            _currencyCode = draft.currencyCode;
            _amountText = draft.amountText;
            _date = draft.date;
            _countsAsCash = draft.countsAsCash;
            _includeInNetWorth = draft.includeInNetWorth;
          }
          _hasDraft = true;
        case UnsupportedAccountDraft():
          _hasDraft = true;
          _unsupportedDraft = true;
        case NoAccountDraft():
          _hasDraft = false;
      }
    } on Object {
      // An unreadable store is no draft; the form stays usable.
      _hasDraft = false;
    } finally {
      _loadingDraft = false;
      notifyListeners();
    }
  }

  /// Deletes the stored draft and clears the flag. The form fields stay.
  Future<void> discardDraft() async {
    final store = drafts;
    await _persistChain;
    _hasDraft = false;
    _unsupportedDraft = false;
    if (store != null) {
      try {
        await store.discard();
      } on Object {
        // A committed or missing draft has nothing to discard.
      }
    }
    notifyListeners();
  }

  void setName(String value) => _update(() => _name = value);

  /// C01: the type is one required choice. A card does not count as cash.
  void setKind(AccountKind value) => _update(() {
        _kind = value;
        _countsAsCash = !value.isLiability;
      });

  void setCurrency(String code) => _update(() {
        _currencyCode = code;
      });

  /// The inclusive anchor date (G01-A).
  void setDate(LocalDate value) => _update(() => _date = value);

  void setCountsAsCash(bool value) => _update(() => _countsAsCash = value);

  void setIncludeInNetWorth(bool value) =>
      _update(() => _includeInNetWorth = value);

  /// One keypad press: a digit or the decimal point.
  void pressKey(String key) => _update(() {
        if (key == '.') {
          if (_amountText.contains('.') || _currency.minorUnits == 0) {
            return;
          }
          _amountText = _amountText.isEmpty ? '0.' : '$_amountText.';
          return;
        }
        if (!RegExp(r'^\d$').hasMatch(key)) {
          return;
        }
        if (_amountText.contains('.') &&
            _digitsAfterPoint >= _currency.minorUnits) {
          return;
        }
        if (!_amountText.contains('.') && _integerDigits >= 12) {
          return;
        }
        _amountText = _amountText == '0' ? key : '$_amountText$key';
      });

  void deleteKey() => _update(() {
        if (_amountText.isNotEmpty) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
        }
      });

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
      return Money.fromDecimal(Decimal.parse(text), _currency);
    } on Object {
      return null;
    }
  }

  /// C01: `CreateAccount` + `SetOpeningBalance` in one commit.
  ///
  /// Returns the new account, or null on a failure. A failure keeps the draft
  /// and sets [errorCode]; nothing is written on a validation failure.
  Future<AccountSummary?> save() async {
    if (!canSave) {
      _errorCode = AccountsErrorCode.invalidSetup;
      _status = AccountSetupStatus.failed;
      notifyListeners();
      return null;
    }
    final amount = openingAmount!;
    final date = _date;
    final kind = _kind!;
    final setup = AccountSetup(
      name: _name.trim(),
      kind: kind,
      currencyCode: _currencyCode,
      openingBalanceMinor: amount.minor.abs(),
      openingDate: date,
      countsAsCash: _countsAsCash,
      includeInNetWorth: _includeInNetWorth,
    );
    _status = AccountSetupStatus.saving;
    _errorCode = null;
    notifyListeners();
    try {
      final account = await gateway.createAccount(setup);
      _status = AccountSetupStatus.saved;
      await _persistChain;
      await _discardAfterSave();
      notifyListeners();
      return account;
    } on AccountsError catch (error) {
      _errorCode = error.code;
      _status = AccountSetupStatus.failed;
      notifyListeners();
      return null;
    } on Object {
      _errorCode = AccountsErrorCode.saveFailed;
      _status = AccountSetupStatus.failed;
      notifyListeners();
      return null;
    }
  }

  void _update(VoidCallback change) {
    if (_status == AccountSetupStatus.saved) {
      return;
    }
    change();
    _userEdited = true;
    if (_status == AccountSetupStatus.failed) {
      _status = AccountSetupStatus.editing;
      _errorCode = null;
    }
    _schedulePersist();
    notifyListeners();
  }

  AccountDraft _snapshot() => AccountDraft(
        name: _name,
        kind: _kind,
        currencyCode: _currencyCode,
        amountText: _amountText,
        date: _date,
        countsAsCash: _countsAsCash,
        includeInNetWorth: _includeInNetWorth,
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
    AccountDraftStore store,
    AccountDraft snapshot,
  ) async {
    try {
      await store.save(snapshot);
    } on Object {
      // A failed draft write keeps the fields; the next edit tries again.
    }
  }

  Future<void> _discardAfterSave() async {
    _hasDraft = false;
    _unsupportedDraft = false;
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
