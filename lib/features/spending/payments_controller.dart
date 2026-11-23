// P27 (flow F08 steps 2–4): the payment list, detail and category state.
//
// The list applies a returned filter only (F08-A). A delete returns the
// committed result so the screen can offer Undo; a restore is the one
// compensating command (F08-C).
library;

import 'package:flutter/foundation.dart';

import 'payments_models.dart';

/// The load lifecycle.
enum PaymentsViewState { loading, ready, failed }

/// X37: one applied filter and its page.
final class PaymentsListController extends ChangeNotifier {
  PaymentsListController({
    required this.gateway,
    PaymentFilter filter = const PaymentFilter(
      period: PaymentPeriod.thisMonth,
      show: PaymentShowFilter.moneyOut,
    ),
  }) : _filter = filter;

  final PaymentsReadGateway gateway;

  PaymentFilter _filter;
  PaymentsViewState _state = PaymentsViewState.loading;
  PaymentListPage? _page;
  PaymentsReadErrorCode? _errorCode;

  PaymentFilter get filter => _filter;
  PaymentsViewState get state => _state;
  PaymentListPage? get page => _page;
  PaymentsReadErrorCode? get errorCode => _errorCode;

  Future<void> load() async {
    _state = PaymentsViewState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _page = await gateway.loadPayments(_filter);
      _state = PaymentsViewState.ready;
      notifyListeners();
    } on Object {
      _state = PaymentsViewState.failed;
      _errorCode = PaymentsReadErrorCode.loadFailed;
      notifyListeners();
    }
  }

  /// X38 "Show" returns the filter; Back keeps the previous one.
  Future<void> apply(PaymentFilter filter) async {
    _filter = filter;
    notifyListeners();
    await load();
  }
}

/// X39: one payment and its delete/restore.
final class PaymentDetailController extends ChangeNotifier {
  PaymentDetailController({required this.gateway, required this.paymentId});

  final PaymentsReadGateway gateway;
  final String paymentId;

  PaymentsViewState _state = PaymentsViewState.loading;
  PaymentDetailView? _view;
  PaymentsReadErrorCode? _errorCode;

  PaymentsViewState get state => _state;
  PaymentDetailView? get view => _view;
  PaymentsReadErrorCode? get errorCode => _errorCode;

  Future<void> load() async {
    _state = PaymentsViewState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _view = await gateway.loadPayment(paymentId);
      _state =
          _view == null ? PaymentsViewState.failed : PaymentsViewState.ready;
      if (_view == null) {
        _errorCode = PaymentsReadErrorCode.loadFailed;
      }
      notifyListeners();
    } on Object {
      _state = PaymentsViewState.failed;
      _errorCode = PaymentsReadErrorCode.loadFailed;
      notifyListeners();
    }
  }

  /// X39b confirm: one soft delete. Null on a failure.
  Future<DeletedPayment?> delete() async {
    final view = _view;
    if (view == null) {
      return null;
    }
    try {
      return await gateway.deletePayment(view);
    } on Object {
      _errorCode = PaymentsReadErrorCode.deleteFailed;
      notifyListeners();
      return null;
    }
  }

  /// The 5 s toast Undo.
  Future<void> restore(DeletedPayment deleted) async {
    try {
      await gateway.restorePayment(deleted);
      await load();
    } on Object {
      _errorCode = PaymentsReadErrorCode.restoreFailed;
      notifyListeners();
    }
  }
}

/// X36: one category and its numbers.
final class CategoryDetailController extends ChangeNotifier {
  CategoryDetailController({
    required this.gateway,
    required this.categoryId,
    PaymentPeriod period = PaymentPeriod.thisMonth,
  }) : _period = period;

  final PaymentsReadGateway gateway;
  final String categoryId;

  PaymentPeriod _period;
  PaymentsViewState _state = PaymentsViewState.loading;
  CategoryDetailView? _view;
  PaymentsReadErrorCode? _errorCode;

  PaymentPeriod get period => _period;
  PaymentsViewState get state => _state;
  CategoryDetailView? get view => _view;
  PaymentsReadErrorCode? get errorCode => _errorCode;

  Future<void> load() async {
    _state = PaymentsViewState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _view = await gateway.loadCategory(categoryId, period: _period);
      _state = PaymentsViewState.ready;
      notifyListeners();
    } on Object {
      _state = PaymentsViewState.failed;
      _errorCode = PaymentsReadErrorCode.loadFailed;
      notifyListeners();
    }
  }

  Future<void> selectPeriod(PaymentPeriod period) async {
    if (period == _period) {
      return;
    }
    _period = period;
    notifyListeners();
    await load();
  }
}
