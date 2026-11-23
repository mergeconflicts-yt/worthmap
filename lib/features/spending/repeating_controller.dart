// P28 (flow F09): the repeating list, one schedule and the rules list.
//
// Reads and the two writes (`StopSchedule`, `SaveRule`) go through one port.
// A schedule write never creates a payment (F09-A).
library;

import 'package:flutter/foundation.dart';

import '../../core/dates.dart';
import 'repeating_models.dart';

/// The load lifecycle.
enum RepeatingState { loading, ready, failed }

/// X34.
final class RepeatingController extends ChangeNotifier {
  RepeatingController({required this.gateway});

  final RepeatingGateway gateway;

  RepeatingState _state = RepeatingState.loading;
  RepeatingView? _view;
  RepeatingErrorCode? _errorCode;

  RepeatingState get state => _state;
  RepeatingView? get view => _view;
  RepeatingErrorCode? get errorCode => _errorCode;

  Future<void> load() async {
    _state = RepeatingState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _view = await gateway.loadRepeating();
      _state = RepeatingState.ready;
      notifyListeners();
    } on Object {
      _state = RepeatingState.failed;
      _errorCode = RepeatingErrorCode.loadFailed;
      notifyListeners();
    }
  }
}

/// X35.
final class RepeatingDetailController extends ChangeNotifier {
  RepeatingDetailController({required this.gateway, required this.scheduleId});

  final RepeatingGateway gateway;
  final String scheduleId;

  RepeatingState _state = RepeatingState.loading;
  RepeatingDetailView? _view;
  RepeatingErrorCode? _errorCode;

  RepeatingState get state => _state;
  RepeatingDetailView? get view => _view;
  RepeatingErrorCode? get errorCode => _errorCode;

  Future<void> load() async {
    _state = RepeatingState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _view = await gateway.loadSchedule(scheduleId);
      _state = _view == null ? RepeatingState.failed : RepeatingState.ready;
      if (_view == null) {
        _errorCode = RepeatingErrorCode.loadFailed;
      }
      notifyListeners();
    } on Object {
      _state = RepeatingState.failed;
      _errorCode = RepeatingErrorCode.loadFailed;
      notifyListeners();
    }
  }

  /// `StopSchedule` from today. Returns true when the command committed.
  Future<bool> stop() async {
    final view = _view;
    if (view == null) {
      return false;
    }
    try {
      final now = DateTime.now();
      await gateway.stopSchedule(
        view,
        lastDate: LocalDate(now.year, now.month, now.day),
      );
      await load();
      return true;
    } on Object {
      _errorCode = RepeatingErrorCode.stopFailed;
      notifyListeners();
      return false;
    }
  }
}

/// X84: rules and the category list.
final class RulesController extends ChangeNotifier {
  RulesController({required this.gateway});

  final RepeatingGateway gateway;

  RepeatingState _state = RepeatingState.loading;
  List<RuleView> _rules = const <RuleView>[];
  List<NamedOption> _categories = const <NamedOption>[];
  RepeatingErrorCode? _errorCode;

  RepeatingState get state => _state;
  List<RuleView> get rules => List<RuleView>.unmodifiable(_rules);
  List<NamedOption> get categories =>
      List<NamedOption>.unmodifiable(_categories);
  RepeatingErrorCode? get errorCode => _errorCode;

  Future<void> load() async {
    _state = RepeatingState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _rules = await gateway.loadRules();
      _categories = await gateway.categoryOptions();
      _state = RepeatingState.ready;
      notifyListeners();
    } on Object {
      _state = RepeatingState.failed;
      _errorCode = RepeatingErrorCode.loadFailed;
      notifyListeners();
    }
  }
}
