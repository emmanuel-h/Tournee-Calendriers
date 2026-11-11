import 'dart:math';

import 'package:tournee_calendriers/application/ports/admin_status.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/phone_cache_reset.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/sector/actor.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_repository.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

// Équipe (PLAN §5.8, §5.12): who is in the open tournée, the requests to
// answer, the join code, its communes, and leaving or deleting the tournée. The member
// acting is the one on the phone (`IdentityProvider`), with whether they
// are an admin (`AdminStatus`): the tournée's root checks they may do it.
// Accepting, refusing, removing, leaving and changing the communes work
// offline (queued by storage); a new code, an admin joining and deleting
// need the server.

/// Why a command of Équipe was not done: one of the [TeamProblem]s, or
/// [TeamCommandRefused] with the tournée's reason.
///
/// `sealed`: these are the only cases, so the screen's `switch` handles
/// each one. An enum may implement a sealed class of its own library, so
/// the cases without data need no class each.
sealed class TeamFailure {}

/// The failures of Équipe that carry no data.
enum TeamProblem implements TeamFailure {
  /// The tournée cannot be read any more: deleted, or the member was
  /// removed from it.
  sectorGone,

  /// The command needs the server and the phone could not reach it
  /// (« Nouveau code », « Supprimer le secteur »). Nothing was changed.
  offline,

  /// The phone has no first name to give the team: « Rejoindre » as an
  /// admin needs one (PLAN §5.12). Nothing was changed.
  noName,

  /// The server refused an admin's command (« Nouveau code », « Supprimer
  /// la tournée », « Rejoindre » as an admin): the member on the phone is
  /// no longer an admin, though the phone still believed it. Nothing was
  /// changed.
  notAdmin,

  /// The server says a member of the tournée holds the phone's first name,
  /// case and accents ignored (« Rejoindre » as an admin, #148): names are
  /// unique within a secteur. Nothing was changed.
  nameTaken,
}

/// The tournée refused the command for [reason]: the team changed in the
/// meantime (the request was already answered, the member already left),
/// since the screen offers each command only to whom may run it.
final class TeamCommandRefused implements TeamFailure {
  const TeamCommandRefused(this.reason);

  final SectorCommandFailure reason;

  @override
  bool operator ==(Object other) =>
      other is TeamCommandRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'TeamCommandRefused($reason)';
}

/// What [failure] of the storage means for Équipe.
TeamFailure _teamFailureOf(SectorWriteFailure failure) => switch (failure) {
  SectorWriteFailure.noNetwork => TeamProblem.offline,
  SectorWriteFailure.notAdmin => TeamProblem.notAdmin,
  SectorWriteFailure.nameTaken => TeamProblem.nameTaken,
};

/// Who acts on the phone: the member, and whether they are an admin as
/// [admins] last knew it (false until known, so an admin's command is then
/// refused rather than sent to a server that would refuse it).
///
/// A status that cannot be read counts as not an admin too: the member's
/// own commands still run, and an admin's is refused with a reason the
/// screen words, instead of an error it cannot.
Future<Actor> _actorOf(IdentityProvider identity, AdminStatus admins) async {
  bool isAdmin;
  try {
    isAdmin = await admins.watchIsAdmin().first;
  } on Object {
    isAdmin = false;
  }
  return Actor(member: identity.currentMember, isAdmin: isAdmin);
}

/// The steps every command of Équipe shares: load the tournée [id], run
/// [command] on it, store the change it made, and return the tournée as
/// stored with the change.
///
/// [command] is a function the use case passes in (`(sector) =>
/// sector.accept(…)`), so the loading and storing are written once.
Future<Result<(Sector, C), TeamFailure>> _runOnSector<C extends SectorChange>(
  SectorRepository sectors,
  SectorId id,
  Result<(Sector, C), SectorCommandFailure> Function(Sector sector) command,
) async {
  final sector = await sectors.find(id);
  if (sector == null) return const Err(TeamProblem.sectorGone);
  switch (command(sector)) {
    case Err(:final failure):
      return Err(TeamCommandRefused(failure));
    case Ok(value: (final changed, final change)):
      return switch (await sectors.save(changed, change)) {
        Ok(:final value) => Ok((value, change)),
        Err(:final failure) => Err(_teamFailureOf(failure)),
      };
  }
}

/// The tournée [SectorId] now, then again after each change to it or to
/// its team (a request arrives, a teammate accepts it); null while it
/// cannot be read (deleted, the member removed, or never seen offline).
final class ObserveTeam {
  const ObserveTeam(this._sectors);

  final SectorRepository _sectors;

  Stream<Sector?> call(SectorId id) => _sectors.watch(id);
}

/// The communes of the tournée [SectorId] now, then again each time they
/// change (« Ajouter des rues » lists their streets, its map is centred on
/// them, PLAN §5.4); none while the tournée cannot be read, or when it
/// was created before the communes. Works offline, from the phone's copy.
///
/// A change of the team alone (a request, an acceptance) is not told: the
/// screens would list the same streets again for nothing.
final class ObserveSectorCommunes {
  const ObserveSectorCommunes(this._sectors);

  final SectorRepository _sectors;

  Stream<List<SectorCommune>> call(SectorId id) => _sectors
      .watch(id)
      .map((sector) => sector?.communes ?? const <SectorCommune>[])
      .distinct(sameItems);
}

/// The member using the phone: Équipe shows « (vous) » next to them.
final class ReadCurrentMember {
  const ReadCurrentMember(this._identity);

  final IdentityProvider _identity;

  MemberId call() => _identity.currentMember;
}

/// « Accepter » a request: the newcomer joins the team, accepted by the
/// member (or admin) on the phone, now. Works offline.
final class AcceptMember {
  const AcceptMember(this._sectors, this._clock, this._identity, this._admins);

  final SectorRepository _sectors;
  final Clock _clock;
  final IdentityProvider _identity;
  final AdminStatus _admins;

  Future<Result<MemberAccepted, TeamFailure>> call(
    SectorId sector,
    MemberId member,
  ) async {
    final by = await _actorOf(_identity, _admins);
    final at = _clock.now();
    return (await _runOnSector(
      _sectors,
      sector,
      (sector) => sector.accept(member, by: by, at: at),
    )).map((stored) => stored.$2);
  }
}

/// « Refuser » a request: it is taken out. Works offline.
final class RefuseMember {
  const RefuseMember(this._sectors, this._identity, this._admins);

  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final AdminStatus _admins;

  Future<Result<MemberRefused, TeamFailure>> call(
    SectorId sector,
    MemberId member,
  ) async {
    final by = await _actorOf(_identity, _admins);
    return (await _runOnSector(
      _sectors,
      sector,
      (sector) => sector.refuse(member, by: by),
    )).map((stored) => stored.$2);
  }
}

/// « Retirer » a member (admins only): their access is cut at once, their
/// marks stay, and the name they held in the tournée is free again (#148).
///
/// With « Changer aussi le code » ticked ([renewCode], #148, PLAN §5.16:
/// the member removed knows the code) it first does « Nouveau code »,
/// which needs the server: offline, or refused, nobody is taken out, so
/// the admin never believes the code changed when it did not. Without it,
/// it works offline.
final class RemoveMember {
  /// [random] draws the new code: `Random.secure()` in the app, a scripted
  /// one in tests.
  const RemoveMember(this._sectors, this._identity, this._admins, this._random);

  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final AdminStatus _admins;
  final Random _random;

  Future<Result<MemberRemoved, TeamFailure>> call(
    SectorId sector,
    MemberId member, {
    required bool renewCode,
  }) async {
    final by = await _actorOf(_identity, _admins);
    if (renewCode) {
      // Asked of the tournée first, without storing anything: no new code
      // for a removal it would refuse (the member left meanwhile).
      final current = await _sectors.find(sector);
      if (current == null) return const Err(TeamProblem.sectorGone);
      if (current.remove(member, by: by) case Err(:final failure)) {
        return Err(TeamCommandRefused(failure));
      }
      final renewed = await _runOnSector(
        _sectors,
        sector,
        (sector) => sector.regenerateCode(by: by, random: _random),
      );
      if (renewed case Err(:final failure)) return Err(failure);
    }
    return (await _runOnSector(
      _sectors,
      sector,
      (sector) => sector.remove(member, by: by),
    )).map((stored) => stored.$2);
  }
}

/// « + Ajouter une commune » (Équipe): the tournée covers [SectorCommune]
/// too. Any active member or admin may. Works offline (sent later); the
/// commune itself was found online (geo.api.gouv.fr).
final class AddCommune {
  const AddCommune(this._sectors, this._identity, this._admins);

  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final AdminStatus _admins;

  Future<Result<CommuneAdded, TeamFailure>> call(
    SectorId sector,
    SectorCommune commune,
  ) async {
    final by = await _actorOf(_identity, _admins);
    return (await _runOnSector(
      _sectors,
      sector,
      (sector) => sector.addCommune(commune, by: by),
    )).map((stored) => stored.$2);
  }
}

/// ✕ on a commune (Équipe): the tournée no longer covers it; the streets
/// added from it stay. Never the last one. Works offline.
final class RemoveCommune {
  const RemoveCommune(this._sectors, this._identity, this._admins);

  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final AdminStatus _admins;

  Future<Result<CommuneRemoved, TeamFailure>> call(
    SectorId sector,
    InseeCode commune,
  ) async {
    final by = await _actorOf(_identity, _admins);
    return (await _runOnSector(
      _sectors,
      sector,
      (sector) => sector.removeCommune(commune, by: by),
    )).map((stored) => stored.$2);
  }
}

/// « Quitter le secteur »: the member on the phone leaves the team, and the
/// phone forgets the tournée (« Mes secteurs »), its streets leaving the
/// phone's copy at the next start ([PhoneCacheReset]). Works offline; every
/// member may leave, admins and the creator included, even the last one.
final class LeaveSector {
  const LeaveSector(
    this._sectors,
    this._identity,
    this._mySectors,
    this._cache,
  );

  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final MySectorsStore _mySectors;
  final PhoneCacheReset _cache;

  Future<Result<MemberLeft, TeamFailure>> call(SectorId sector) async {
    final by = _identity.currentMember;
    switch (await _runOnSector(
      _sectors,
      sector,
      (sector) => sector.leave(by: by),
    )) {
      case Ok(value: (_, final change)):
        await _mySectors.save(_mySectors.mySectors.forget(sector));
        _cache.scheduleAtNextStart();
        return Ok(change);
      case Err(:final failure):
        return Err(failure);
    }
  }
}

/// « Nouveau code » (admins only): the old code stops working, the members
/// stay. Returns the code as stored. Needs the server, which makes sure no
/// other tournée holds the new one.
final class RegenerateJoinCode {
  /// [random] draws the code: `Random.secure()` in the app (PLAN §5.2), a
  /// scripted one in tests.
  const RegenerateJoinCode(
    this._sectors,
    this._identity,
    this._admins,
    this._random,
  );

  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final AdminStatus _admins;
  final Random _random;

  Future<Result<JoinCode, TeamFailure>> call(SectorId sector) async {
    final by = await _actorOf(_identity, _admins);
    return (await _runOnSector(
      _sectors,
      sector,
      (sector) => sector.regenerateCode(by: by, random: _random),
    )).map((stored) => stored.$1.joinCode);
  }
}

/// « Supprimer le secteur » (admins only): the tournée and all it holds
/// are deleted for the whole team, and the phone forgets it (its copy of
/// the streets too, at the next start: [PhoneCacheReset]). Needs the
/// server.
final class DeleteSector {
  const DeleteSector(
    this._sectors,
    this._identity,
    this._admins,
    this._mySectors,
    this._cache,
  );

  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final AdminStatus _admins;
  final MySectorsStore _mySectors;
  final PhoneCacheReset _cache;

  Future<Result<SectorDeleted, TeamFailure>> call(SectorId id) async {
    final sector = await _sectors.find(id);
    if (sector == null) return const Err(TeamProblem.sectorGone);
    switch (sector.delete(by: await _actorOf(_identity, _admins))) {
      case Err(:final failure):
        return Err(TeamCommandRefused(failure));
      case Ok(value: final deletion):
        switch (await _sectors.delete(deletion)) {
          case Err(:final failure):
            return Err(_teamFailureOf(failure));
          case Ok():
            await _mySectors.save(_mySectors.mySectors.forget(id));
            _cache.scheduleAtNextStart();
            return Ok(deletion);
        }
    }
  }
}

/// « Rejoindre » on the banner « Administrateur · pas membre » (PLAN
/// §5.12): the admin on the phone, who only visited the tournée, becomes
/// an active member at once under the phone's first name (no code, no
/// approval), and the tournée becomes one of theirs on the phone. Needs
/// the server: offline nothing changes. Refused, changing nothing, when a
/// member holds that name there (#148).
final class JoinAsAdmin {
  const JoinAsAdmin(
    this._sectors,
    this._identity,
    this._admins,
    this._clock,
    this._settings,
    this._mySectors,
  );

  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final AdminStatus _admins;
  final Clock _clock;
  final PhoneSettings _settings;
  final MySectorsStore _mySectors;

  Future<Result<AdminJoined, TeamFailure>> call(SectorId id) async {
    final name = _settings.memberName;
    if (name == null) return const Err(TeamProblem.noName);
    final by = await _actorOf(_identity, _admins);
    final at = _clock.now();
    switch (await _runOnSector(
      _sectors,
      id,
      (sector) => sector.joinAsAdmin(by: by, name: name, at: at),
    )) {
      case Ok(value: (_, final change)):
        final mine = _mySectors.mySectors;
        // Forgotten meanwhile (another screen removed it): nothing to keep.
        if (mine.find(id) case final visited?) {
          await _mySectors.save(
            mine.remember(visited.accepted().withMemberName(name)),
          );
        }
        return Ok(change);
      case Err(:final failure):
        return Err(failure);
    }
  }
}

/// « Retirer de Mes secteurs » (PLAN §5.12): an admin who only visited the
/// tournée forgets it on the phone. Nothing is written: they were never in
/// its team. Works offline.
final class ForgetVisitedSector {
  const ForgetVisitedSector(this._mySectors);

  final MySectorsStore _mySectors;

  Future<void> call(SectorId id) =>
      _mySectors.save(_mySectors.mySectors.forget(id));
}
