// Helpers that open a `Result` in tests, so a test reads
// `expect(valueOf(HouseNumber.parse('12')).number, 12)` instead of a switch.
//
// `fail` (from package:test) returns `Never`: it throws a test failure, so the
// switch below still has a value of the right type on every branch.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// The value of [result], or a test failure naming the unexpected failure.
T valueOf<T, F>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected a value, got the failure $failure'),
};

/// The failure of [result], or a test failure naming the unexpected value.
F failureOf<T, F>(Result<T, F> result) => switch (result) {
  Ok(:final value) => fail('expected a failure, got the value $value'),
  Err(:final failure) => failure,
};
