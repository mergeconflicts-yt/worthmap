import 'package:decimal/decimal.dart';

import '../../core/dates.dart';
import '../../core/money.dart';

/// SPEC 8.3 / 8.10: one-line quick add and voice parsing, on the phone.
///
/// The parser turns a sentence into a [PaymentDraft] with per-field
/// confidence. It never writes to the database, never calls a model and never
/// guesses an amount. Text in, draft out.
///
/// Grammar (SPEC 8.3): `[amount] [currency?] [words] [date words?]
/// [#category?] [@account?]`. Voice adds spoken numbers, currency words,
/// merchant after "at"/"from", category after "for"/"on", dates, and the
/// account after "with"/"using"/"on my" (SPEC 8.10).

/// A field the review screen shows with its confidence (X25).
enum DraftField { amount, date, merchant, category, account }

/// SPEC 8.10 / X25: how a field was filled.
enum FieldConfidence {
  /// The sentence did not fill the field.
  absent,

  /// The sentence filled it, but the value needs a check (dashed in X25).
  unsure,

  /// The sentence filled it and it is trusted (tinted with a check).
  filled,
}

/// SPEC 8.10: the parsed payment, before Save.
final class PaymentDraft {
  const PaymentDraft({
    required this.amount,
    required this.currency,
    required this.currencyExplicit,
    required this.date,
    required this.dateExplicit,
    required this.merchant,
    required this.category,
    required this.account,
    required this.isIncome,
    required this.secondAmount,
    required this.confidence,
  });

  /// The first amount, or null when the sentence has none.
  final Money? amount;

  /// The stated currency, or the main currency when none is stated.
  final Currency currency;

  /// True when the sentence named a currency.
  final bool currencyExplicit;

  /// The payment date; today when the sentence names none.
  final LocalDate date;

  /// True when the sentence named a date.
  final bool dateExplicit;

  /// The merchant after "at" or "from", when present.
  final String? merchant;

  /// The category name from "#", "for"/"on" or a keyword rule.
  final String? category;

  /// The account name from "@", "with", "using" or "on my".
  final String? account;

  /// True when the sentence reads as money in (got, received, salary).
  final bool isIncome;

  /// SPEC 8.10: a second amount, offered only after the first Save.
  final Money? secondAmount;

  final Map<DraftField, FieldConfidence> confidence;

  /// True when an amount was found; false keeps the keypad active.
  bool get hasAmount => amount != null;

  /// The confidence of [field] (absent when not listed).
  FieldConfidence confidenceOf(DraftField field) =>
      confidence[field] ?? FieldConfidence.absent;

  /// How many review fields the sentence filled with trust (X25 "4 filled").
  int get filledCount => confidence.values
      .where((value) => value == FieldConfidence.filled)
      .length;

  /// How many review fields need a check (X25 "1 to check").
  int get unsureCount => confidence.values
      .where((value) => value == FieldConfidence.unsure)
      .length;
}

/// SPEC 8.3 / 8.10: parses a sentence with the caller's small data tables.
///
/// [knownMerchants] resolves a loosely typed name ("star bucks" becomes
/// "Starbucks"). [keywordCategories] is the default keyword rule table
/// (SPEC 8.9); the caller supplies it so no category is hard-coded here.
/// [dayFirst] reads "12/10" as 12 October; the other order is 10 December.
final class QuickAddParser {
  const QuickAddParser({
    this.knownMerchants = const <String>[],
    this.keywordCategories = const <String, String>{},
    this.dayFirst = true,
  });

  /// Merchant names to resolve a loosely typed match against.
  final List<String> knownMerchants;

  /// Keyword to category name, in priority order (SPEC 8.9).
  final Map<String, String> keywordCategories;

  /// True when a numeric date reads day first.
  final bool dayFirst;

  /// Parses [text] for the day [today] and the [mainCurrency].
  PaymentDraft parse(
    String text, {
    required LocalDate today,
    required Currency mainCurrency,
  }) {
    final tokens = _tokenise(text);
    final dateMatch = _findDate(tokens, today, dayFirst);
    final dateIndices = dateMatch?.indices ?? const <int>{};
    final amounts = _findAmounts(tokens, dateIndices);
    final first = amounts.isEmpty ? null : amounts.first;
    final second = amounts.length > 1 ? amounts[1] : null;
    final parseEnd = second == null ? tokens.length : second.first;

    final consumed = <int>{...dateIndices};
    if (first != null) {
      consumed.addAll(first.indices);
    }

    final currency = first?.currency ?? mainCurrency;
    final amount =
        first == null ? null : Money.fromDecimal(first.value, currency);

    final category = _findCategory(
      tokens,
      consumed,
      parseEnd,
      keywordCategories,
    );
    final merchant = _findMerchant(
      tokens,
      consumed,
      parseEnd,
      knownMerchants,
    );
    final account = _findAccount(tokens, consumed, parseEnd);
    final isIncome = tokens.any(
      (token) => _incomeWords.contains(token.lower),
    );

    final effectiveCategory = category ?? (isIncome ? 'Income' : null);
    final secondAmount =
        second == null ? null : Money.fromDecimal(second.value, currency);

    return PaymentDraft(
      amount: amount,
      currency: currency,
      currencyExplicit: first?.currency != null,
      date: dateMatch?.date ?? today,
      dateExplicit: dateMatch != null,
      merchant: merchant,
      category: effectiveCategory,
      account: account?.name,
      isIncome: isIncome,
      secondAmount: secondAmount,
      confidence: <DraftField, FieldConfidence>{
        DraftField.amount:
            amount == null ? FieldConfidence.absent : FieldConfidence.filled,
        DraftField.date:
            dateMatch == null ? FieldConfidence.absent : FieldConfidence.filled,
        DraftField.merchant:
            merchant == null ? FieldConfidence.absent : FieldConfidence.filled,
        DraftField.category: effectiveCategory == null
            ? FieldConfidence.absent
            : FieldConfidence.filled,
        DraftField.account:
            account == null ? FieldConfidence.absent : account.confidence,
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tokens

final class _Token {
  const _Token(this.raw, this.lower);

  final String raw;
  final String lower;
}

final RegExp _tokenPattern = RegExp(r'\S+');

List<_Token> _tokenise(String text) => <_Token>[
      for (final match in _tokenPattern.allMatches(text))
        _Token(match.group(0)!, match.group(0)!.toLowerCase()),
    ];

// ---------------------------------------------------------------------------
// Small tables

const Map<String, int> _monthNumbers = <String, int>{
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

const Map<String, int> _weekdays = <String, int>{
  'monday': 1,
  'tuesday': 2,
  'wednesday': 3,
  'thursday': 4,
  'friday': 5,
  'saturday': 6,
  'sunday': 7,
};

const Map<String, String> _currencySymbols = <String, String>{
  r'$': 'USD',
  '€': 'EUR',
  '£': 'GBP',
  '₹': 'INR',
  '¥': 'JPY',
};

const Map<String, String> _currencyWords = <String, String>{
  'dollar': 'USD',
  'dollars': 'USD',
  'buck': 'USD',
  'bucks': 'USD',
  'euro': 'EUR',
  'euros': 'EUR',
  'pound': 'GBP',
  'pounds': 'GBP',
  'rupee': 'INR',
  'rupees': 'INR',
  'yen': 'JPY',
};

const Set<String> _incomeWords = <String>{'got', 'received', 'salary'};

const Set<String> _stopWords = <String>{
  'at',
  'from',
  'for',
  'on',
  'with',
  'using',
  'and',
  'my',
  'last',
  'next',
};

const Set<String> _dateUnits = <String>{
  'day',
  'days',
  'week',
  'weeks',
  'month',
  'months',
  'year',
  'years',
  'hour',
  'hours',
};

const Set<String> _numberWords = <String>{
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
  'twenty',
  'thirty',
  'forty',
  'fifty',
  'sixty',
  'seventy',
  'eighty',
  'ninety',
};

int? _spokenNumber(String word) {
  final small = <String, int>{
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };
  return small[word];
}

Currency? _currencyFromCode(String code) {
  if (!RegExp(r'^[a-zA-Z]{3}$').hasMatch(code)) {
    return null;
  }
  try {
    return Currency.of(code.toUpperCase());
  } on ArgumentError {
    return null;
  }
}

Currency? _currencyWord(String lower) {
  final code = _currencyWords[lower];
  return code == null ? null : Currency.of(code);
}

Currency? _currencyInToken(String lower) {
  for (final entry in _currencySymbols.entries) {
    if (lower.contains(entry.key)) {
      return Currency.of(entry.value);
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Amounts

final class _AmountMatch {
  const _AmountMatch({
    required this.first,
    required this.last,
    required this.value,
    required this.currency,
  });

  final int first;
  final int last;
  final Decimal value;
  final Currency? currency;

  Set<int> get indices => <int>{
        for (var i = first; i <= last; i++) i,
      };
}

String? _numericCore(String lower) {
  var text = lower;
  for (final symbol in _currencySymbols.keys) {
    text = text.replaceAll(symbol, '');
  }
  if (text.isEmpty) {
    return null;
  }
  if (!RegExp(r'^[0-9][0-9.,]*[kK]?$').hasMatch(text)) {
    return null;
  }
  if (text.endsWith('.') || text.endsWith(',')) {
    return null;
  }
  return text;
}

Decimal _parseNumberText(String text) {
  var value = text;
  var multiplier = Decimal.one;
  if (value.endsWith('k') || value.endsWith('K')) {
    multiplier = Decimal.fromInt(1000);
    value = value.substring(0, value.length - 1);
  }
  final hasDot = value.contains('.');
  final hasComma = value.contains(',');
  String normalised;
  if (hasDot && hasComma) {
    final decimalIsDot = value.lastIndexOf('.') > value.lastIndexOf(',');
    final thousandSeparator = decimalIsDot ? ',' : '.';
    normalised = value.replaceAll(thousandSeparator, '');
    if (!decimalIsDot) {
      normalised = normalised.replaceAll(',', '.');
    }
  } else if (hasDot || hasComma) {
    final separator = hasDot ? '.' : ',';
    final parts = value.split(separator);
    if (parts.length == 2 && parts[1].length == 3 && parts[0].length <= 3) {
      normalised = parts.join();
    } else if (parts.length > 2) {
      normalised = parts.join();
    } else {
      normalised = parts.join('.');
    }
  } else {
    normalised = value;
  }
  return Decimal.parse(normalised) * multiplier;
}

List<_AmountMatch> _findAmounts(
  List<_Token> tokens,
  Set<int> dateIndices,
) {
  final matches = <_AmountMatch>[];
  var index = 0;
  while (index < tokens.length) {
    if (dateIndices.contains(index)) {
      index++;
      continue;
    }
    final token = tokens[index].lower;
    final numeric = _numericCore(token);
    if (numeric != null) {
      if (_followedByDate(tokens, index)) {
        index++;
        continue;
      }
      final value = _parseNumberText(numeric);
      var last = index;
      var currency = _currencyInToken(token);
      if (currency == null && index + 1 < tokens.length) {
        final next = tokens[index + 1].lower;
        final word = _currencyWord(next) ?? _currencyFromCode(next);
        if (word != null) {
          currency = word;
          last = index + 1;
          if (index + 2 < tokens.length &&
              RegExp(r'^[0-9]{1,2}$').hasMatch(tokens[index + 2].lower) &&
              RegExp(r'^[0-9]+$').hasMatch(numeric)) {
            final minor = tokens[index + 2].lower;
            final combined =
                Decimal.tryParse('$numeric.${minor.padLeft(2, '0')}');
            if (combined != null) {
              matches.add(
                _AmountMatch(
                  first: index,
                  last: index + 2,
                  value: combined,
                  currency: currency,
                ),
              );
              index += 3;
              continue;
            }
          }
        }
      }
      matches.add(
        _AmountMatch(
          first: index,
          last: last,
          value: value,
          currency: currency,
        ),
      );
      index = last + 1;
      continue;
    }
    final spoken = _spokenNumber(token);
    if (spoken != null) {
      if (index + 1 < tokens.length &&
          _dateUnits.contains(tokens[index + 1].lower)) {
        index++;
        continue;
      }
      var value = Decimal.fromInt(spoken);
      var last = index;
      Currency? currency;
      if (index + 1 < tokens.length) {
        final next = tokens[index + 1].lower;
        final nextSpoken = _spokenNumber(next);
        if (nextSpoken != null && nextSpoken >= 20 && nextSpoken % 10 == 0) {
          value =
              Decimal.parse('$spoken.${nextSpoken.toString().padLeft(2, '0')}');
          last = index + 1;
        } else if (nextSpoken != null &&
            nextSpoken < 10 &&
            spoken >= 20 &&
            spoken % 10 == 0) {
          value = Decimal.fromInt(spoken + nextSpoken);
          last = index + 1;
        } else {
          final word = _currencyWord(next) ?? _currencyFromCode(next);
          if (word != null) {
            currency = word;
            last = index + 1;
          }
        }
      }
      matches.add(
        _AmountMatch(
          first: index,
          last: last,
          value: value,
          currency: currency,
        ),
      );
      index = last + 1;
      continue;
    }
    index++;
  }
  return matches;
}

bool _followedByDate(List<_Token> tokens, int index) {
  if (index + 1 >= tokens.length) {
    return false;
  }
  final next = tokens[index + 1].lower;
  return _dateUnits.contains(next) || _monthNumbers.containsKey(next);
}

// ---------------------------------------------------------------------------
// Dates

final class _DateMatch {
  const _DateMatch(this.date, this.indices);

  final LocalDate date;
  final Set<int> indices;
}

_DateMatch? _findDate(
  List<_Token> tokens,
  LocalDate today,
  bool dayFirst,
) {
  for (var index = 0; index < tokens.length; index++) {
    final lower = tokens[index].lower;
    if (lower == 'today') {
      return _DateMatch(today, <int>{index});
    }
    if (lower == 'yesterday') {
      return _DateMatch(_shift(today, -1), <int>{index});
    }
    final offset = RegExp(r'^-([0-9]+)d$').firstMatch(lower);
    if (offset != null) {
      final days = int.parse(offset.group(1)!);
      return _DateMatch(_shift(today, -days), <int>{index});
    }
    if (lower == 'last' &&
        index + 1 < tokens.length &&
        _weekdays.containsKey(tokens[index + 1].lower)) {
      return _DateMatch(
        _mostRecentPast(today, _weekdays[tokens[index + 1].lower]!),
        <int>{index, index + 1},
      );
    }
    if (_weekdays.containsKey(lower)) {
      return _DateMatch(
        _mostRecentPast(today, _weekdays[lower]!),
        <int>{index},
      );
    }
    final ago = _daysAgo(tokens, index);
    if (ago != null) {
      return _DateMatch(_shift(today, -ago.days), ago.indices);
    }
    final numericDate = _numericMonthDate(tokens, index, today);
    if (numericDate != null) {
      return numericDate;
    }
    final slashed = RegExp(r'^([0-9]{1,2})/([0-9]{1,2})$').firstMatch(lower);
    if (slashed != null) {
      final first = int.parse(slashed.group(1)!);
      final second = int.parse(slashed.group(2)!);
      final day = dayFirst ? first : second;
      final month = dayFirst ? second : first;
      final resolved = _recentYearDate(today, month, day);
      if (resolved != null) {
        return _DateMatch(resolved, <int>{index});
      }
    }
  }
  return null;
}

final class _DaysAgo {
  const _DaysAgo(this.days, this.indices);

  final int days;
  final Set<int> indices;
}

_DaysAgo? _daysAgo(List<_Token> tokens, int index) {
  if (index + 2 >= tokens.length) {
    return null;
  }
  if (tokens[index + 1].lower != 'day' && tokens[index + 1].lower != 'days') {
    return null;
  }
  if (tokens[index + 2].lower != 'ago') {
    return null;
  }
  final word = tokens[index].lower;
  final days = RegExp(r'^[0-9]+$').hasMatch(word)
      ? int.parse(word)
      : _spokenNumber(word);
  if (days == null || days <= 0) {
    return null;
  }
  return _DaysAgo(days, <int>{index, index + 1, index + 2});
}

_DateMatch? _numericMonthDate(
  List<_Token> tokens,
  int index,
  LocalDate today,
) {
  final lower = tokens[index].lower;
  if (!RegExp(r'^[0-9]{1,2}$').hasMatch(lower)) {
    return null;
  }
  if (index + 1 >= tokens.length) {
    return null;
  }
  final month = _monthNumbers[tokens[index + 1].lower];
  if (month == null) {
    return null;
  }
  final day = int.parse(lower);
  if (index + 2 < tokens.length &&
      RegExp(r'^[0-9]{4}$').hasMatch(tokens[index + 2].lower)) {
    final year = int.parse(tokens[index + 2].lower);
    if (!_isValid(day, month, year)) {
      return null;
    }
    return _DateMatch(
      LocalDate(year, month, day),
      <int>{index, index + 1, index + 2},
    );
  }
  final resolved = _recentYearDate(today, month, day);
  if (resolved == null) {
    return null;
  }
  return _DateMatch(resolved, <int>{index, index + 1});
}

bool _isValid(int day, int month, int year) =>
    day >= 1 && day <= LocalDate.daysInMonth(year, month);

LocalDate? _recentYearDate(LocalDate today, int month, int day) {
  if (!_isValid(day, month, today.year)) {
    return null;
  }
  final thisYear = LocalDate(today.year, month, day);
  if (thisYear.compareTo(today) <= 0) {
    return thisYear;
  }
  if (!_isValid(day, month, today.year - 1)) {
    return null;
  }
  return LocalDate(today.year - 1, month, day);
}

LocalDate _mostRecentPast(LocalDate today, int weekday) {
  final current = _weekdayOf(today);
  var back = (current - weekday) % 7;
  if (back == 0) {
    back = 7;
  }
  return _shift(today, -back);
}

int _weekdayOf(LocalDate date) =>
    DateTime.utc(date.year, date.month, date.day).weekday;

LocalDate _shift(LocalDate date, int days) {
  final shifted = DateTime.utc(date.year, date.month, date.day + days);
  return LocalDate(shifted.year, shifted.month, shifted.day);
}

// ---------------------------------------------------------------------------
// Category, merchant and account

String? _findCategory(
  List<_Token> tokens,
  Set<int> consumed,
  int parseEnd,
  Map<String, String> keywordCategories,
) {
  for (var index = 0; index < parseEnd; index++) {
    if (consumed.contains(index)) {
      continue;
    }
    final token = tokens[index].lower;
    if (token.startsWith('#') && token.length > 1) {
      consumed.add(index);
      return _title(token.substring(1).replaceAll('-', ' '));
    }
  }
  for (var index = 0; index < parseEnd; index++) {
    if (consumed.contains(index)) {
      continue;
    }
    final token = tokens[index].lower;
    if (token == 'on' &&
        index + 1 < parseEnd &&
        tokens[index + 1].lower == 'my') {
      continue;
    }
    if (token == 'for' || token == 'on') {
      final indices = _phraseAfter(tokens, index + 1, consumed, parseEnd);
      if (indices.isNotEmpty) {
        final name = indices.map((i) => tokens[i].raw).join(' ');
        consumed
          ..add(index)
          ..addAll(indices);
        return _title(name);
      }
    }
  }
  for (var index = 0; index < parseEnd; index++) {
    if (consumed.contains(index)) {
      continue;
    }
    final word = tokens[index].lower;
    for (final entry in keywordCategories.entries) {
      if (word == entry.key) {
        consumed.add(index);
        return entry.value;
      }
    }
  }
  return null;
}

List<int> _phraseAfter(
  List<_Token> tokens,
  int start,
  Set<int> consumed,
  int parseEnd,
) {
  final indices = <int>[];
  for (var index = start; index < parseEnd; index++) {
    if (consumed.contains(index)) {
      break;
    }
    final lower = tokens[index].lower;
    if (_stopWords.contains(lower) ||
        _weekdays.containsKey(lower) ||
        _monthNumbers.containsKey(lower) ||
        _dateUnits.contains(lower) ||
        _numberWords.contains(lower) ||
        _numericCore(lower) != null ||
        lower.startsWith('#') ||
        lower.startsWith('@')) {
      break;
    }
    indices.add(index);
  }
  return indices;
}

String? _findMerchant(
  List<_Token> tokens,
  Set<int> consumed,
  int parseEnd,
  List<String> knownMerchants,
) {
  for (var index = 0; index < parseEnd; index++) {
    if (consumed.contains(index)) {
      continue;
    }
    final token = tokens[index].lower;
    if (token != 'at' && token != 'from') {
      continue;
    }
    final indices = _phraseAfter(tokens, index + 1, consumed, parseEnd);
    if (indices.isEmpty) {
      continue;
    }
    consumed
      ..add(index)
      ..addAll(indices);
    final raw = indices.map((i) => tokens[i].raw).join(' ');
    return _resolveMerchant(raw, knownMerchants);
  }
  return null;
}

final class _AccountMatch {
  const _AccountMatch(this.name, this.confidence);

  final String name;
  final FieldConfidence confidence;
}

_AccountMatch? _findAccount(
  List<_Token> tokens,
  Set<int> consumed,
  int parseEnd,
) {
  for (var index = 0; index < parseEnd; index++) {
    if (consumed.contains(index)) {
      continue;
    }
    final token = tokens[index].lower;
    if (token.startsWith('@') && token.length > 1) {
      consumed.add(index);
      return _AccountMatch(
        token.substring(1),
        FieldConfidence.filled,
      );
    }
  }
  for (var index = 0; index < parseEnd; index++) {
    if (consumed.contains(index)) {
      continue;
    }
    final token = tokens[index].lower;
    final isOnMy = token == 'on' &&
        index + 1 < parseEnd &&
        tokens[index + 1].lower == 'my';
    if (token != 'with' && token != 'using' && !isOnMy) {
      continue;
    }
    var start = index + 1;
    if (start < parseEnd && tokens[start].lower == 'my') {
      start++;
    }
    final indices = _phraseAfter(tokens, start, consumed, parseEnd);
    if (indices.isEmpty) {
      continue;
    }
    consumed
      ..add(index)
      ..addAll(indices);
    final name = indices.map((i) => tokens[i].raw).join(' ');
    return _AccountMatch(name, FieldConfidence.unsure);
  }
  return null;
}

String _title(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final lower = trimmed.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

String _normalise(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _resolveMerchant(String raw, List<String> known) {
  final normalised = _normalise(raw);
  for (final merchant in known) {
    if (_normalise(merchant) == normalised) {
      return merchant;
    }
  }
  return raw;
}
