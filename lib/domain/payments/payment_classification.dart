import '../../core/money.dart';
import '../numbers/spending_totals.dart';

/// SPEC 4.2 / 4.10 / 8.17: classifies one payment into its linked postings.
///
/// Pure Dart. A command asks for the postings it would write; the classifier
/// validates the shape and returns signed ledger effects. It never writes and
/// never invents a fee, a rate or a second copy of an amount.
///
/// Sign rule (DATABASE_DESIGN 4.2; SPEC 6.6): a posting is negative when money
/// leaves the account and positive when it enters it. A card purchase is
/// negative on the card account; a payment to the card is positive there.

/// The account facts the classifier needs (SPEC 6.6).
final class AccountRef {
  const AccountRef({
    required this.id,
    required this.currency,
    this.isLiability = false,
    this.includeInNetWorth = true,
  }) : assert(id != '');

  /// The account identifier.
  final String id;

  /// The account currency.
  final Currency currency;

  /// True for a card, loan or other liability account.
  final bool isLiability;

  /// True when the account counts in net worth (SPEC 4.4).
  final bool includeInNetWorth;
}

/// One signed posting the command writes.
final class Posting {
  const Posting({
    required this.account,
    required this.kind,
    required this.amount,
  });

  /// The account the amount posts to.
  final AccountRef account;

  /// The posting class (expense, income, transfer or fee).
  final SpendingKind kind;

  /// The signed amount: negative leaves the account, positive enters it.
  final Money amount;

  /// True for one side of a transfer principal.
  bool get isPrincipal => kind == SpendingKind.transfer;
}

/// The posting set of one confirmed payment event.
final class PaymentEvent {
  PaymentEvent({required this.postings}) {
    if (postings.isEmpty) {
      throw ArgumentError.value(postings, 'postings', 'Must not be empty');
    }
  }

  /// Every posting of the event, principal and fee included.
  final List<Posting> postings;

  /// The fee posting, when the transfer charged one (SPEC 4.10).
  Posting? get feePosting {
    for (final posting in postings) {
      if (posting.kind == SpendingKind.fee) {
        return posting;
      }
    }
    return null;
  }

  /// SPEC 4.7: the net worth effect of the event's postings.
  ///
  /// Each posting counts only when its account is in net-worth scope. A
  /// principal transfer between two included accounts sums to zero (F05-A);
  /// a transfer across the boundary leaves a real change (F05-E).
  Money get netWorthChange {
    final currency = postings.first.amount.currency;
    var total = Money.zero(currency);
    for (final posting in postings) {
      if (posting.account.includeInNetWorth) {
        total = total + posting.amount;
      }
    }
    return total;
  }
}

/// A payment the user is confirming.
sealed class PaymentRequest {
  const PaymentRequest();
}

/// An expense on one account (SPEC 6.3).
final class ExpenseRequest extends PaymentRequest {
  ExpenseRequest({required this.amount, required this.account}) {
    _requirePositive(amount, account);
  }

  /// The amount spent, positive.
  final Money amount;

  /// The paying account.
  final AccountRef account;
}

/// Money in on one account (SPEC 6.3).
final class IncomeRequest extends PaymentRequest {
  IncomeRequest({required this.amount, required this.account}) {
    _requirePositive(amount, account);
  }

  /// The amount received, positive.
  final Money amount;

  /// The receiving account.
  final AccountRef account;
}

/// A transfer between two owned accounts, with an optional charged fee
/// (SPEC 6.3, 4.10). Cross-currency transfers are v1.1.
final class TransferRequest extends PaymentRequest {
  TransferRequest({
    required this.from,
    required this.to,
    required this.amount,
    this.fee,
  }) {
    if (from.id == to.id) {
      throw ArgumentError.value(
        to.id,
        'to',
        'Must differ from the from account',
      );
    }
    if (from.currency != to.currency) {
      throw ArgumentError(
        'A cross-currency transfer is not available in this phase (v1.1)',
      );
    }
    _requirePositive(amount, from);
    final fee = this.fee;
    if (fee != null) {
      if (fee.minor <= 0) {
        throw ArgumentError.value(fee, 'fee', 'Must be positive when charged');
      }
      if (fee.currency != from.currency) {
        throw MoneyCurrencyMismatch(fee.currency.code, from.currency.code);
      }
    }
  }

  /// The paying account.
  final AccountRef from;

  /// The receiving account.
  final AccountRef to;

  /// The amount that leaves [from] and enters [to], positive.
  final Money amount;

  /// The charged fee, or null when no fee is charged.
  final Money? fee;

  /// True when the destination is a liability account (a card repayment).
  bool get paysLiability => to.isLiability;
}

void _requirePositive(Money amount, AccountRef account) {
  if (amount.minor <= 0) {
    throw ArgumentError.value(amount, 'amount', 'Must be positive');
  }
  if (amount.currency != account.currency) {
    throw MoneyCurrencyMismatch(
      amount.currency.code,
      account.currency.code,
    );
  }
}

/// SPEC 4.2 / 4.10: builds the posting set for [request].
///
/// A transfer writes one debit and one credit and at most one fee posting.
/// The fee is money out (4.10); the principal is neither income nor spending.
PaymentEvent classifyPayment(PaymentRequest request) => switch (request) {
      ExpenseRequest() => _expense(request),
      IncomeRequest() => _income(request),
      TransferRequest() => _transfer(request),
    };

PaymentEvent _expense(ExpenseRequest request) => PaymentEvent(
      postings: <Posting>[
        Posting(
          account: request.account,
          kind: SpendingKind.expense,
          amount: -request.amount,
        ),
      ],
    );

PaymentEvent _income(IncomeRequest request) => PaymentEvent(
      postings: <Posting>[
        Posting(
          account: request.account,
          kind: SpendingKind.income,
          amount: request.amount,
        ),
      ],
    );

PaymentEvent _transfer(TransferRequest request) {
  final postings = <Posting>[
    Posting(
      account: request.from,
      kind: SpendingKind.transfer,
      amount: -request.amount,
    ),
    Posting(
      account: request.to,
      kind: SpendingKind.transfer,
      amount: request.amount,
    ),
  ];
  final fee = request.fee;
  if (fee != null) {
    postings.add(
      Posting(
        account: request.from,
        kind: SpendingKind.fee,
        amount: -fee,
      ),
    );
  }
  return PaymentEvent(postings: postings);
}
