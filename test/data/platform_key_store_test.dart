import 'dart:convert';
import 'dart:typed_data';

import 'package:contour/data/keys/keys.dart';
import 'package:contour/data/keys/secure_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

// T08: the platform key store binding over a scripted secure-storage
// engine. Keychain/Keystore behaviour is device evidence (S06); these tests
// cover the preload, write-through and failure contracts on the host.

class _FakeStorageApi implements SecureStorageApi {
  final Map<String, String> values = <String, String>{};
  final Set<String> failingWrites = <String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failingWrites.contains(key)) {
      throw StateError('storage write failed');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

VaultKey keyOf(int seed) {
  final bytes = Uint8List(VaultKey.byteLength);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = (seed + i) & 0xff;
  }
  return VaultKey.fromBytes(bytes);
}

void main() {
  test('an empty store reports an absent key and epoch', () async {
    final store = await SecureKeyStore.load(_FakeStorageApi());
    expect(
      () => store.readKey(),
      throwsA(const KeyStoreError(KeyStoreErrorCode.absent)),
    );
    expect(
      () => store.readInstallEpoch(),
      throwsA(const KeyStoreError(KeyStoreErrorCode.absent)),
    );
  });

  test('write, flush and reload return the same key bytes', () async {
    final api = _FakeStorageApi();
    final store = await SecureKeyStore.load(api);
    final key = keyOf(7);
    store.writeKey(key);
    await store.flush();
    expect(api.values, isNotEmpty, reason: 'flush surfaces the write');

    final reloaded = await SecureKeyStore.load(api);
    final bytes = reloaded.readKey().bytes;
    expect(bytes, equals(key.bytes));
  });

  test('a pending write is durable after flush even with a slow engine',
      () async {
    final api = _FakeStorageApi();
    final store = await SecureKeyStore.load(api);
    store.writeKey(keyOf(11));
    // flush awaits every scheduled write, so the caller may treat the key
    // as stored when flush completes.
    await store.flush();
    expect(api.values.containsKey(SecureKeyStore.keyNameForTest), isTrue);
  });

  test('stored bytes that are not 32 key bytes fail closed', () async {
    final api = _FakeStorageApi();
    api.values[SecureKeyStore.keyNameForTest] = base64Encode(<int>[1, 2, 3]);
    expect(
      () => SecureKeyStore.load(api),
      throwsA(const KeyStoreError(KeyStoreErrorCode.unreadable)),
    );
  });

  test('stored bytes that are not base64 fail closed', () async {
    final api = _FakeStorageApi();
    api.values[SecureKeyStore.keyNameForTest] = 'not base64 !!';
    expect(
      () => SecureKeyStore.load(api),
      throwsA(const KeyStoreError(KeyStoreErrorCode.unreadable)),
    );
  });

  test('deleteKey removes the key durably after flush', () async {
    final api = _FakeStorageApi();
    final store = await SecureKeyStore.load(api);
    store.writeKey(keyOf(3));
    await store.flush();
    store.deleteKey();
    await store.flush();

    final reloaded = await SecureKeyStore.load(api);
    expect(
      () => reloaded.readKey(),
      throwsA(const KeyStoreError(KeyStoreErrorCode.absent)),
    );
  });

  test('the install epoch round-trips and rejects a corrupt value', () async {
    final api = _FakeStorageApi();
    final store = await SecureKeyStore.load(api);
    store.writeInstallEpoch(4);
    await store.flush();

    final reloaded = await SecureKeyStore.load(api);
    expect(reloaded.readInstallEpoch(), 4);

    api.values[SecureKeyStore.epochNameForTest] = 'not-a-number';
    expect(
      () => SecureKeyStore.load(api),
      throwsA(const KeyStoreError(KeyStoreErrorCode.unreadable)),
    );
  });

  test('a failed platform write surfaces through flush', () async {
    final api = _FakeStorageApi();
    api.failingWrites.add(SecureKeyStore.keyNameForTest);
    final store = await SecureKeyStore.load(api);
    store.writeKey(keyOf(9));
    expect(
      store.flush(),
      throwsA(isA<StateError>()),
    );
  });
}
