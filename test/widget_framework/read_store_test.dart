import 'package:contour/app/widgets/read_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const key = MetricKey('home.availableUntil');

  test('observeResident misses before a publish and after an evict', () {
    final store = InMemoryReadStore();
    expect(store.observeResident(key), isNull);

    store.publish(
      const MetricValue(
        key: key,
        state: MetricState.value,
        revision: 1,
        value: 'value',
      ),
    );
    expect(store.observeResident(key)?.state, MetricState.value);

    store.evict(key);
    expect(store.observeResident(key), isNull);
  });

  test('acquire and release are reference counted', () {
    final store = InMemoryReadStore();
    expect(store.subscriberCount(key), 0);
    store.acquire(key);
    store.acquire(key);
    expect(store.subscriberCount(key), 2);
    store.release(key);
    expect(store.subscriberCount(key), 1);
    store.release(key);
    expect(store.subscriberCount(key), 0);
  });

  test('MetricKey equality uses the canonical id', () {
    expect(const MetricKey('a'), const MetricKey('a'));
    expect(const MetricKey('a'), isNot(const MetricKey('b')));
  });
}
