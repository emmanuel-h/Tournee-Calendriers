import 'package:tournee_calendriers/domain/shared/identifier.dart';

/// The identity of a `Round`, made by the app when the tournée starts. Its
/// validated summary keeps it (the Firestore document id,
/// `rounds/{roundId}`, PLAN §6.2), so sending it twice still makes one.
final class RoundId {
  /// Throws an [ArgumentError] when [value] is blank: ids come from adapters,
  /// so a blank one is a bug, not a user error.
  RoundId(String value) : value = requireNotBlank(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) => other is RoundId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'RoundId($value)';
}
