import 'package:contour/core/dates.dart';

/// SPEC 8.10: the voice test sentences and their expected drafts.
///
/// Amounts are in minor units of the stated currency; a null currency means
/// the main currency. [dayOffset] is relative to the test day (13 Oct 2026).

final class ExpectedPayment {
  const ExpectedPayment({
    this.amountMinor,
    this.currencyCode,
    this.merchant,
    this.category,
    this.dayOffset = 0,
    this.isIncome = false,
    this.secondAmountMinor,
  });

  final int? amountMinor;
  final String? currencyCode;
  final String? merchant;
  final String? category;
  final int dayOffset;
  final bool isIncome;
  final int? secondAmountMinor;
}

final class SentenceCase {
  const SentenceCase(this.sentence, this.expected);

  final String sentence;
  final ExpectedPayment expected;
}

/// The nine SPEC 8.10 test sentences.
const List<SentenceCase> voiceCases = <SentenceCase>[
  SentenceCase(
    'Spent 40\$ for food today at Starbucks',
    ExpectedPayment(
      amountMinor: 4000,
      currencyCode: 'USD',
      merchant: 'Starbucks',
      category: 'Food',
    ),
  ),
  SentenceCase(
    'Spent forty dollars on food at star bucks',
    ExpectedPayment(
      amountMinor: 4000,
      currencyCode: 'USD',
      merchant: 'Starbucks',
      category: 'Food',
    ),
  ),
  SentenceCase(
    'Paid twelve fifty for parking yesterday',
    ExpectedPayment(
      amountMinor: 1250,
      category: 'Parking',
      dayOffset: -1,
    ),
  ),
  SentenceCase(
    'Taxi 340 with cash',
    ExpectedPayment(amountMinor: 34000, category: 'Transport'),
  ),
  SentenceCase(
    'Bought groceries at Tesco for 1.2k last Friday',
    ExpectedPayment(
      amountMinor: 120000,
      merchant: 'Tesco',
      category: 'Groceries',
      dayOffset: -4,
    ),
  ),
  SentenceCase(
    '40 at Starbucks and 12 for parking',
    ExpectedPayment(
      amountMinor: 4000,
      merchant: 'Starbucks',
      secondAmountMinor: 1200,
    ),
  ),
  SentenceCase(
    'Coffee 4 euros 50 using my Visa',
    ExpectedPayment(
      amountMinor: 450,
      currencyCode: 'EUR',
      category: 'Coffee',
    ),
  ),
  SentenceCase(
    'Got 500 salary bonus',
    ExpectedPayment(
      amountMinor: 50000,
      category: 'Income',
      isIncome: true,
    ),
  ),
  SentenceCase(
    'Lunch at Subway',
    ExpectedPayment(merchant: 'Subway'),
  ),
];

/// The six SPEC 8.3 must-pass quick-add lines.
const List<SentenceCase> quickAddCases = <SentenceCase>[
  SentenceCase('lunch 180', ExpectedPayment(amountMinor: 18000)),
  SentenceCase('180 lunch', ExpectedPayment(amountMinor: 18000)),
  SentenceCase(
    'taxi 340 yesterday',
    ExpectedPayment(
      amountMinor: 34000,
      category: 'Transport',
      dayOffset: -1,
    ),
  ),
  SentenceCase(
    '€12.50 coffee',
    ExpectedPayment(
      amountMinor: 1250,
      currencyCode: 'EUR',
      category: 'Coffee',
    ),
  ),
  SentenceCase(
    'coffee 12,50 EUR',
    ExpectedPayment(
      amountMinor: 1250,
      currencyCode: 'EUR',
      category: 'Coffee',
    ),
  ),
  SentenceCase(
    'rent 25000 #housing @bank',
    ExpectedPayment(amountMinor: 2500000, category: 'Housing'),
  ),
  SentenceCase(
    'lunch 18 at subway',
    ExpectedPayment(amountMinor: 1800, merchant: 'Subway'),
  ),
];

/// The test day: Tuesday 13 October 2026 (SPEC Appendix A).
final LocalDate testDay = LocalDate.parse('2026-10-13');
