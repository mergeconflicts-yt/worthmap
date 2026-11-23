// P22 (flow F03; SPEC 8.16, 8.18): the app composition for the payment form.
//
// This is the only adapter between the payment feature port and the data
// layer. It holds no state and logs nothing (AGENTS 2.6). One Save is one
// command on the single writer: an intent, a receipt, ChangeLog rows and, when
// a draft exists, the sealed draft (P13).
//
// A typed failure resolves through the receipt first (a lost reply is a
// success), then releases the uncommitted attempt so the next Save allocates a
// new operation id (P13-DRAFTS).
library;

import 'dart:convert';
import 'dart:math';

import '../core/dates.dart';
import '../core/ids.dart';
import '../data/db/command_repository.dart';
import '../data/repositories/accounts.dart';
import '../data/repositories/categories.dart';
import '../data/repositories/payments.dart';
import '../data/repositories/write_plan.dart';
import '../features/accounts/account_models.dart';
import '../features/add/payment_models.dart';

/// P12 + P14 + the single command writer behind the payment port.
final class SqlPaymentsGateway implements PaymentsGateway {
  SqlPaymentsGateway({
    required this.accounts,
    required this.categories,
    required this.payments,
    required this.commands,
    required this.today,
    required this.newId,
    this.lastCurrency,
  });

  final AccountRepository accounts;
  final CategoryRepository categories;
  final PaymentRepository payments;
  final CommandRepository commands;

  /// The cut-off for a listed balance and the default payment date.
  final LocalDate Function() today;

  /// A UUID v7 source. The app boundary supplies the clock and randomness
  /// (AGENTS 6.3).
  final String Function() newId;

  /// SPEC 3.2: the last currency used. Null falls back to the first account's
  /// currency, then USD (DECISIONS P22-DEFAULTS).
  final String Function()? lastCurrency;

  @override
  Future<PaymentFormData> loadForm({required PaymentKind kind}) async {
    final asOf = today().toString();
    final rows = await accounts.list();
    final accountRows = <AccountSummary>[
      for (final row in rows)
        AccountSummary(
          id: row.id,
          name: row.name,
          kind: _kind(row.type),
          currencyCode: row.currency,
          balanceMinor: await _balance(row.id, asOf),
        ),
    ];
    final categoryRows = await categories.list(
      kind: kind.isIncome ? 'income' : 'expense',
    );
    final tagRows = await categories.tags();
    final currency = lastCurrency?.call() ??
        (accountRows.isEmpty ? 'USD' : accountRows.first.currencyCode);
    return PaymentFormData(
      accounts: accountRows,
      categories: <CategorySummary>[
        for (final row in categoryRows)
          CategorySummary(id: row.id, name: row.name),
      ],
      tags: <TagSummary>[
        for (final row in tagRows) TagSummary(id: row.id, name: row.name),
      ],
      lastCurrencyCode: currency,
    );
  }

  @override
  Future<SavedPayment> savePayment({
    required PaymentSetup setup,
    String? draftId,
    String? payloadJson,
  }) async {
    if (draftId != null) {
      // A repeated Save returns the recorded result before any effect is
      // prepared, so one draft never writes twice (F03-B).
      final committed = await commands.committedOutcomeOf(draftId);
      if (committed != null) {
        return _saved(committed, setup);
      }
    }
    final eventId = newId();
    final paymentId = setup.edit?.paymentId ?? newId();
    final plan = await _plan(setup, paymentId: paymentId, eventId: eventId);
    final resultJson = jsonEncode(<String, Object?>{
      'payment': paymentId,
      'event': setup.edit?.eventId ?? eventId,
      'edit': setup.edit != null,
    });
    final operationId = newId();
    try {
      if (draftId != null && payloadJson != null) {
        final outcome = await commands.saveDraft(
          draftId: draftId,
          commandType: setup.edit == null ? 'payment.create' : 'payment.edit',
          payloadJson: payloadJson,
          payloadVersion: 1,
          codecVersion: 1,
          changes: plan.changes,
          effects: plan.apply,
          resultJson: resultJson,
        );
        return _saved(outcome, setup);
      }
      await commands.prepare(
        operationId: operationId,
        commandType: setup.edit == null ? 'payment.create' : 'payment.edit',
        draftId: newId(),
        formType: 'payment',
        payloadJson: payloadJson ?? '{"v":1}',
        payloadVersion: 1,
        codecVersion: 1,
        schemaVersion: 1,
      );
      final outcome = await commands.execute(
        operationId: operationId,
        changes: plan.changes,
        effects: plan.apply,
        resultJson: resultJson,
      );
      return _saved(outcome, setup);
    } on Object {
      final resolved = draftId == null
          ? await _resolveWithoutDraft(operationId)
          : await _resolveDraft(draftId);
      if (resolved != null) {
        return _saved(resolved, setup);
      }
      throw const PaymentsError(PaymentsErrorCode.saveFailed);
    }
  }

  @override
  Future<void> undoPayment(SavedPayment saved) async {
    final plan = await payments.planUndoCreate(paymentId: saved.paymentId);
    final operationId = newId();
    await commands.prepare(
      operationId: operationId,
      commandType: 'payment.undo',
      draftId: newId(),
      formType: 'paymentUndo',
      payloadJson: jsonEncode(<String, Object?>{'undoOf': saved.operationId}),
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    try {
      await commands.execute(
        operationId: operationId,
        changes: plan.changes,
        effects: plan.apply,
        resultJson: '{}',
      );
    } on Object {
      final receipt = await commands.receiptOf(operationId);
      if (receipt == null) {
        throw const PaymentsError(PaymentsErrorCode.undoFailed);
      }
    }
  }

  /// F03 step 5: a create adds one event; an edit changes the existing one.
  Future<WritePlan> _plan(
    PaymentSetup setup, {
    required String paymentId,
    required String eventId,
  }) async {
    final edit = setup.edit;
    final splits = <PaymentSplitInput>[
      for (final split in setup.splits)
        PaymentSplitInput(
          id: newId(),
          categoryId: split.categoryId,
          amountMinor: split.amountMinor,
        ),
    ];
    if (edit == null) {
      return payments.planCreate(
        NewPayment(
          id: paymentId,
          eventId: eventId,
          accountId: setup.accountId,
          date: setup.date.toString(),
          amountMinor: setup.amountMinor,
          currency: setup.currencyCode,
          kind: setup.kind.databaseType,
          merchantName: setup.merchantName,
          note: setup.note,
          categoryId: setup.categoryId,
          splits: splits,
          tagIds: setup.tagIds,
        ),
      );
    }
    return payments.planUpdate(
      id: edit.paymentId,
      expectedRevision: edit.expectedRevision,
      date: setup.date.toString(),
      amountMinor: setup.amountMinor,
      kind: setup.kind.databaseType,
      merchantName: setup.merchantName,
      note: setup.note,
      categoryId: setup.categoryId,
      splits: splits,
      tagIds: setup.tagIds,
    );
  }

  SavedPayment _saved(CommandOutcome outcome, PaymentSetup setup) {
    String? paymentId;
    String? eventId;
    var edit = setup.edit != null;
    try {
      final result = jsonDecode(outcome.resultJson);
      if (result is Map<String, Object?>) {
        paymentId = result['payment'] as String?;
        eventId = result['event'] as String?;
        edit = (result['edit'] as bool?) ?? edit;
      }
    } on FormatException {
      // A receipt without fields still names the committed operation.
    }
    return SavedPayment(
      paymentId: paymentId ?? setup.edit?.paymentId ?? '',
      eventId: eventId ?? setup.edit?.eventId ?? '',
      operationId: outcome.operationId,
      amountMinor: setup.amountMinor,
      currencyCode: setup.currencyCode,
      kind: setup.kind,
      date: setup.date,
      edit: edit,
    );
  }

  /// A lost response after a commit is a success. Otherwise the attempt is
  /// released so the next Save allocates a new operation id (SPEC 8.16).
  Future<CommandOutcome?> _resolveDraft(String draftId) async {
    final operationId = await commands.activeOperationId(draftId);
    if (operationId == null) {
      return null;
    }
    final receipt = await commands.receiptOf(operationId);
    if (receipt != null) {
      return receipt;
    }
    try {
      await commands.releaseUncommitted(operationId);
    } on Object {
      // A concurrent commit is resolved by the next receipt read.
    }
    return commands.receiptOf(operationId);
  }

  Future<CommandOutcome?> _resolveWithoutDraft(String operationId) async {
    final receipt = await commands.receiptOf(operationId);
    if (receipt != null) {
      return receipt;
    }
    try {
      await commands.releaseUncommitted(operationId);
    } on Object {
      // Nothing to release; the Save failed before an intent existed.
    }
    return null;
  }

  Future<int?> _balance(String accountId, String asOf) async {
    final balance = await accounts.balanceAt(accountId: accountId, asOf: asOf);
    return switch (balance) {
      KnownBalance(:final amount) => amount.minor,
      MissingBalance() => null,
    };
  }

  static AccountKind _kind(String type) => switch (type) {
        'card' => AccountKind.card,
        'cash' => AccountKind.cash,
        _ => AccountKind.bank,
      };
}

/// The production cut-off: the local calendar date.
LocalDate paymentToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}

/// A UUID v7 from the wall clock and secure randomness, for the app boundary.
String newPaymentId() {
  final now = DateTime.now().toUtc();
  final random = Random.secure();
  return UuidV7.generate(
    unixMillis: now.millisecondsSinceEpoch,
    randomBytes: List<int>.generate(10, (_) => random.nextInt(256)),
  ).toString();
}
