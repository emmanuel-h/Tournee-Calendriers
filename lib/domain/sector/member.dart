import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// Where a member of a secteur stands (PLAN §5.2, §8.1).
enum MemberStatus {
  /// « En attente »: asked to join with the code, can read and write
  /// nothing until an active member accepts.
  pending,

  /// Accepted (or the creator): sees and marks the whole secteur.
  active,

  /// Not in the secteur at all, but an admin who opened it (« Tous les
  /// secteurs », PLAN §5.12): sees and marks it as a member does. Only a
  /// `SectorSummary` of the phone is ever visiting; a [Member] is pending
  /// or active.
  visiting,
}

/// A firefighter in a secteur, or someone asking to join it (PLAN §2): an
/// entity of the `Sector` aggregate, changed only through its root.
///
/// Its [status] follows from [acceptance], so a member can never be active
/// without someone having let them in, nor pending with an acceptance.
final class Member {
  /// A member as it is stored: pending while [acceptance] is null.
  ///
  /// A newcomer's request is made by `JoinRequest`, the one place outside
  /// the secteur's root that builds a member; the root accepts it.
  const Member({
    required this.id,
    required this.name,
    required this.requestedAt,
    this.acceptance,
  });

  /// The member's uid (PLAN §8.3).
  final MemberId id;

  /// The first name the member gave, shown to the team.
  final MemberName name;

  /// When they asked to join (« il y a 2 min » in Équipe); for the creator,
  /// when the secteur was created.
  final DateTime requestedAt;

  /// Who accepted them and when; the creator accepted themself when
  /// creating the secteur. Null while the request is pending.
  final ChangeStamp? acceptance;

  MemberStatus get status =>
      acceptance == null ? MemberStatus.pending : MemberStatus.active;

  /// Whether the member has been accepted.
  bool get isActive => status == MemberStatus.active;

  @override
  bool operator ==(Object other) =>
      other is Member &&
      other.id == id &&
      other.name == name &&
      other.requestedAt == requestedAt &&
      other.acceptance == acceptance;

  @override
  int get hashCode => Object.hash(id, name, requestedAt, acceptance);

  @override
  String toString() => 'Member(${id.value}, ${name.text}, ${status.name})';
}
