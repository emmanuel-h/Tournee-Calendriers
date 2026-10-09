import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// What one command of a [Tournee] changed, returned next to the new
/// tournée.
///
/// Storage writes only what a change names (PLAN §6.2): accepting Julie
/// updates her document `tournees/{id}/members/{uid}`, never the whole
/// team, so two members accepting two requests at once do not overwrite
/// each other.
///
/// `sealed`: these classes are the only changes, so the adapter's `switch`
/// over a `TourneeChange` must handle each one, and a new change breaks the
/// build there until it is handled.
sealed class TourneeChange {
  const TourneeChange({required this.tourneeId});

  /// The tournée that changed.
  final TourneeId tourneeId;
}

/// A change that let a member in or took one out of the tournée.
sealed class MemberChange extends TourneeChange {
  const MemberChange({required super.tourneeId, required this.member});

  /// For [MemberAccepted], the member as accepted; otherwise the member as
  /// they were before leaving the tournée.
  final Member member;

  /// Equal when of the same kind and about the same member: the
  /// `runtimeType` check keeps a [MemberRemoved] from equalling a
  /// [MemberLeft] of the same member.
  @override
  bool operator ==(Object other) =>
      other is MemberChange &&
      other.runtimeType == runtimeType &&
      other.tourneeId == tourneeId &&
      other.member == member;

  @override
  int get hashCode => Object.hash(runtimeType, tourneeId, member);
}

/// An active member accepted the request of [member] (« Accepter », PLAN
/// §5.8): storage writes the member's status, `acceptedBy` and `acceptedAt`.
final class MemberAccepted extends MemberChange {
  const MemberAccepted({required super.tourneeId, required super.member});

  @override
  String toString() => 'MemberAccepted(${tourneeId.value}, $member)';
}

/// An active member refused the pending request of [member] (« Refuser »):
/// storage deletes the request.
final class MemberRefused extends MemberChange {
  const MemberRefused({required super.tourneeId, required super.member});

  @override
  String toString() => 'MemberRefused(${tourneeId.value}, $member)';
}

/// The creator removed [member] (« Retirer »): their access is cut at once,
/// their marks stay stamped with their name.
final class MemberRemoved extends MemberChange {
  const MemberRemoved({required super.tourneeId, required super.member});

  @override
  String toString() => 'MemberRemoved(${tourneeId.value}, $member)';
}

/// [member] left the tournée (« Quitter la tournée »), or cancelled their
/// own pending request (« Annuler la demande »).
final class MemberLeft extends MemberChange {
  const MemberLeft({required super.tourneeId, required super.member});

  @override
  String toString() => 'MemberLeft(${tourneeId.value}, $member)';
}

/// The creator replaced the join code [before] by [code] (« Nouveau
/// code »): the old code stops working, the members stay.
///
/// Storage writes the tournée's `joinCode`, removes `joinCodes/{before}`
/// and creates `joinCodes/{code}` with the preview the join screen shows.
final class JoinCodeRegenerated extends TourneeChange {
  const JoinCodeRegenerated({
    required super.tourneeId,
    required this.before,
    required this.code,
  });

  final JoinCode before;
  final JoinCode code;

  @override
  bool operator ==(Object other) =>
      other is JoinCodeRegenerated &&
      other.tourneeId == tourneeId &&
      other.before == before &&
      other.code == code;

  @override
  int get hashCode => Object.hash(tourneeId, before, code);

  @override
  String toString() =>
      'JoinCodeRegenerated(${tourneeId.value}, ${before.display} → '
      '${code.display})';
}

/// The creator deleted [tournee] (« Supprimer la tournée »): every member,
/// campaign and street goes, with the join code and the number + centre
/// reservation (PLAN §8.3: deleting the tournée deletes its data).
///
/// Not a [TourneeChange]: nothing is left to change afterwards. It carries
/// the whole tournée as it was, because storage needs its join code, its
/// centre and its number to free them.
final class TourneeDeleted {
  const TourneeDeleted(this.tournee);

  final Tournee tournee;

  @override
  String toString() => 'TourneeDeleted(${tournee.id.value})';
}
