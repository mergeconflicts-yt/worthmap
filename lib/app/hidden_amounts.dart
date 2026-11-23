// P20 (SPEC 4.9; DESIGN 4, 6.6): the app-level hidden-amount state.
//
// The state is presentation only. It changes no financial record, no
// projection and no stored value. It keeps one bit: whether amounts show as
// the mask. The port below makes the bit survive a restart; the default
// implementation keeps it in memory, and a file implementation is provided
// for the app composition (it holds one preference and never an amount).
//
// DESIGN 4: percentages, dates and counts stay visible. Charts keep their
// shape and hide their amount text (section 7).
library;

import 'dart:io';

import 'package:flutter/widgets.dart';

import '../design/format/hidden_amounts.dart';

/// The presentation preference port. It stores one bit and no financial data.
abstract interface class HiddenAmountsStore {
  /// The stored value, or null when nothing is stored yet.
  Future<bool?> read();

  /// Stores [hidden]. A failure keeps the in-memory state.
  Future<void> write(bool hidden);
}

/// T08 pattern: a small local file outside the financial generations. It holds
/// `hidden=true|false` and nothing else. The write is a temp file plus an
/// atomic same-directory rename, so a reader never sees a partial value.
final class FileHiddenAmountsStore implements HiddenAmountsStore {
  FileHiddenAmountsStore({required String directory})
      : _file = File('$directory/contour-hidden-amounts.preference'),
        _tempFile = File('$directory/contour-hidden-amounts.preference.tmp');

  static const String _key = 'hidden';

  final File _file;
  final File _tempFile;

  @override
  Future<bool?> read() async {
    if (!_file.existsSync()) {
      return null;
    }
    final text = await _file.readAsString();
    for (final line in text.split('\n')) {
      final separator = line.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      if (line.substring(0, separator) != _key) {
        continue;
      }
      return switch (line.substring(separator + 1).trim()) {
        'true' => true,
        'false' => false,
        _ => null,
      };
    }
    return null;
  }

  @override
  Future<void> write(bool hidden) async {
    await _tempFile.writeAsString('$_key=$hidden\n', flush: true);
    await _tempFile.rename(_file.path);
  }
}

/// The default store for a fresh installation: no file, no platform path.
final class MemoryHiddenAmountsStore implements HiddenAmountsStore {
  MemoryHiddenAmountsStore({bool? initial}) : _value = initial;

  bool? _value;

  @override
  Future<bool?> read() async => _value;

  @override
  Future<void> write(bool hidden) async => _value = hidden;
}

/// Holds the hidden-amount state and writes it through [store].
///
/// A component reads the scope that [HiddenAmountsHost] mounts; a screen never
/// reads this controller directly. The controller exposes an immutable value
/// and its side effect (the write) is the only method that changes it.
final class HiddenAmountsController extends ChangeNotifier {
  HiddenAmountsController({
    this.store,
    bool initial = false,
  }) : _hidden = initial;

  final HiddenAmountsStore? store;
  bool _hidden;

  bool get hidden => _hidden;

  /// Reads the stored bit. A missing bit keeps [initial]; an unreadable store
  /// keeps the current state and does not reveal amounts.
  Future<void> load() async {
    final store = this.store;
    if (store == null) {
      return;
    }
    bool? stored;
    try {
      stored = await store.read();
    } on Object {
      stored = null;
    }
    if (stored != null && stored != _hidden) {
      _hidden = stored;
      notifyListeners();
    }
  }

  /// Shows or masks every money component. The presentation changes; no data
  /// record changes (P20 acceptance).
  Future<void> setHidden(bool hidden) async {
    if (_hidden == hidden) {
      return;
    }
    _hidden = hidden;
    notifyListeners();
    final store = this.store;
    if (store == null) {
      return;
    }
    try {
      await store.write(hidden);
    } on Object {
      // A failed preference write keeps the state on this screen. The next
      // change tries again; amounts are never revealed because of the error.
    }
  }

  Future<void> toggle() => setHidden(!_hidden);
}

/// The controller scope, for the one visible Hide amounts control.
///
/// Screens read this only to toggle the presentation bit; components read
/// [HiddenAmountsScope] for the value.
class HiddenAmountsControllerScope
    extends InheritedNotifier<HiddenAmountsController> {
  const HiddenAmountsControllerScope({
    required HiddenAmountsController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static HiddenAmountsController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<HiddenAmountsControllerScope>()
      ?.notifier;

  static HiddenAmountsController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError('No HiddenAmountsControllerScope above this widget');
    }
    return controller;
  }
}

/// Mounts [controller] as the one hidden-amount scope for the app.
///
/// The scope sits above the router, so the state survives navigation and the
/// lock screen. A locked app still reads the same value.
class HiddenAmountsHost extends StatelessWidget {
  const HiddenAmountsHost({
    required this.controller,
    required this.child,
    super.key,
  });

  final HiddenAmountsController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) =>
          HiddenAmountsControllerScope(
        controller: controller,
        child: HiddenAmountsScope(
          hidden: controller.hidden,
          child: child!,
        ),
      ),
      child: child,
    );
  }
}
