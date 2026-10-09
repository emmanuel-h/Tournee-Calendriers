import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';

/// Where a member of a tournée stands (PLAN §5.2, §8.1).
enum MemberStatus {
  /// « En attente »: asked to join with the code, can read and write
  /// nothing until an active member accepts.
  pending,

  /// Accepted (or the creator): sees and marks the whole tournée.
  active,
}

/// A firefighter in a tournée, or someone asking to join it (PLAN §2): an
/// entity of the `Tournee` aggregate, changed only through its root.
///
/// Its [status] follows from [acceptance], so a member can never be active
/// without someone having let them in, nor pending with an acceptance.
final class Member {
  /// A member as it is stored: pending while [acceptance] is null.
  ///
  /// A newcomer's request is `Member(id: uid, name: …, requestedAt: now)`;
  /// the tournée's root accepts it.
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
  /// when the tournée was created.
  final DateTime requestedAt;

  /// Who accepted them and when; the creator accepted themself when
  /// creating the tournée. Null while the request is pending.
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
