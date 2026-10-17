/// The outcome of an operation that can fail in a way the user can act on:
/// either an [Ok] holding a value of type [T], or an [Err] holding a failure
/// of type [F].
///
/// Returning a `Result` instead of throwing makes the failure part of the
/// method's type, so the caller cannot forget it. `sealed` means [Ok] and
/// [Err] are the only two kinds, so a `switch` must handle both, and Dart 3
/// patterns read the content in the same step:
///
/// ```dart
/// switch (HouseNumber.parse(text)) {
///   case Ok(:final value):
///     // `value` is a HouseNumber
///   case Err(:final failure):
///     // `failure` is a HouseNumberFailure: tell the user what is wrong
/// }
/// ```
///
/// A failure type is an `enum` when its cases carry no data (each value
/// object's failures), and a `sealed class` when some case needs data.
/// Either way the `switch` over it is exhaustive: no `default`, so a new case
/// breaks the build wherever it must be handled.
sealed class Result<T, F> {
  const Result();

  /// This result with [transform] applied to its value; a failure is kept
  /// as it is. Spares the `switch` that only passes the failure on:
  /// `run().map((pair) => pair.$2)`.
  Result<U, F> map<U>(U Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final failure) => Err(failure),
  };

  /// This result with [transform] applied to its failure; a value is kept
  /// as it is. For a caller that words the failure its own way.
  Result<T, G> mapFailure<G>(G Function(F failure) transform) => switch (this) {
    Ok(:final value) => Ok(value),
    Err(:final failure) => Err(transform(failure)),
  };
}

/// A successful [Result] holding [value].
final class Ok<T, F> extends Result<T, F> {
  const Ok(this.value);

  final T value;
}

/// A failed [Result] holding [failure], which says what went wrong.
final class Err<T, F> extends Result<T, F> {
  const Err(this.failure);

  final F failure;
}
