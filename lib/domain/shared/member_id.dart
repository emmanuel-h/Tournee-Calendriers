import 'package:tournee_calendriers/domain/shared/identifier.dart';

/// Who made a change: a member of the tournée.
///
/// Opaque on purpose: it holds the member's Firebase uid, or, before the
/// phone's first sign-in, an id the phone generated for itself. The domain only
/// compares it, so the source can change without touching the domain.
final class MemberId {
  /// Throws an [ArgumentError] when [value] is blank: ids come from adapters,
  /// so a blank one is a bug, not a user error.
  MemberId(String value) : value = requireNotBlank(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) => other is MemberId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MemberId($value)';
}
