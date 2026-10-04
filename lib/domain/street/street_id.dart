import 'package:tournee_calendriers/domain/shared/identifier.dart';

/// The identity of a [Street] in its tournée, made by the app (a generated
/// id on the phone, the Firestore document id from M2).
///
/// A class of its own rather than a `String`, so a street id cannot be
/// passed where a BAN id or a member id is expected.
final class StreetId {
  /// Throws an [ArgumentError] when [value] is blank: ids come from adapters,
  /// so a blank one is a bug, not a user error.
  StreetId(String value) : value = requireNotBlank(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) => other is StreetId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StreetId($value)';
}

/// The identity of a street in the national address base (BAN), such as
/// `69264_0420`. A street typed in by hand has none.
final class BanStreetId {
  /// Throws an [ArgumentError] when [value] is blank: it comes from the BAN
  /// adapter, so a blank one is a bug, not a user error.
  BanStreetId(String value) : value = requireNotBlank(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is BanStreetId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BanStreetId($value)';
}
