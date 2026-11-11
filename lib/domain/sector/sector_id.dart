import 'package:tournee_calendriers/domain/shared/identifier.dart';

/// The identity of a `Sector`, made by the app (the Firestore document id,
/// `sectors/{id}`, PLAN §6.2). It never changes, whatever the number, the
/// station or the code become.
///
/// A class of its own rather than a `String`, so a secteur id cannot be
/// passed where a street id or a member id is expected.
final class SectorId {
  /// Throws an [ArgumentError] when [value] is blank: ids come from adapters,
  /// so a blank one is a bug, not a user error.
  SectorId(String value) : value = requireNotBlank(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) => other is SectorId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SectorId($value)';
}
