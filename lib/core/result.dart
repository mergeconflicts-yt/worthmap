/// SPEC 9 / SYSTEM_DESIGN 3: a typed failure carries a message key and, at
/// most, a safe field name. It never holds an amount, a name, a file's content
/// or other personal data (AGENTS 2.6).
final class DomainError {
  const DomainError(this.key, {this.field});

  /// An l10n message key.
  final String key;

  /// An optional safe field name, never a value.
  final String? field;

  @override
  String toString() =>
      field == null ? 'DomainError($key)' : 'DomainError($key, field: $field)';
}

/// A typed success or failure. Failure carries a [DomainError].
sealed class Result<T> {
  const Result();

  bool get isOk;
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool get isOk => true;
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final DomainError error;

  @override
  bool get isOk => false;
}
