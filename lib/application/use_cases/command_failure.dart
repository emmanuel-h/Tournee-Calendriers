/// Why a use case could not change a street: the street is not on the
/// phone, or the street refused the command for a [reason] of type [F]
/// (`HouseChangeFailure`, `NumberChangeFailure`…).
///
/// Generic over [F] so each use case says exactly which refusals it can
/// return, and the screen's `switch` handles those and no others. Each case
/// is phrased in French by the screen.
sealed class CommandFailure<F> {
  const CommandFailure();
}

/// No street has that id (it was never imported, or the id is stale).
final class StreetNotFound<F> extends CommandFailure<F> {
  const StreetNotFound();

  @override
  bool operator ==(Object other) => other is StreetNotFound<F>;

  @override
  int get hashCode => (StreetNotFound).hashCode;

  @override
  String toString() => 'StreetNotFound';
}

/// The street refused the command, for [reason].
final class CommandRefused<F> extends CommandFailure<F> {
  const CommandRefused(this.reason);

  final F reason;

  @override
  bool operator ==(Object other) =>
      other is CommandRefused<F> && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'CommandRefused($reason)';
}
