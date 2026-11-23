// P3-20 (flow F06 step 2): the secure PDF password vault for the import
// feature. Plaintext never leaves the store; the key is a hash of the scope.
library;

import '../data/keys/secure_key_store.dart';
import '../data/repositories/import_secrets.dart';
import '../features/import/import_models.dart';

/// The production vault over the platform secure store.
final class SecureImportPasswordVault implements ImportPasswordVault {
  SecureImportPasswordVault({SecureStorageApi? api})
      : _store = SecureImportPasswordStore(api ?? SecureStorageApiImpl());

  final SecureImportPasswordStore _store;

  @override
  Future<String?> read(String scope) => _store.read(scope);

  @override
  Future<void> save(String scope, String password) =>
      _store.save(scope, password);

  @override
  Future<void> clear(String scope) => _store.clear(scope);
}
