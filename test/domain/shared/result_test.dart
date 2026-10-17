import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

void main() {
  String describe(Result<int, String> result) => switch (result) {
    Ok(:final value) => 'value $value',
    Err(:final failure) => 'failure $failure',
  };

  // The arguments are variables, not literals, so the results are built when
  // the test runs (a `const` would be built by the compiler instead).
  test('should carry its value when the operation succeeded', () {
    final value = int.parse('13');

    expect(describe(Ok(value)), 'value 13');
  });

  test('should carry its failure when the operation failed', () {
    final failure = 'trop long'.toUpperCase();

    expect(describe(Err(failure)), 'failure TROP LONG');
  });

  test('should transform the value and keep a failure when mapped', () {
    final value = int.parse('13');
    final failure = 'trop long'.toUpperCase();

    expect(describe(Ok<int, String>(value).map((v) => v + 1)), 'value 14');
    expect(
      describe(Err<int, String>(failure).map((v) => v + 1)),
      'failure TROP LONG',
    );
  });

  test('should transform the failure and keep a value when mapped', () {
    final value = int.parse('13');
    final failure = 'trop long'.toUpperCase();

    expect(
      describe(Err<int, String>(failure).mapFailure((f) => f.toLowerCase())),
      'failure trop long',
    );
    expect(
      describe(Ok<int, String>(value).mapFailure((f) => f.toLowerCase())),
      'value 13',
    );
  });
}
