import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';

/// Who still counts among the members who cover a street (#91): the
/// tournée's members, and the member on the phone.
///
/// A member removed with « Retirer », or gone with « Quitter la tournée »,
/// stays in the `assignees` of their streets: the security rules let a
/// member add or remove only themself. Their streets are « libre » again
/// for everyone else because every place that decides whether a street is
/// taken (the map's lines, the street card) reads its assignees through a
/// roster rather than straight from [Street.assignees].
///
/// A pending request counts too: whoever is in [Tournee.members] is still
/// in the tournée, and the card names them (« Faite par Julie »).
///
/// The member on the phone always counts as themself: an admin visiting a
/// tournée is no member of it (PLAN §5.12), yet the street they took is
/// theirs.
final class TeamRoster {
  const TeamRoster._(this._members, this._me);

  /// The roster of [team], seen by [me]. While [team] is null (not read
  /// yet: an offline cold start before the team was ever kept on the phone)
  /// it is [unknown], so streets never flash to « libre » and back.
  factory TeamRoster.of(Tournee? team, {required MemberId me}) =>
      switch (team) {
        null => unknown,
        final team => TeamRoster._({
          for (final member in team.members) member.id,
        }, me),
      };

  /// A team not read yet: every assignee counts, as stored.
  static const unknown = TeamRoster._(null, null);

  /// The members of the tournée; null when the team is unknown.
  final Set<MemberId>? _members;

  /// The member on the phone; null when the team is unknown.
  final MemberId? _me;

  /// The assignees of [street] who still cover it.
  Set<MemberId> assigneesOf(Street street) {
    final members = _members;
    if (members == null) return street.assignees;
    return {
      for (final assignee in street.assignees)
        if (assignee == _me || members.contains(assignee)) assignee,
    };
  }

  /// Whether someone still covers [street]; when not, it is « libre ».
  bool isTaken(Street street) => assigneesOf(street).isNotEmpty;
}
