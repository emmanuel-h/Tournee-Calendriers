import 'dart:math';

import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';

/// Why stored members cannot make a [Tournee].
enum NewTourneeFailure {
  /// The creator is not among the members, or is only pending: a tournée
  /// always has its creator, active.
  creatorNotActive,

  /// Two members have the same id.
  duplicateMember,
}

/// Why a command on a [Tournee] was refused. The screens only offer each
/// command to whom may run it (PLAN §5.8), so most of these mean the team
/// changed in the meantime (« vous avez été retiré »).
enum TourneeCommandFailure {
  /// The one acting is not in the tournée: never joined, removed, or left.
  notAMember,

  /// The one acting is still waiting to be accepted: they can do nothing
  /// but cancel their request (`leave`).
  requestPending,

  /// Only the creator removes members, regenerates the code and deletes
  /// the tournée.
  notCreator,

  /// The member acted on is not in the tournée (any more).
  unknownMember,

  /// The request to accept or refuse has already been accepted.
  alreadyActive,

  /// The member to remove is a pending request: refuse it instead.
  memberPending,

  /// The creator can neither be removed nor leave: the tournée would have
  /// nobody to run it. They delete it instead.
  creatorStays,
}

/// A team's round (« Tournée 49 · CS Villefranche », PLAN §2): the
/// aggregate root that guards who is in the team and who may do what
/// (PLAN §6.1, §8).
///
/// Invariants, true of every `Tournee`:
/// - exactly one creator, [createdBy], always an active member;
/// - each member appears once, pending or active ([Member.status]);
/// - [members] are sorted by request time, then by id.
///
/// Permissions (each command returns a [TourneeCommandFailure] otherwise):
///
/// | command                    | creator | active | pending      | outsider |
/// |----------------------------|---------|--------|--------------|----------|
/// | [accept], [refuse]         | yes     | yes    | no           | no       |
/// | [remove]                   | yes     | no     | no           | no       |
/// | [leave]                    | no      | yes    | yes (cancel) | no       |
/// | [regenerateCode], [delete] | yes     | no     | no           | no       |
///
/// A `Tournee` is immutable. Each command returns a new tournée together
/// with the [TourneeChange] it made, as a Dart record `(Tournee, Change)`;
/// storage writes only that change.
final class Tournee {
  Tournee._({
    required this.id,
    required this.number,
    required this.centre,
    required this.joinCode,
    required this.createdBy,
    required this.createdAt,
    required this.currentCampaign,
    required Iterable<Member> members,
  }) : members = List.unmodifiable(members.toList()..sort(_byRequest));

  /// A new tournée, created by [creator] at [at] (« Créer », PLAN §5.2):
  /// they are its only member, active, accepted by themself.
  ///
  /// It cannot fail: every value is already valid. Whether number + centre
  /// is free is for storage to tell, as only it knows the other tournées.
  factory Tournee.createdBy({
    required TourneeId id,
    required TourneeNumber number,
    required RescueCentre centre,
    required CampaignYear campaign,
    required JoinCode joinCode,
    required MemberId creator,
    required MemberName creatorName,
    required DateTime at,
  }) => Tournee._(
    id: id,
    number: number,
    centre: centre,
    joinCode: joinCode,
    createdBy: creator,
    createdAt: at,
    currentCampaign: campaign,
    members: [
      Member(
        id: creator,
        name: creatorName,
        requestedAt: at,
        acceptance: ChangeStamp(by: creator, at: at),
      ),
    ],
  );

  /// Rebuilds a stored tournée with its [members], given in any order.
  ///
  /// Fails with [NewTourneeFailure.duplicateMember] when two members share
  /// an id, and with [NewTourneeFailure.creatorNotActive] when the creator
  /// is missing or pending.
  static Result<Tournee, NewTourneeFailure> create({
    required TourneeId id,
    required TourneeNumber number,
    required RescueCentre centre,
    required JoinCode joinCode,
    required MemberId createdBy,
    required DateTime createdAt,
    required CampaignYear currentCampaign,
    required Iterable<Member> members,
  }) {
    final ids = <MemberId>{};
    for (final member in members) {
      // `Set.add` answers false when the id was already in the set.
      if (!ids.add(member.id)) {
        return const Err(NewTourneeFailure.duplicateMember);
      }
    }
    final creator = members.where((member) => member.id == createdBy);
    if (creator.isEmpty || !creator.single.isActive) {
      return const Err(NewTourneeFailure.creatorNotActive);
    }
    return Ok(
      Tournee._(
        id: id,
        number: number,
        centre: centre,
        joinCode: joinCode,
        createdBy: createdBy,
        createdAt: createdAt,
        currentCampaign: currentCampaign,
        members: members,
      ),
    );
  }

  final TourneeId id;
  final TourneeNumber number;
  final RescueCentre centre;

  /// The secret to ask to join; changed by [regenerateCode].
  final JoinCode joinCode;

  /// The member who created the tournée: the only one who removes members,
  /// regenerates the code and deletes it.
  final MemberId createdBy;

  final DateTime createdAt;

  /// The year whose streets and statuses everyone works on (PLAN §5.10).
  final CampaignYear currentCampaign;

  /// Everyone in the tournée, pending requests included, by request time.
  /// The list cannot be modified (it throws an `UnsupportedError`): members
  /// change only through the commands below.
  final List<Member> members;

  /// The creator, always an active member.
  Member get creator => memberOf(createdBy)!;

  /// The requests waiting for an answer (« En attente », PLAN §5.8).
  List<Member> get pendingMembers =>
      List.unmodifiable(members.where((member) => !member.isActive));

  /// The accepted members, the creator included (« Membres »).
  List<Member> get activeMembers =>
      List.unmodifiable(members.where((member) => member.isActive));

  /// The member [id], pending or active; null when not in the tournée.
  Member? memberOf(MemberId id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// Whether [id] is the creator.
  bool isCreator(MemberId id) => id == createdBy;

  /// Lets the pending [member] in, as [by] at [at] (« Accepter »). Any
  /// active member may: nobody has to wait for the creator.
  Result<(Tournee, MemberAccepted), TourneeCommandFailure> accept(
    MemberId member, {
    required MemberId by,
    required DateTime at,
  }) {
    if (_activeActor(by) case final failure?) return Err(failure);
    final request = memberOf(member);
    if (request == null) return const Err(TourneeCommandFailure.unknownMember);
    if (request.isActive) return const Err(TourneeCommandFailure.alreadyActive);
    final accepted = Member(
      id: request.id,
      name: request.name,
      requestedAt: request.requestedAt,
      acceptance: ChangeStamp(by: by, at: at),
    );
    return Ok((
      _withMembers([
        for (final other in members)
          if (other.id == member) accepted else other,
      ]),
      MemberAccepted(tourneeId: id, member: accepted),
    ));
  }

  /// Turns down the pending request of [member], as [by] (« Refuser »).
  /// Any active member may.
  Result<(Tournee, MemberRefused), TourneeCommandFailure> refuse(
    MemberId member, {
    required MemberId by,
  }) {
    if (_activeActor(by) case final failure?) return Err(failure);
    final request = memberOf(member);
    if (request == null) return const Err(TourneeCommandFailure.unknownMember);
    if (request.isActive) return const Err(TourneeCommandFailure.alreadyActive);
    return Ok((
      _without(member),
      MemberRefused(tourneeId: id, member: request),
    ));
  }

  /// Takes the active [member] out of the tournée, as [by] (« Retirer »).
  /// Only the creator may; combined with [regenerateCode] when the code
  /// has leaked (PLAN §5.8).
  Result<(Tournee, MemberRemoved), TourneeCommandFailure> remove(
    MemberId member, {
    required MemberId by,
  }) {
    if (_creatorActor(by) case final failure?) return Err(failure);
    final removed = memberOf(member);
    if (removed == null) return const Err(TourneeCommandFailure.unknownMember);
    if (isCreator(member)) return const Err(TourneeCommandFailure.creatorStays);
    if (!removed.isActive) {
      return const Err(TourneeCommandFailure.memberPending);
    }
    return Ok((
      _without(member),
      MemberRemoved(tourneeId: id, member: removed),
    ));
  }

  /// Takes [by] out of the tournée (« Quitter la tournée »), or cancels
  /// their request when still pending (« Annuler la demande »). The creator
  /// cannot leave: they delete the tournée.
  Result<(Tournee, MemberLeft), TourneeCommandFailure> leave({
    required MemberId by,
  }) {
    final leaving = memberOf(by);
    if (leaving == null) return const Err(TourneeCommandFailure.notAMember);
    if (isCreator(by)) return const Err(TourneeCommandFailure.creatorStays);
    return Ok((_without(by), MemberLeft(tourneeId: id, member: leaving)));
  }

  /// Replaces the join code by a new one drawn from [random], as [by]
  /// (« Nouveau code »). Only the creator may. The new code always differs
  /// from the old one, which stops working; the members stay.
  Result<(Tournee, JoinCodeRegenerated), TourneeCommandFailure> regenerateCode({
    required MemberId by,
    required Random random,
  }) {
    if (_creatorActor(by) case final failure?) return Err(failure);
    JoinCode code;
    // One draw in 887 million gives the same code again: draw once more,
    // or the old code would keep working.
    do {
      code = JoinCode.generate(random);
    } while (code == joinCode);
    return Ok((
      Tournee._(
        id: id,
        number: number,
        centre: centre,
        joinCode: code,
        createdBy: createdBy,
        createdAt: createdAt,
        currentCampaign: currentCampaign,
        members: members,
      ),
      JoinCodeRegenerated(tourneeId: id, before: joinCode, code: code),
    ));
  }

  /// Deletes the tournée, as [by] (« Supprimer la tournée »). Only the
  /// creator may. Nothing is left to return but the deletion itself.
  Result<TourneeDeleted, TourneeCommandFailure> delete({required MemberId by}) {
    if (_creatorActor(by) case final failure?) return Err(failure);
    return Ok(TourneeDeleted(this));
  }

  /// Why [by] may not act for the team, or null when they are an active
  /// member.
  TourneeCommandFailure? _activeActor(MemberId by) {
    final actor = memberOf(by);
    if (actor == null) return TourneeCommandFailure.notAMember;
    if (!actor.isActive) return TourneeCommandFailure.requestPending;
    return null;
  }

  /// Why [by] may not run a creator's command, or null when they are the
  /// creator.
  TourneeCommandFailure? _creatorActor(MemberId by) {
    final failure = _activeActor(by);
    if (failure != null) return failure;
    if (!isCreator(by)) return TourneeCommandFailure.notCreator;
    return null;
  }

  Tournee _without(MemberId member) =>
      _withMembers(members.where((other) => other.id != member));

  Tournee _withMembers(Iterable<Member> newMembers) => Tournee._(
    id: id,
    number: number,
    centre: centre,
    joinCode: joinCode,
    createdBy: createdBy,
    createdAt: createdAt,
    currentCampaign: currentCampaign,
    members: newMembers,
  );

  /// Oldest request first; the id breaks ties so the order never depends
  /// on the order storage gave.
  static int _byRequest(Member a, Member b) {
    final byTime = a.requestedAt.compareTo(b.requestedAt);
    return byTime != 0 ? byTime : a.id.value.compareTo(b.id.value);
  }

  @override
  String toString() =>
      'Tournee(${id.value}, ${number.value}, ${centre.name}, '
      '${currentCampaign.value})';
}
