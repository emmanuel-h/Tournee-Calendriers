import 'dart:math';

import 'package:tournee_calendriers/domain/sector/actor.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why stored members cannot make a [Sector].
enum NewSectorFailure {
  /// Two members have the same id.
  duplicateMember,

  /// Two communes have the same INSEE code.
  duplicateCommune,

  /// More than [Sector.maxCommunes] communes.
  tooManyCommunes,
}

/// Why a command on a [Sector] was refused. The screens only offer each
/// command to whom may run it (PLAN §5.8, §5.12), so most of these mean the
/// team changed in the meantime (« vous avez été retiré »).
enum SectorCommandFailure {
  /// The one acting is not in the secteur (never joined, removed, or left)
  /// and is not an admin.
  notAMember,

  /// The one acting is still waiting to be accepted and is not an admin:
  /// they can do nothing but cancel their request (`leave`).
  requestPending,

  /// Only an admin removes members, regenerates the code, deletes the
  /// secteur and joins it without a code.
  notAdmin,

  /// The member acted on is not in the secteur (any more).
  unknownMember,

  /// The request to accept or refuse has already been accepted.
  alreadyActive,

  /// The member to remove is a pending request: refuse it instead.
  memberPending,

  /// The admin who asks to join is already in the secteur.
  alreadyMember,

  /// Another member of the secteur, pending or active, goes by the same
  /// name, case and accents ignored ([MemberName.key]): names are unique
  /// within a secteur (#148, PLAN §5.16).
  nameTaken,

  /// The commune to add is already one of the secteur's.
  communeAlreadyIn,

  /// The secteur has [Sector.maxCommunes] communes already.
  tooManyCommunes,

  /// The commune to remove is not one of the secteur's (any more).
  unknownCommune,

  /// The commune to remove is the secteur's last one: a secteur keeps at
  /// least one, which « Ajouter des rues » starts on.
  lastCommune,
}

/// A team's secteur (« Secteur 49 · CS Villefranche », PLAN §2): the
/// aggregate root that guards who is in the team and who may do what
/// (PLAN §6.1, §8).
///
/// Invariants, true of every `Sector`:
/// - each member appears once, pending or active ([Member.status]);
/// - no command gives a member a name another member holds
///   ([MemberName.key]); the server checks it too, against the members
///   this copy may not have seen yet (#148);
/// - [members] are sorted by request time, then by id;
/// - no two [communes] share an INSEE code, and there are at most
///   [Sector.maxCommunes]. A secteur created from #78 on has at least
///   one, and [removeCommune] never takes the last; one created before may
///   have none.
///
/// The creator ([createdBy]) has no power of their own (PLAN §5.12): the
/// app's admins run the secteur, member of it or not, and anyone may
/// leave, the creator and the last member included. Who acts comes as an
/// [Actor]: their id and whether they are an admin.
///
/// Permissions (each command returns a [SectorCommandFailure] otherwise):
///
/// | command                    | admin      | active | pending      | outsider |
/// |----------------------------|------------|--------|--------------|----------|
/// | [accept], [refuse]         | yes        | yes    | no           | no       |
/// | [remove]                   | yes        | no     | no           | no       |
/// | [leave]                    | if in it   | yes    | yes (cancel) | no       |
/// | [regenerateCode], [delete] | yes        | no     | no           | no       |
/// | [joinAsAdmin]              | if not in  | no     | no           | no       |
/// | [rename] (themself)        | if active  | yes    | no           | no       |
/// | [addCommune], [removeCommune] | yes     | yes    | no           | no       |
///
/// A `Sector` is immutable. Each command returns a new secteur together
/// with the [SectorChange] it made, as a Dart record `(Sector, Change)`;
/// storage writes only that change.
final class Sector {
  Sector._({
    required this.id,
    required this.number,
    required this.centre,
    required this.joinCode,
    required this.createdBy,
    required this.createdAt,
    required this.currentCampaign,
    required Iterable<Member> members,
    required Iterable<SectorCommune> communes,
  }) : members = List.unmodifiable(members.toList()..sort(_byRequest)),
       communes = List.unmodifiable(communes);

  /// The most communes a secteur may cover: far more than a team walks,
  /// and a bound the security rules check (PLAN §8.2).
  static const maxCommunes = 50;

  /// A new secteur, created by [creator] at [at] (« Créer », PLAN §5.2):
  /// they are its only member, active, accepted by themself. It covers
  /// [communes], in the order picked.
  ///
  /// Whether number + centre is free is for storage to tell, as only it
  /// knows the other secteurs. « Nouveau secteur » lets « Créer » be
  /// pressed only with one to [maxCommunes] different communes, so other
  /// [communes] are a bug: they throw an [ArgumentError].
  factory Sector.createdBy({
    required SectorId id,
    required SectorNumber number,
    required RescueCentre centre,
    required CampaignYear campaign,
    required JoinCode joinCode,
    required MemberId creator,
    required MemberName creatorName,
    required DateTime at,
    required List<SectorCommune> communes,
  }) {
    if (communes.isEmpty) {
      throw ArgumentError.value(communes, 'communes', 'No commune');
    }
    if (_communesFailure(communes) case final failure?) {
      throw ArgumentError.value(communes, 'communes', '$failure');
    }
    return Sector._(
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
      communes: communes,
    );
  }

  /// Rebuilds a stored secteur with its [members], given in any order,
  /// and its [communes], in their stored order. The creator may be gone,
  /// and the team empty: everyone may leave. A secteur created before #78
  /// has no commune.
  ///
  /// Fails with [NewSectorFailure.duplicateMember] when two members share
  /// an id, [NewSectorFailure.duplicateCommune] when two communes share
  /// an INSEE code, [NewSectorFailure.tooManyCommunes] beyond
  /// [maxCommunes].
  static Result<Sector, NewSectorFailure> create({
    required SectorId id,
    required SectorNumber number,
    required RescueCentre centre,
    required JoinCode joinCode,
    required MemberId createdBy,
    required DateTime createdAt,
    required CampaignYear currentCampaign,
    required Iterable<Member> members,
    List<SectorCommune> communes = const [],
  }) {
    final ids = <MemberId>{};
    for (final member in members) {
      // `Set.add` answers false when the id was already in the set.
      if (!ids.add(member.id)) {
        return const Err(NewSectorFailure.duplicateMember);
      }
    }
    if (_communesFailure(communes) case final failure?) return Err(failure);
    return Ok(
      Sector._(
        id: id,
        number: number,
        centre: centre,
        joinCode: joinCode,
        createdBy: createdBy,
        createdAt: createdAt,
        currentCampaign: currentCampaign,
        members: members,
        communes: communes,
      ),
    );
  }

  /// What is wrong with [communes] for a secteur, or null when nothing is.
  static NewSectorFailure? _communesFailure(List<SectorCommune> communes) {
    if (communes.length > maxCommunes) {
      return NewSectorFailure.tooManyCommunes;
    }
    final codes = {for (final commune in communes) commune.inseeCode};
    return codes.length < communes.length
        ? NewSectorFailure.duplicateCommune
        : null;
  }

  final SectorId id;
  final SectorNumber number;
  final RescueCentre centre;

  /// The secret to ask to join; changed by [regenerateCode].
  final JoinCode joinCode;

  /// The member who created the secteur (an admin at the time). Kept as
  /// information only: they may have left, and have no power of their own.
  final MemberId createdBy;

  final DateTime createdAt;

  /// The year whose streets and statuses everyone works on (PLAN §5.10).
  final CampaignYear currentCampaign;

  /// Everyone in the secteur, pending requests included, by request time.
  /// The list cannot be modified (it throws an `UnsupportedError`): members
  /// change only through the commands below.
  final List<Member> members;

  /// The communes the secteur covers, in the order they were added: the
  /// map of « Ajouter des rues » is centred on them and its list shows
  /// their streets (PLAN §5.4). Possibly none for a secteur created before
  /// they existed. The list cannot be modified: they change only through
  /// [addCommune] and [removeCommune].
  final List<SectorCommune> communes;

  /// The requests waiting for an answer (« En attente », PLAN §5.8).
  List<Member> get pendingMembers =>
      List.unmodifiable(members.where((member) => !member.isActive));

  /// The accepted members (« Membres »).
  List<Member> get activeMembers =>
      List.unmodifiable(members.where((member) => member.isActive));

  /// The member [id], pending or active; null when not in the secteur.
  Member? memberOf(MemberId id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// Lets the pending [member] in, as [by] at [at] (« Accepter »). Any
  /// active member or admin may: nobody has to wait for someone else.
  Result<(Sector, MemberAccepted), SectorCommandFailure> accept(
    MemberId member, {
    required Actor by,
    required DateTime at,
  }) {
    if (_teamActor(by) case final failure?) return Err(failure);
    final request = memberOf(member);
    if (request == null) return const Err(SectorCommandFailure.unknownMember);
    if (request.isActive) return const Err(SectorCommandFailure.alreadyActive);
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
      MemberAccepted(sectorId: id, member: accepted),
    ));
  }

  /// Turns down the pending request of [member], as [by] (« Refuser »).
  /// Any active member or admin may.
  Result<(Sector, MemberRefused), SectorCommandFailure> refuse(
    MemberId member, {
    required Actor by,
  }) {
    if (_teamActor(by) case final failure?) return Err(failure);
    final request = memberOf(member);
    if (request == null) return const Err(SectorCommandFailure.unknownMember);
    if (request.isActive) return const Err(SectorCommandFailure.alreadyActive);
    return Ok((_without(member), MemberRefused(sectorId: id, member: request)));
  }

  /// Takes the active [member] out of the secteur, as [by] (« Retirer »).
  /// Only an admin may, on any active member, admins and the creator
  /// included; combined with [regenerateCode] when the code has leaked
  /// (PLAN §5.8).
  Result<(Sector, MemberRemoved), SectorCommandFailure> remove(
    MemberId member, {
    required Actor by,
  }) {
    if (_adminActor(by) case final failure?) return Err(failure);
    final removed = memberOf(member);
    if (removed == null) return const Err(SectorCommandFailure.unknownMember);
    if (!removed.isActive) {
      return const Err(SectorCommandFailure.memberPending);
    }
    return Ok((_without(member), MemberRemoved(sectorId: id, member: removed)));
  }

  /// Takes [by] out of the secteur (« Quitter le secteur »), or cancels
  /// their request when still pending (« Annuler la demande »). Any member
  /// may, the creator and the last one included: an empty secteur stays,
  /// for the admins to manage (PLAN §5.12).
  Result<(Sector, MemberLeft), SectorCommandFailure> leave({
    required MemberId by,
  }) {
    final leaving = memberOf(by);
    if (leaving == null) return const Err(SectorCommandFailure.notAMember);
    return Ok((_without(by), MemberLeft(sectorId: id, member: leaving)));
  }

  /// Gives [by] the first name [name] in this secteur (« Prénom » in
  /// Paramètres, PLAN §5.9), so the team sees the new name. Any active
  /// member may, for themself only: there is no member parameter, so
  /// renaming someone else cannot even be asked. Refused when another
  /// member holds the name ([SectorCommandFailure.nameTaken]).
  Result<(Sector, MemberRenamed), SectorCommandFailure> rename(
    MemberName name, {
    required MemberId by,
  }) {
    if (_activeActor(by) case final failure?) return Err(failure);
    if (_isHeldByAnother(name, by)) {
      return const Err(SectorCommandFailure.nameTaken);
    }
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
      MemberRenamed(sectorId: id, member: renamed),
    ));
  }

  /// Replaces the join code by a new one drawn from [random], as [by]
  /// (« Nouveau code »). Only an admin may, member or not. The new code
  /// always differs from the old one, which stops working; the members
  /// stay.
  Result<(Sector, JoinCodeRegenerated), SectorCommandFailure> regenerateCode({
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
      JoinCodeRegenerated(sectorId: id, before: joinCode, code: code),
    ));
  }

  /// This secteur holding [code] as its join code, everything else kept.
  ///
  /// Not a command: it is the secteur as storage keeps it when the code
  /// drawn on the phone turned out to be another secteur's, and the server
  /// gave it another one (a code is unique across secteurs, which only the
  /// server can tell, `SectorRepository.add` and `save`).
  Sector withJoinCode(JoinCode code) => _copy(joinCode: code);

  /// Deletes the secteur, as [by] (« Supprimer le secteur »). Only an
  /// admin may, member or not. Nothing is left to return but the deletion
  /// itself.
  Result<SectorDeleted, SectorCommandFailure> delete({required Actor by}) {
    if (_adminActor(by) case final failure?) return Err(failure);
    return Ok(SectorDeleted(this));
  }

  /// Makes the admin [by], who is not in the secteur, an active member at
  /// once under [name] (« Rejoindre » of the banner « Administrateur · pas
  /// membre », PLAN §5.12): no code, no request to answer, accepted by
  /// themself at [at], as the creator was. Refused when a member holds
  /// [name] already ([SectorCommandFailure.nameTaken]).
  Result<(Sector, AdminJoined), SectorCommandFailure> joinAsAdmin({
    required Actor by,
    required MemberName name,
    required DateTime at,
  }) {
    if (!by.isAdmin) return const Err(SectorCommandFailure.notAdmin);
    if (memberOf(by.member) != null) {
      return const Err(SectorCommandFailure.alreadyMember);
    }
    if (_isHeldByAnother(name, by.member)) {
      return const Err(SectorCommandFailure.nameTaken);
    }
    final joined = Member(
      id: by.member,
      name: name,
      requestedAt: at,
      acceptance: ChangeStamp(by: by.member, at: at),
    );
    return Ok((
      _withMembers([...members, joined]),
      AdminJoined(sectorId: id, member: joined),
    ));
  }

  /// Adds [commune] after the secteur's others, as [by] (« + Ajouter une
  /// commune » in Équipe, PLAN §5.8). Any active member or admin may.
  /// Refused when the secteur already covers that commune (same INSEE
  /// code) or has [maxCommunes].
  Result<(Sector, CommuneAdded), SectorCommandFailure> addCommune(
    SectorCommune commune, {
    required Actor by,
  }) {
    if (_teamActor(by) case final failure?) return Err(failure);
    if (_communeOf(commune.inseeCode) != null) {
      return const Err(SectorCommandFailure.communeAlreadyIn);
    }
    if (communes.length >= maxCommunes) {
      return const Err(SectorCommandFailure.tooManyCommunes);
    }
    return Ok((
      _copy(communes: [...communes, commune]),
      CommuneAdded(sectorId: id, commune: commune),
    ));
  }

  /// Takes the commune [code] out of the secteur, as [by] (✕ in Équipe).
  /// Any active member or admin may; the streets already added from it
  /// stay. Never the last commune: « Ajouter des rues » needs one.
  Result<(Sector, CommuneRemoved), SectorCommandFailure> removeCommune(
    InseeCode code, {
    required Actor by,
  }) {
    if (_teamActor(by) case final failure?) return Err(failure);
    final removed = _communeOf(code);
    if (removed == null) {
      return const Err(SectorCommandFailure.unknownCommune);
    }
    if (communes.length == 1) {
      return const Err(SectorCommandFailure.lastCommune);
    }
    return Ok((
      _copy(communes: communes.where((commune) => commune != removed)),
      CommuneRemoved(sectorId: id, commune: removed),
    ));
  }

  /// The secteur's commune [code], or null when it has none of that code.
  SectorCommune? _communeOf(InseeCode code) {
    for (final commune in communes) {
      if (commune.inseeCode == code) return commune;
    }
    return null;
  }

  /// Whether a member other than [member] goes by [name] here, case and
  /// accents ignored.
  bool _isHeldByAnother(MemberName name, MemberId member) =>
      members.any((other) => other.id != member && other.name.key == name.key);

  /// Why [by] may not act for the team as a member, or null when they are
  /// an active one.
  SectorCommandFailure? _activeActor(MemberId by) {
    final actor = memberOf(by);
    if (actor == null) return SectorCommandFailure.notAMember;
    if (!actor.isActive) return SectorCommandFailure.requestPending;
    return null;
  }

  /// Why [by] may not answer a request, or null when they are an admin or
  /// an active member.
  SectorCommandFailure? _teamActor(Actor by) =>
      by.isAdmin ? null : _activeActor(by.member);

  /// Why [by] may not run an admin's command, or null when they are an
  /// admin. A non-admin hears first what keeps them from acting at all
  /// (not in the secteur, still pending), as before.
  SectorCommandFailure? _adminActor(Actor by) => by.isAdmin
      ? null
      : _activeActor(by.member) ?? SectorCommandFailure.notAdmin;

  Sector _without(MemberId member) =>
      _withMembers(members.where((other) => other.id != member));

  Sector _withMembers(Iterable<Member> newMembers) =>
      _copy(members: newMembers);

  /// This secteur with the given parts replaced, the others kept.
  Sector _copy({
    JoinCode? joinCode,
    Iterable<Member>? members,
    Iterable<SectorCommune>? communes,
  }) => Sector._(
    id: id,
    number: number,
    centre: centre,
    joinCode: joinCode ?? this.joinCode,
    createdBy: createdBy,
    createdAt: createdAt,
    currentCampaign: currentCampaign,
    members: members ?? this.members,
    communes: communes ?? this.communes,
  );

  /// Oldest request first; the id breaks ties so the order never depends
  /// on the order storage gave.
  static int _byRequest(Member a, Member b) {
    final byTime = a.requestedAt.compareTo(b.requestedAt);
    return byTime != 0 ? byTime : a.id.value.compareTo(b.id.value);
  }

  @override
  String toString() =>
      'Sector(${id.value}, ${number.value}, ${centre.name}, '
      '${currentCampaign.value})';
}
