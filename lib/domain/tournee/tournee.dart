import 'dart:math';

import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/actor.dart';
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
  /// Two members have the same id.
  duplicateMember,
}

/// Why a command on a [Tournee] was refused. The screens only offer each
/// command to whom may run it (PLAN §5.8, §5.12), so most of these mean the
/// team changed in the meantime (« vous avez été retiré »).
enum TourneeCommandFailure {
  /// The one acting is not in the tournée (never joined, removed, or left)
  /// and is not an admin.
  notAMember,

  /// The one acting is still waiting to be accepted and is not an admin:
  /// they can do nothing but cancel their request (`leave`).
  requestPending,

  /// Only an admin removes members, regenerates the code, deletes the
  /// tournée and joins it without a code.
  notAdmin,

  /// The member acted on is not in the tournée (any more).
  unknownMember,

  /// The request to accept or refuse has already been accepted.
  alreadyActive,

  /// The member to remove is a pending request: refuse it instead.
  memberPending,

  /// The admin who asks to join is already in the tournée.
  alreadyMember,
}

/// A team's round (« Tournée 49 · CS Villefranche », PLAN §2): the
/// aggregate root that guards who is in the team and who may do what
/// (PLAN §6.1, §8).
///
/// Invariants, true of every `Tournee`:
/// - each member appears once, pending or active ([Member.status]);
/// - [members] are sorted by request time, then by id.
///
/// The creator ([createdBy]) has no power of their own (PLAN §5.12): the
/// app's admins run the tournée, member of it or not, and anyone may
/// leave, the creator and the last member included. Who acts comes as an
/// [Actor]: their id and whether they are an admin.
///
/// Permissions (each command returns a [TourneeCommandFailure] otherwise):
///
/// | command                    | admin      | active | pending      | outsider |
/// |----------------------------|------------|--------|--------------|----------|
/// | [accept], [refuse]         | yes        | yes    | no           | no       |
/// | [remove]                   | yes        | no     | no           | no       |
/// | [leave]                    | if in it   | yes    | yes (cancel) | no       |
/// | [regenerateCode], [delete] | yes        | no     | no           | no       |
/// | [joinAsAdmin]              | if not in  | no     | no           | no       |
/// | [rename] (themself)        | if active  | yes    | no           | no       |
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
  /// The creator may be gone, and the team empty: everyone may leave.
  ///
  /// Fails with [NewTourneeFailure.duplicateMember] when two members share
  /// an id.
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

  /// The member who created the tournée (an admin at the time). Kept as
  /// information only: they may have left, and have no power of their own.
  final MemberId createdBy;

  final DateTime createdAt;

  /// The year whose streets and statuses everyone works on (PLAN §5.10).
  final CampaignYear currentCampaign;

  /// Everyone in the tournée, pending requests included, by request time.
  /// The list cannot be modified (it throws an `UnsupportedError`): members
  /// change only through the commands below.
  final List<Member> members;

  /// The requests waiting for an answer (« En attente », PLAN §5.8).
  List<Member> get pendingMembers =>
      List.unmodifiable(members.where((member) => !member.isActive));

  /// The accepted members (« Membres »).
  List<Member> get activeMembers =>
      List.unmodifiable(members.where((member) => member.isActive));

  /// The member [id], pending or active; null when not in the tournée.
  Member? memberOf(MemberId id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// Lets the pending [member] in, as [by] at [at] (« Accepter »). Any
  /// active member or admin may: nobody has to wait for someone else.
  Result<(Tournee, MemberAccepted), TourneeCommandFailure> accept(
    MemberId member, {
    required Actor by,
    required DateTime at,
  }) {
    if (_teamActor(by) case final failure?) return Err(failure);
    final request = memberOf(member);
    if (request == null) return const Err(TourneeCommandFailure.unknownMember);
    if (request.isActive) return const Err(TourneeCommandFailure.alreadyActive);
    final accepted = Member(
      id: request.id,
      name: request.name,
      requestedAt: request.requestedAt,
      acceptance: ChangeStamp(by: by.member, at: at),
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
  /// Any active member or admin may.
  Result<(Tournee, MemberRefused), TourneeCommandFailure> refuse(
    MemberId member, {
    required Actor by,
  }) {
    if (_teamActor(by) case final failure?) return Err(failure);
    final request = memberOf(member);
    if (request == null) return const Err(TourneeCommandFailure.unknownMember);
    if (request.isActive) return const Err(TourneeCommandFailure.alreadyActive);
    return Ok((
      _without(member),
      MemberRefused(tourneeId: id, member: request),
    ));
  }

  /// Takes the active [member] out of the tournée, as [by] (« Retirer »).
  /// Only an admin may, on any active member, admins and the creator
  /// included; combined with [regenerateCode] when the code has leaked
  /// (PLAN §5.8).
  Result<(Tournee, MemberRemoved), TourneeCommandFailure> remove(
    MemberId member, {
    required Actor by,
  }) {
    if (_adminActor(by) case final failure?) return Err(failure);
    final removed = memberOf(member);
    if (removed == null) return const Err(TourneeCommandFailure.unknownMember);
    if (!removed.isActive) {
      return const Err(TourneeCommandFailure.memberPending);
    }
    return Ok((
      _without(member),
      MemberRemoved(tourneeId: id, member: removed),
    ));
  }

  /// Takes [by] out of the tournée (« Quitter la tournée »), or cancels
  /// their request when still pending (« Annuler la demande »). Any member
  /// may, the creator and the last one included: an empty tournée stays,
  /// for the admins to manage (PLAN §5.12).
  Result<(Tournee, MemberLeft), TourneeCommandFailure> leave({
    required MemberId by,
  }) {
    final leaving = memberOf(by);
    if (leaving == null) return const Err(TourneeCommandFailure.notAMember);
    return Ok((_without(by), MemberLeft(tourneeId: id, member: leaving)));
  }

  /// Gives [by] the first name [name] in this tournée (« Prénom » in
  /// Paramètres, PLAN §5.9), so the team sees the new name. Any active
  /// member may, for themself only: there is no member parameter, so
  /// renaming someone else cannot even be asked.
  Result<(Tournee, MemberRenamed), TourneeCommandFailure> rename(
    MemberName name, {
    required MemberId by,
  }) {
    if (_activeActor(by) case final failure?) return Err(failure);
    // `!`: `_activeActor` just found [by] among the members.
    final before = memberOf(by)!;
    final renamed = Member(
      id: before.id,
      name: name,
      requestedAt: before.requestedAt,
      acceptance: before.acceptance,
    );
    return Ok((
      _withMembers([
        for (final other in members)
          if (other.id == by) renamed else other,
      ]),
      MemberRenamed(tourneeId: id, member: renamed),
    ));
  }

  /// Replaces the join code by a new one drawn from [random], as [by]
  /// (« Nouveau code »). Only an admin may, member or not. The new code
  /// always differs from the old one, which stops working; the members
  /// stay.
  Result<(Tournee, JoinCodeRegenerated), TourneeCommandFailure> regenerateCode({
    required Actor by,
    required Random random,
  }) {
    if (_adminActor(by) case final failure?) return Err(failure);
    JoinCode code;
    // One draw in 887 million gives the same code again: draw once more,
    // or the old code would keep working.
    do {
      code = JoinCode.generate(random);
    } while (code == joinCode);
    return Ok((
      withJoinCode(code),
      JoinCodeRegenerated(tourneeId: id, before: joinCode, code: code),
    ));
  }

  /// This tournée holding [code] as its join code, everything else kept.
  ///
  /// Not a command: it is the tournée as storage keeps it when the code
  /// drawn on the phone turned out to be another tournée's, and the server
  /// gave it another one (a code is unique across tournées, which only the
  /// server can tell, `TourneeRepository.add` and `save`).
  Tournee withJoinCode(JoinCode code) => Tournee._(
    id: id,
    number: number,
    centre: centre,
    joinCode: code,
    createdBy: createdBy,
    createdAt: createdAt,
    currentCampaign: currentCampaign,
    members: members,
  );

  /// Deletes the tournée, as [by] (« Supprimer la tournée »). Only an
  /// admin may, member or not. Nothing is left to return but the deletion
  /// itself.
  Result<TourneeDeleted, TourneeCommandFailure> delete({required Actor by}) {
    if (_adminActor(by) case final failure?) return Err(failure);
    return Ok(TourneeDeleted(this));
  }

  /// Makes the admin [by], who is not in the tournée, an active member at
  /// once under [name] (« Rejoindre » of the banner « Administrateur · pas
  /// membre », PLAN §5.12): no code, no request to answer, accepted by
  /// themself at [at], as the creator was.
  Result<(Tournee, AdminJoined), TourneeCommandFailure> joinAsAdmin({
    required Actor by,
    required MemberName name,
    required DateTime at,
  }) {
    if (!by.isAdmin) return const Err(TourneeCommandFailure.notAdmin);
    if (memberOf(by.member) != null) {
      return const Err(TourneeCommandFailure.alreadyMember);
    }
    final joined = Member(
      id: by.member,
      name: name,
      requestedAt: at,
      acceptance: ChangeStamp(by: by.member, at: at),
    );
    return Ok((
      _withMembers([...members, joined]),
      AdminJoined(tourneeId: id, member: joined),
    ));
  }

  /// Why [by] may not act for the team as a member, or null when they are
  /// an active one.
  TourneeCommandFailure? _activeActor(MemberId by) {
    final actor = memberOf(by);
    if (actor == null) return TourneeCommandFailure.notAMember;
    if (!actor.isActive) return TourneeCommandFailure.requestPending;
    return null;
  }

  /// Why [by] may not answer a request, or null when they are an admin or
  /// an active member.
  TourneeCommandFailure? _teamActor(Actor by) =>
      by.isAdmin ? null : _activeActor(by.member);

  /// Why [by] may not run an admin's command, or null when they are an
  /// admin. A non-admin hears first what keeps them from acting at all
  /// (not in the tournée, still pending), as before.
  TourneeCommandFailure? _adminActor(Actor by) => by.isAdmin
      ? null
      : _activeActor(by.member) ?? TourneeCommandFailure.notAdmin;

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
