import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

/// The streets each member of a tournée covers, as Équipe lists them under
/// each member (« Léa · 3 rues », PLAN §5.8). A member covers a street when
/// they are among its `Street.assignees`, as for « Mes rues » (see
/// `MyStreets`).
///
/// Équipe lists only the members still in the team, so a street held by
/// someone who left simply belongs to no row there (see `TeamRoster`).
/// Streets in the Corbeille are left out.
final class StreetsByMember {
  const StreetsByMember._(this._streets);

  /// No street at all: before the streets are read, or once they can no
  /// longer be.
  static const none = StreetsByMember._({});

  /// The streets of [streets] per member, each list in the order of
  /// [streets].
  factory StreetsByMember.of(Iterable<Street> streets) {
    final byMember = <MemberId, List<StreetName>>{};
    for (final street in streets) {
      if (street.isDeleted) continue;
      for (final member in street.assignees) {
        // `putIfAbsent` gives the member's list, made empty the first time.
        byMember.putIfAbsent(member, () => []).add(street.name);
      }
    }
    return StreetsByMember._({
      for (final MapEntry(key: member, value: names) in byMember.entries)
        member: List.unmodifiable(names),
    });
  }

  final Map<MemberId, List<StreetName>> _streets;

  /// The names of the streets [member] covers; empty when none. The list
  /// cannot be modified.
  List<StreetName> streetsOf(MemberId member) => _streets[member] ?? const [];
}
