import 'package:contour/core/result.dart';
import 'package:flutter_test/flutter_test.dart';

// T02 — Result and safe DomainError. SYSTEM_DESIGN 3: failures are typed with
// message keys and safe field references, never values or content.
// Tests first (AGENTS 2.8).
void main() {
  test('Ok carries a value through an exhaustive switch', () {
    const Result<int> result = Ok<int>(42);
    final value = switch (result) {
      Ok<int>(:final value) => value,
      Err<int>() => -1,
    };
    expect(value, 42);
    expect(result.isOk, true);
  });

  test('Err carries only a safe domain error key', () {
    const Result<int> result = Err<int>(
      DomainError('money.currencyMismatch', field: 'currency'),
    );
    final key = switch (result) {
      Ok<int>() => 'ok',
      Err<int>(:final error) => error.key,
    };
    expect(key, 'money.currencyMismatch');
    expect(result.isOk, false);
  });

  test('a domain error never holds a value, only a key and a field name', () {
    const error = DomainError('money.currencyMismatch', field: 'currency');
    expect(error.key, 'money.currencyMismatch');
    expect(error.field, 'currency');
    expect(error.toString(), contains('money.currencyMismatch'));
  });
}
