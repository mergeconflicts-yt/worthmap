// P26 (flow F08; SPEC 4.4, 6.5): the Spending state.
//
// One controller for the root, where it goes, money in and budget. A second
// controller holds the limits draft and one SaveLimits. No controller writes a
// payment (F08-E).
library;

import 'package:flutter/foundation.dart';

import 'spending_models.dart';

/// The load lifecycle of a Spending screen.
enum SpendingLoadState { loading, ready, failed }

/// The selected period and its numbers.
final class SpendingController extends ChangeNotifier {
  SpendingController({
    required this.gateway,
    SpendingPeriod period = SpendingPeriod.month,
  }) : _period = period;

  final SpendingGateway gateway;

  SpendingPeriod _period;
  SpendingLoadState _state = SpendingLoadState.loading;
  SpendingView? _view;
  LimitsView? _limits;
  SpendingRowsView? _rows;
  SpendingErrorCode? _errorCode;

  SpendingPeriod get period => _period;
  SpendingLoadState get state => _state;
  SpendingView? get view => _view;
  LimitsView? get limits => _limits;

  /// The monthly row summaries. Null when the summary read failed.
  SpendingRowsView? get rows => _rows;
  SpendingErrorCode? get errorCode => _errorCode;

  /// Reads the period and the limits (the rings need both).
  Future<void> load() async {
    _state = SpendingLoadState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      final view = await gateway.loadSpending(_period);
      final limits = await _safeLimits();
      _view = view;
      _limits = limits;
      _state = SpendingLoadState.ready;
      notifyListeners();
      _rows = await _safeRows();
      notifyListeners();
    } on Object {
      _state = SpendingLoadState.failed;
      _errorCode = SpendingErrorCode.loadFailed;
      notifyListeners();
    }
  }

  Future<LimitsView?> _safeLimits() async {
    try {
      return await gateway.loadLimits();
    } on Object {
      return null;
    }
  }

  Future<SpendingRowsView?> _safeRows() async {
    try {
      return await gateway.loadRows();
    } on Object {
      return null;
    }
  }

  /// A chip tap. The previous numbers stay until the new period arrives.
  Future<void> selectPeriod(SpendingPeriod period) async {
    if (period == _period) {
      return;
    }
    _period = period;
    notifyListeners();
    await load();
  }

  /// The per-category limit, or zero when none is set.
  int limitFor(String categoryId) {
    final limits = _limits;
    if (limits == null) {
      return 0;
    }
    for (final row in limits.rows) {
      if (row.categoryId == categoryId) {
        return row.limitMinor;
      }
    }
    return 0;
  }
}

/// X33: the limits draft and one SaveLimits.
final class LimitsController extends ChangeNotifier {
  LimitsController({required this.gateway});

  final SpendingGateway gateway;

  SpendingLoadState _state = SpendingLoadState.loading;
  LimitsView? _view;
  final Map<String, int> _draft = <String, int>{};
  SpendingErrorCode? _errorCode;
  bool _saving = false;

  SpendingLoadState get state => _state;
  LimitsView? get view => _view;
  SpendingErrorCode? get errorCode => _errorCode;
  bool get saving => _saving;

  /// The edited value for one category.
  int limitFor(String categoryId) =>
      _draft[categoryId] ?? _viewLimit(categoryId);

  int _viewLimit(String categoryId) {
    final view = _view;
    if (view == null) {
      return 0;
    }
    for (final row in view.rows) {
      if (row.categoryId == categoryId) {
        return row.limitMinor;
      }
    }
    return 0;
  }

  /// The draft total, from the edited values.
  int? get totalMinor {
    final view = _view;
    if (view == null) {
      return null;
    }
    var sum = 0;
    var any = false;
    for (final row in view.rows) {
      final value = limitFor(row.categoryId);
      if (value > 0) {
        sum += value;
        any = true;
      }
    }
    return any ? sum : null;
  }

  int get categoryCount {
    final view = _view;
    if (view == null) {
      return 0;
    }
    return view.rows.where((row) => limitFor(row.categoryId) > 0).length;
  }

  Future<void> load() async {
    _state = SpendingLoadState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _view = await gateway.loadLimits();
      _draft.clear();
      _state = SpendingLoadState.ready;
      notifyListeners();
    } on Object {
      _state = SpendingLoadState.failed;
      _errorCode = SpendingErrorCode.loadFailed;
      notifyListeners();
    }
  }

  void setLimit(String categoryId, int minor) {
    if (minor < 0) {
      return;
    }
    _draft[categoryId] = minor;
    notifyListeners();
  }

  /// `SaveLimits`. Returns true when the command committed.
  Future<bool> save() async {
    if (_saving || _state != SpendingLoadState.ready) {
      return false;
    }
    final view = _view!;
    _saving = true;
    _errorCode = null;
    notifyListeners();
    final limits = <String, int>{
      for (final row in view.rows) row.categoryId: limitFor(row.categoryId),
    };
    try {
      await gateway.saveLimits(limits);
      _saving = false;
      return true;
    } on SpendingError catch (error) {
      _saving = false;
      _errorCode = error.code;
      notifyListeners();
      return false;
    } on Object {
      _saving = false;
      _errorCode = SpendingErrorCode.saveFailed;
      notifyListeners();
      return false;
    }
  }
}

/// X30c and X31: money in and the spending of the same period.
final class MoneyInController extends ChangeNotifier {
  MoneyInController({
    required this.gateway,
    SpendingPeriod period = SpendingPeriod.month,
  }) : _period = period;

  final SpendingGateway gateway;

  SpendingPeriod _period;
  SpendingLoadState _state = SpendingLoadState.loading;
  MoneyInView? _view;
  SpendingView? _spending;
  SpendingErrorCode? _errorCode;

  SpendingPeriod get period => _period;
  SpendingLoadState get state => _state;
  MoneyInView? get view => _view;
  SpendingView? get spending => _spending;
  SpendingErrorCode? get errorCode => _errorCode;

  Future<void> load() async {
    _state = SpendingLoadState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      final view = await gateway.loadMoneyIn(_period);
      SpendingView? spending;
      try {
        spending = await gateway.loadSpending(_period);
      } on Object {
        spending = null;
      }
      _view = view;
      _spending = spending;
      _state = SpendingLoadState.ready;
      notifyListeners();
    } on Object {
      _state = SpendingLoadState.failed;
      _errorCode = SpendingErrorCode.loadFailed;
      notifyListeners();
    }
  }

  Future<void> selectPeriod(SpendingPeriod period) async {
    if (period == _period) {
      return;
    }
    _period = period;
    notifyListeners();
    await load();
  }
}
