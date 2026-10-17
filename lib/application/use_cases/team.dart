import 'dart:math';

import 'package:tournee_calendriers/application/ports/admin_status.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/actor.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';

// Équipe (PLAN §5.8, §5.12): who is in the open tournée, the requests to
// answer, the join code, and leaving or deleting the tournée. The member
// acting is the one on the phone (`IdentityProvider`), with whether they
// are an admin (`AdminStatus`): the tournée's root checks they may do it.
// Accepting, refusing, removing and leaving work offline (queued by
// storage); a new code, an admin joining and deleting need the server.

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
  tourneeGone,

  /// The command needs the server and the phone could not reach it
  /// (« Nouveau code », « Supprimer la tournée »). Nothing was changed.
  offline,

  /// The phone has no first name to give the team: « Rejoindre » as an
  /// admin needs one (PLAN §5.12). Nothing was changed.
  noName,

  /// The server refused an admin's command (« Nouveau code », « Supprimer
  /// la tournée », « Rejoindre » as an admin): the member on the phone is
  /// no longer an admin, though the phone still believed it. Nothing was
  /// changed.
  notAdmin,
}

/// The tournée refused the command for [reason]: the team changed in the
/// meantime (the request was already answered, the member already left),
/// since the screen offers each command only to whom may run it.
final class TeamCommandRefused implements TeamFailure {
  const TeamCommandRefused(this.reason);

  final TourneeCommandFailure reason;

  @override
  bool operator ==(Object other) =>
      other is TeamCommandRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'TeamCommandRefused($reason)';
}

/// What [failure] of the storage means for Équipe.
TeamFailure _teamFailureOf(TourneeWriteFailure failure) => switch (failure) {
  TourneeWriteFailure.noNetwork => TeamProblem.offline,
  TourneeWriteFailure.notAdmin => TeamProblem.notAdmin,
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
/// [command] is a function the use case passes in (`(tournee) =>
/// tournee.accept(…)`), so the loading and storing are written once.
Future<Result<(Tournee, C), TeamFailure>>
_runOnTournee<C extends TourneeChange>(
  TourneeRepository tournees,
  TourneeId id,
  Result<(Tournee, C), TourneeCommandFailure> Function(Tournee tournee) command,
) async {
  final tournee = await tournees.find(id);
  if (tournee == null) return const Err(TeamProblem.tourneeGone);
  switch (command(tournee)) {
    case Err(:final failure):
      return Err(TeamCommandRefused(failure));
    case Ok(value: (final changed, final change)):
      return switch (await tournees.save(changed, change)) {
        Ok(:final value) => Ok((value, change)),
        Err(:final failure) => Err(_teamFailureOf(failure)),
      };
  }
}

/// The tournée [TourneeId] now, then again after each change to it or to
/// its team (a request arrives, a teammate accepts it); null while it
/// cannot be read (deleted, the member removed, or never seen offline).
final class ObserveTeam {
  const ObserveTeam(this._tournees);

  final TourneeRepository _tournees;

  Stream<Tournee?> call(TourneeId id) => _tournees.watch(id);
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
  const AcceptMember(this._tournees, this._clock, this._identity, this._admins);

  final TourneeRepository _tournees;
  final Clock _clock;
  final IdentityProvider _identity;
  final AdminStatus _admins;

  Future<Result<MemberAccepted, TeamFailure>> call(
    TourneeId tournee,
    MemberId member,
  ) async {
    final by = await _actorOf(_identity, _admins);
    final at = _clock.now();
    return (await _runOnTournee(
      _tournees,
      tournee,
      (tournee) => tournee.accept(member, by: by, at: at),
    )).map((stored) => stored.$2);
  }
}

/// « Refuser » a request: it is taken out. Works offline.
final class RefuseMember {
  const RefuseMember(this._tournees, this._identity, this._admins);

  final TourneeRepository _tournees;
  final IdentityProvider _identity;
  final AdminStatus _admins;

  Future<Result<MemberRefused, TeamFailure>> call(
    TourneeId tournee,
    MemberId member,
  ) async {
    final by = await _actorOf(_identity, _admins);
    return (await _runOnTournee(
      _tournees,
      tournee,
      (tournee) => tournee.refuse(member, by: by),
    )).map((stored) => stored.$2);
  }
}

/// « Retirer » a member (admins only): their access is cut at once, their
/// marks stay. Works offline.
final class RemoveMember {
  const RemoveMember(this._tournees, this._identity, this._admins);

  final TourneeRepository _tournees;
  final IdentityProvider _identity;
  final AdminStatus _admins;

  Future<Result<MemberRemoved, TeamFailure>> call(
    TourneeId tournee,
    MemberId member,
  ) async {
    final by = await _actorOf(_identity, _admins);
    return (await _runOnTournee(
      _tournees,
      tournee,
      (tournee) => tournee.remove(member, by: by),
    )).map((stored) => stored.$2);
  }
}

/// « Quitter la tournée »: the member on the phone leaves the team, and the
/// phone forgets the tournée (« Mes tournées »). Works offline; every
/// member may leave, admins and the creator included, even the last one.
final class LeaveTournee {
  const LeaveTournee(this._tournees, this._identity, this._myTournees);

  final TourneeRepository _tournees;
  final IdentityProvider _identity;
  final MyTourneesStore _myTournees;

  Future<Result<MemberLeft, TeamFailure>> call(TourneeId tournee) async {
    final by = _identity.currentMember;
    switch (await _runOnTournee(
      _tournees,
      tournee,
      (tournee) => tournee.leave(by: by),
    )) {
      case Ok(value: (_, final change)):
        await _myTournees.save(_myTournees.myTournees.forget(tournee));
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
    this._tournees,
    this._identity,
    this._admins,
    this._random,
  );

  final TourneeRepository _tournees;
  final IdentityProvider _identity;
  final AdminStatus _admins;
  final Random _random;

  Future<Result<JoinCode, TeamFailure>> call(TourneeId tournee) async {
    final by = await _actorOf(_identity, _admins);
    return (await _runOnTournee(
      _tournees,
      tournee,
      (tournee) => tournee.regenerateCode(by: by, random: _random),
    )).map((stored) => stored.$1.joinCode);
  }
}

/// « Supprimer la tournée » (admins only): the tournée and all it holds
/// are deleted for the whole team, and the phone forgets it. Needs the
/// server.
final class DeleteTournee {
  const DeleteTournee(
    this._tournees,
    this._identity,
    this._admins,
    this._myTournees,
  );

  final TourneeRepository _tournees;
  final IdentityProvider _identity;
  final AdminStatus _admins;
  final MyTourneesStore _myTournees;

  Future<Result<TourneeDeleted, TeamFailure>> call(TourneeId id) async {
    final tournee = await _tournees.find(id);
    if (tournee == null) return const Err(TeamProblem.tourneeGone);
    switch (tournee.delete(by: await _actorOf(_identity, _admins))) {
      case Err(:final failure):
        return Err(TeamCommandRefused(failure));
      case Ok(value: final deletion):
        switch (await _tournees.delete(deletion)) {
          case Err(:final failure):
            return Err(_teamFailureOf(failure));
          case Ok():
            await _myTournees.save(_myTournees.myTournees.forget(id));
            return Ok(deletion);
        }
    }
  }
}

/// « Rejoindre » on the banner « Administrateur · pas membre » (PLAN
/// §5.12): the admin on the phone, who only visited the tournée, becomes
/// an active member at once under the phone's first name (no code, no
/// approval), and the tournée becomes one of theirs on the phone. Needs
/// the server: offline nothing changes.
final class JoinAsAdmin {
  const JoinAsAdmin(
    this._tournees,
    this._identity,
    this._admins,
    this._clock,
    this._settings,
    this._myTournees,
  );

  final TourneeRepository _tournees;
  final IdentityProvider _identity;
  final AdminStatus _admins;
  final Clock _clock;
  final PhoneSettings _settings;
  final MyTourneesStore _myTournees;

  Future<Result<AdminJoined, TeamFailure>> call(TourneeId id) async {
    final name = _settings.memberName;
    if (name == null) return const Err(TeamProblem.noName);
    final by = await _actorOf(_identity, _admins);
    final at = _clock.now();
    switch (await _runOnTournee(
      _tournees,
      id,
      (tournee) => tournee.joinAsAdmin(by: by, name: name, at: at),
    )) {
      case Ok(value: (_, final change)):
        final mine = _myTournees.myTournees;
        // Forgotten meanwhile (another screen removed it): nothing to keep.
        if (mine.find(id) case final visited?) {
          await _myTournees.save(mine.remember(visited.accepted()));
        }
        return Ok(change);
      case Err(:final failure):
        return Err(failure);
    }
  }
}

/// « Retirer de Mes tournées » (PLAN §5.12): an admin who only visited the
/// tournée forgets it on the phone. Nothing is written: they were never in
/// its team. Works offline.
final class ForgetVisitedTournee {
  const ForgetVisitedTournee(this._myTournees);

  final MyTourneesStore _myTournees;

  Future<void> call(TourneeId id) =>
      _myTournees.save(_myTournees.myTournees.forget(id));
}
