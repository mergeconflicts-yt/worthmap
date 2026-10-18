/// SYSTEM_DESIGN 8.3, widget-framework 3.1: the shared read-store interface.
///
/// One canonical metric identity gives one immutable value and state. A widget
/// reads this store, never its own query. The preview uses `observeResident`,
/// a cache-only peek that starts no work.
library;

import 'package:contour/design/format/value_presentation.dart';

/// SYSTEM_DESIGN 8.3: a canonical metric key. It excludes any placement,
/// host surface, screen or period filter that is not part of the financial
/// meaning.
final class MetricKey {
  const MetricKey(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is MetricKey && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MetricKey($id)';
}

/// SPEC 4.3: the state of a value. Unknown is never zero.
enum MetricState { loading, value, missing, noneRecorded, notAvailable }

/// SYSTEM_DESIGN 8.3: one immutable value, its state and its revision.
///
/// N-05: the value is a [ValueSpec], never an untyped object. `state` is the
/// store state (W3.4); it maps one-to-one onto the spec state: `value` onto
/// real, estimated, expected or oldPrice; `missing`, `noneRecorded` and
/// `notAvailable` onto the same-named spec; `loading` carries no spec.
final class MetricValue {
  const MetricValue({
    required this.key,
    required this.state,
    required this.revision,
    this.spec,
  }) : assert(
          (state == MetricState.loading) == (spec == null),
          'Only a loading value carries no spec',
        );

  final MetricKey key;
  final MetricState state;
  final int revision;
  final ValueSpec? spec;

  /// The presentation text for this value, or null while loading.
  ValuePresentation? get presentation =>
      spec == null ? null : formatValueState(spec!);
}

/// SYSTEM_DESIGN 8.3: the shared read store. `acquire` and `release` are
/// reference-counted by canonical key. `observeResident` is a cache-only peek.
abstract interface class SharedReadStore {
  /// A cache-only peek: only already resident values, never a refresh or a
  /// calculation. Returns null on a cache miss or eviction.
  MetricValue? observeResident(MetricKey key);

  /// Adds one consumer reference for [key].
  void acquire(MetricKey key);

  /// Removes one consumer reference for [key].
  void release(MetricKey key);

  /// The current consumer count for [key] (0 when none).
  int subscriberCount(MetricKey key);
}

/// A Phase 1 in-memory store for tests and the debug gallery. A release and a
/// publish are explicit; there is no network or database.
final class InMemoryReadStore implements SharedReadStore {
  final Map<String, MetricValue> _resident = <String, MetricValue>{};
  final Map<String, int> _counts = <String, int>{};

  /// Publishes an immutable [value] as resident. An admitted consumer or the
  /// writer does this; a preview never does.
  void publish(MetricValue value) {
    _resident[value.key.id] = value;
  }

  /// Removes a resident value (eviction). The next `observeResident` misses.
  void evict(MetricKey key) {
    _resident.remove(key.id);
  }

  @override
  MetricValue? observeResident(MetricKey key) => _resident[key.id];

  @override
  void acquire(MetricKey key) {
    _counts[key.id] = (_counts[key.id] ?? 0) + 1;
  }

  @override
  void release(MetricKey key) {
    final next = (_counts[key.id] ?? 0) - 1;
    if (next <= 0) {
      _counts.remove(key.id);
    } else {
      _counts[key.id] = next;
    }
  }

  @override
  int subscriberCount(MetricKey key) => _counts[key.id] ?? 0;
}
