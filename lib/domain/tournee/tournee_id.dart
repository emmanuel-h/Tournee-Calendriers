import 'package:tournee_calendriers/domain/shared/identifier.dart';

/// The identity of a `Tournee`, made by the app (the Firestore document id,
/// `tournees/{id}`, PLAN §6.2). It never changes, whatever the number, the
/// station or the code become.
///
/// A class of its own rather than a `String`, so a tournée id cannot be
/// passed where a street id or a member id is expected.
final class TourneeId {
  /// Throws an [ArgumentError] when [value] is blank: ids come from adapters,
  /// so a blank one is a bug, not a user error.
  TourneeId(String value) : value = requireNotBlank(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) => other is TourneeId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TourneeId($value)';
}
