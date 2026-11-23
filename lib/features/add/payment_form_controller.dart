// P22 (SPEC 3.1, 3.2, 8.3, 8.16; flow F03 steps 1–6): the X20 controller.
//
// The controller holds the draft, validates it and calls the one gateway. It
// writes nothing before Save (F03-C). A failed Save keeps every entry, so the
// person corrects one field and tries again. Money uses Decimal and Money; no
// `double` and no formatting (AGENTS 2.3, 6.4).
//
// A sentence typed into "Where or what?" fills the fields through the P10
// parser and marks the fields that need a check (SPEC 8.3, 8.10). Parsing never
// writes and never calls a model.
library;

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/importers/quick_add_parser.dart' hide PaymentDraft;
import '../../domain/importers/quick_add_parser.dart' as domain;
import '../accounts/account_models.dart';
import 'payment_draft.dart';
import 'payment_models.dart';

/// The lifecycle of one X20 Save.
enum PaymentFormStatus { loading, editing, saving, saved, failed }

/// The draft and its save state. The widget listens and calls the setters.
final class PaymentFormController extends ChangeNotifier {
  PaymentFormController({
    required this.gateway,
    required this.today,
    this.drafts,
    this.editing,
    this.parser = const QuickAddParser(),
    PaymentKind kind = PaymentKind.expense,
    String currencyCode = 'USD',
  })  : _kind = kind,
        _currencyCode = currencyCode,
        _date = today,
        _edit = editing;

  final PaymentsGateway gateway;

  /// The local date used for the default payment date.
  final LocalDate today;

  /// The draft store. Null keeps the form in memory only.
  final PaymentDraftStore? drafts;

  /// F03 step 1: the record an edit changes. Null is a create.
  final PaymentEdit? editing;

  /// SPEC 8.3: the local sentence parser. Deterministic rules only.
  final QuickAddParser parser;

  PaymentKind _kind;
  String _amountText = '';
  String _currencyCode;
  LocalDate _date;
  AccountSummary? _account;
  CategorySummary? _category;
  final Set<String> _tagIds = <String>{};
  List<PaymentDraftSplit> _splits = const <PaymentDraftSplit>[];
  String _merchantText = '';
  Set<DraftField> _unsureFields = const <DraftField>{};

  List<AccountSummary> _accounts = const <AccountSummary>[];
  List<CategorySummary> _categories = const <CategorySummary>[];
  List<TagSummary> _tags = const <TagSummary>[];

  PaymentFormStatus _status = PaymentFormStatus.loading;
  PaymentsErrorCode? _errorCode;
  PaymentEdit? _edit;
  String? _draftId;
  bool _hasDraft = false;
  bool _unsupportedDraft = false;
  bool _userEdited = false;
  bool _loaded = false;
  Future<void> _persistChain = Future<void>.value();

  PaymentKind get kind => _kind;
  String get amountText => _amountText;
  String get currencyCode => _currencyCode;
  LocalDate get date => _date;
  AccountSummary? get account => _account;
  CategorySummary? get category => _category;
  List<AccountSummary> get accounts => _accounts;
  List<CategorySummary> get categories => _categories;
  List<TagSummary> get tags => _tags;
  Set<String> get selectedTagIds => Set<String>.unmodifiable(_tagIds);
  List<PaymentDraftSplit> get splits => List<PaymentDraftSplit>.unmodifiable(
        _splits,
      );
  String get merchantText => _merchantText;
  Set<DraftField> get unsureFields => Set<DraftField>.unmodifiable(
        _unsureFields,
      );
  PaymentFormStatus get status => _status;
  PaymentsErrorCode? get errorCode => _errorCode;
  PaymentEdit? get edit => _edit;

  /// A draft exists for this form (the Discard action is offered).
  bool get hasDraft => _hasDraft;

  /// The stored draft is from another schema or unreadable. It is kept until
  /// an explicit Discard (P01) and no new draft is written over it.
  bool get draftUnsupported => _unsupportedDraft;

  /// True once the form data is loaded (the screen may show its fields).
  bool get loaded => _loaded;

  /// Tests await this to see the last queued draft write.
  Future<void> get pendingDraftWrite => _persistChain;

  Currency get currency => Currency.of(_currencyCode);

  /// The entered magnitude, or null while the field is empty.
  Money? get enteredAmount => _parseAmount(_amountText);

  /// The signed amount the payment stores: an expense is negative (P09).
  int? get signedAmountMinor {
    final amount = enteredAmount;
    if (amount == null) {
      return null;
    }
    return _kind.isIncome ? amount.minor : -amount.minor;
  }

  bool get amountInvalid =>
      _amountText.isNotEmpty && _amountText != '.' && enteredAmount == null;

  /// The sum of the split parts, as a magnitude.
  Money? get splitTotal {
    if (_splits.isEmpty) {
      return null;
    }
    var total = 0;
    for (final split in _splits) {
      final part = _parseAmount(split.amountText);
      if (part == null) {
        return null;
      }
      total += part.minor;
    }
    return Money.fromMinor(total, currency);
  }

  /// What is left to split. Null before an amount or with an unreadable part.
  Money? get splitRemainder {
    final amount = enteredAmount;
    final total = splitTotal;
    if (amount == null || (_splits.isNotEmpty && total == null)) {
      return null;
    }
    return Money.fromMinor(
      amount.minor - (total?.minor ?? 0),
      currency,
    );
  }

  /// X23: Save is active only when nothing is left to split and at least two
  /// parts exist (one part would be a category, not a split).
  bool get splitIsExact =>
      _splits.length >= 2 && (splitRemainder?.isZero ?? false);

  /// SPEC 3.1 / F03-A: an amount and an account. A category is optional.
  bool get canSave =>
      _status != PaymentFormStatus.saving &&
      _status != PaymentFormStatus.saved &&
      _status != PaymentFormStatus.loading &&
      enteredAmount != null &&
      enteredAmount!.minor > 0 &&
      _account != null &&
      (_splits.isEmpty || splitIsExact);

  /// SPEC 3.2: the Save label carries the amount ("Save $24.00").
  Money? get saveAmount => enteredAmount;

  /// Reads the accounts, categories and tags, then one stored draft.
  Future<void> initialize() async {
    try {
      final data = await gateway.loadForm(kind: _kind);
      _accounts = data.accounts;
      _categories = data.categories;
      _tags = data.tags;
      _kindLoadedFor = _kind;
      if (!_userEdited && _currencyCode == 'USD') {
        _currencyCode = data.lastCurrencyCode;
      }
    } on Object {
      _accounts = const <AccountSummary>[];
      _categories = const <CategorySummary>[];
      _tags = const <TagSummary>[];
    }
    _status = PaymentFormStatus.editing;
    _loaded = true;
    notifyListeners();
    await loadDraft();
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
      case LoadedPaymentDraft(:final id, :final draft):
        _draftId = id;
        if (!_userEdited) {
          _kind = draft.kind;
          _amountText = draft.amountText;
          _currencyCode = draft.currencyCode;
          _date = draft.date;
          _account = _accountById(draft.accountId);
          _category = _categoryById(draft.categoryId);
          _tagIds
            ..clear()
            ..addAll(draft.tagIds.where(_tagExists));
          _merchantText = draft.merchantText;
          _splits = draft.splits;
          _unsureFields = draft.unsureFields;
          _edit = draft.edit;
          if (_kind != _kindLoadedFor) {
            await _reloadCategories(_kind);
          }
        }
        _hasDraft = true;
      case UnsupportedPaymentDraft():
        _hasDraft = true;
        _unsupportedDraft = true;
      case NoPaymentDraft():
        _hasDraft = false;
    }
    notifyListeners();
  }

  /// The kind whose categories are loaded.
  PaymentKind? _kindLoadedFor;

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

  /// SPEC 8.3 / 3.2: the type is one choice. A category of the other type is
  /// cleared, because a category belongs to one kind.
  void setKind(PaymentKind value) {
    if (value == _kind) {
      return;
    }
    _update(() {
      _kind = value;
      _category = null;
      _edit = null;
    });
    _reloadCategories(value);
  }

  void setCurrency(String code) => _update(() => _currencyCode = code);

  void setDate(LocalDate value) => _update(() => _date = value);

  void selectAccount(AccountSummary value) => _update(() => _account = value);

  /// An uncategorised payment is allowed (F03-A). Null clears the choice.
  void selectCategory(CategorySummary? value) =>
      _update(() => _category = value);

  void toggleTag(String tagId) => _update(() {
        if (!_tagIds.remove(tagId)) {
          _tagIds.add(tagId);
        }
      });

  /// X22 Done: the exact tag set the sheet returned.
  void setTags(Iterable<String> tagIds) => _update(() {
        _tagIds
          ..clear()
          ..addAll(tagIds);
      });

  void setMerchant(String value) => _update(() {
        _merchantText = value;
        _unsureFields = const <DraftField>{};
      });

  /// X23: the parts returned by the split editor. A copy of the draft.
  void setSplitParts(List<PaymentDraftSplit> parts) => _update(() {
        _splits = List<PaymentDraftSplit>.unmodifiable(parts);
      });

  void clearSplitParts() => _update(() {
        _splits = const <PaymentDraftSplit>[];
      });

  /// Tables in the C01 account model (P14). A new account is selected.
  void addAccount(AccountSummary account) => _update(() {
        if (!_accounts.any((row) => row.id == account.id)) {
          _accounts = <AccountSummary>[..._accounts, account];
        }
        _account = account;
      });

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

  /// SPEC 8.16: amount entry ends when another field takes focus, a sheet
  /// opens or Save runs. The committed amount is written with the draft.
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

  /// SPEC 8.3 / 8.10: fills the fields from one typed sentence.
  ///
  /// The parser is deterministic. A category or account name fills its field
  /// only when a loaded record has that name; otherwise the field stays empty
  /// and the person chooses. Returns the parsed draft for the review screen
  /// (P24) or a test.
  Future<domain.PaymentDraft> parseSentence(String text) async {
    final parsed = parser.parse(
      text,
      today: today,
      mainCurrency: currency,
    );
    final wantedKind = parsed.isIncome ? PaymentKind.income : _kind;
    if (wantedKind != _kind) {
      _update(
        () {
          _kind = wantedKind;
          _category = null;
        },
        persist: false,
      );
      await _reloadCategories(wantedKind);
    }
    _update(() {
      final amount = parsed.amount;
      if (amount != null) {
        _amountText = _plainAmount(amount);
        _currencyCode = parsed.currency.code;
      }
      if (parsed.dateExplicit) {
        _date = parsed.date;
      }
      final merchant = parsed.merchant;
      if (merchant != null) {
        _merchantText = merchant;
      }
      final categoryName = parsed.category;
      if (categoryName != null) {
        _category = _categoryByName(categoryName);
      }
      final accountName = parsed.account;
      if (accountName != null) {
        _account = _accountByName(accountName) ?? _account;
      }
      _unsureFields = <DraftField>{
        for (final entry in parsed.confidence.entries)
          if (entry.value == FieldConfidence.unsure) entry.key,
      };
    });
    return parsed;
  }

  /// F03 step 5: one Save.
  ///
  /// Returns the confirmed payment, or null on a failure. A failure keeps the
  /// draft and sets [errorCode]; nothing is written on a validation failure.
  Future<SavedPayment?> save() async {
    if (_status == PaymentFormStatus.saving ||
        _status == PaymentFormStatus.saved) {
      return null;
    }
    if (!canSave) {
      _errorCode = PaymentsErrorCode.invalidPayment;
      _status = PaymentFormStatus.failed;
      notifyListeners();
      return null;
    }
    final setup = PaymentSetup(
      kind: _kind,
      amountMinor: signedAmountMinor!,
      currencyCode: _currencyCode,
      date: _date,
      accountId: _account!.id,
      merchantName: _merchantText.trim().isEmpty ? null : _merchantText.trim(),
      categoryId: _category?.id,
      tagIds: _tagIds.toList(growable: false),
      splits: <PaymentSplitSetup>[
        for (final split in _splits)
          PaymentSplitSetup(
            categoryId: split.categoryId,
            amountMinor: _signedPart(split),
          ),
      ],
      edit: _edit,
    );
    _status = PaymentFormStatus.saving;
    _errorCode = null;
    notifyListeners();

    final snapshot = _snapshot();
    final payloadJson = jsonEncode(PaymentDraftJson.encode(snapshot));
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
      final saved = await gateway.savePayment(
        setup: setup,
        draftId: draftId,
        payloadJson: payloadJson,
      );
      _status = PaymentFormStatus.saved;
      await _discardAfterSave();
      notifyListeners();
      return saved;
    } on PaymentsError catch (error) {
      _errorCode = error.code;
      _status = PaymentFormStatus.failed;
      notifyListeners();
      return null;
    } on Object {
      _errorCode = PaymentsErrorCode.saveFailed;
      _status = PaymentFormStatus.failed;
      notifyListeners();
      return null;
    }
  }

  int _signedPart(PaymentDraftSplit split) {
    final part = _parseAmount(split.amountText)?.minor ?? 0;
    return _kind.isIncome ? part : -part;
  }

  void _update(VoidCallback change, {bool persist = true}) {
    if (_status == PaymentFormStatus.saved) {
      return;
    }
    change();
    _userEdited = true;
    if (_status == PaymentFormStatus.failed) {
      _status = PaymentFormStatus.editing;
      _errorCode = null;
    }
    if (persist) {
      _schedulePersist();
    }
    notifyListeners();
  }

  Future<void> _reloadCategories(PaymentKind kind) async {
    try {
      final data = await gateway.loadForm(kind: kind);
      _kindLoadedFor = kind;
      if (_kind != kind) {
        return;
      }
      _categories = data.categories;
      _accounts = data.accounts;
      _tags = data.tags;
      notifyListeners();
    } on Object {
      // A closed store keeps the previous list; the person can retry.
    }
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

  AccountSummary? _accountByName(String name) {
    final wanted = name.toLowerCase();
    for (final account in _accounts) {
      if (account.name.toLowerCase() == wanted) {
        return account;
      }
    }
    return null;
  }

  CategorySummary? _categoryById(String? id) {
    if (id == null) {
      return null;
    }
    for (final category in _categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  CategorySummary? _categoryByName(String name) {
    final wanted = name.toLowerCase();
    for (final category in _categories) {
      if (category.name.toLowerCase() == wanted) {
        return category;
      }
    }
    return null;
  }

  bool _tagExists(String id) => _tags.any((tag) => tag.id == id);

  String _plainAmount(Money amount) {
    final digits = BigInt.from(amount.minor).abs().toString().padLeft(
          amount.currency.minorUnits + 1,
          '0',
        );
    if (amount.currency.minorUnits == 0) {
      return digits;
    }
    final whole = digits.substring(
      0,
      digits.length - amount.currency.minorUnits,
    );
    final fraction =
        digits.substring(digits.length - amount.currency.minorUnits);
    return '$whole.$fraction';
  }

  PaymentFormDraft _snapshot() => PaymentFormDraft(
        kind: _kind,
        amountText: _amountText,
        currencyCode: _currencyCode,
        date: _date,
        accountId: _account?.id,
        categoryId: _category?.id,
        tagIds: _tagIds.toList(growable: false),
        merchantText: _merchantText,
        splits: _splits,
        unsureFields: _unsureFields,
        edit: _edit,
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
    PaymentDraftStore store,
    PaymentFormDraft snapshot,
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
