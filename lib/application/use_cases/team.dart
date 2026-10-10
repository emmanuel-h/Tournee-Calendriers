import 'dart:math';

import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';

// Équipe (PLAN §5.8): who is in the open tournée, the requests to answer,
// the join code, and leaving or deleting the tournée. The member acting is
// the one on the phone (`IdentityProvider`), whom the tournée's root checks
// may do it. Accepting, refusing, removing and leaving work offline (queued
// by storage); a new code and deleting need the server.

/// Why a command of Équipe was not done.
///
/// `sealed`: these are the only cases, so the screen's `switch` handles
/// each one.
sealed class TeamFailure {
  const TeamFailure();
}

/// The tournée cannot be read any more: deleted, or the member was
/// removed from it.
final class TourneeGone extends TeamFailure {
  const TourneeGone();

  @override
  bool operator ==(Object other) => other is TourneeGone;

  @override
  int get hashCode => (TourneeGone).hashCode;

  @override
  String toString() => 'TourneeGone';
}

/// The tournée refused the command for [reason]: the team changed in the
/// meantime (the request was already answered, the member already left),
/// since the screen offers each command only to whom may run it.
final class TeamCommandRefused extends TeamFailure {
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

/// The command needs the server and the phone could not reach it
/// (« Nouveau code », « Supprimer la tournée »). Nothing was changed.
final class TeamOffline extends TeamFailure {
  const TeamOffline();

  @override
  bool operator ==(Object other) => other is TeamOffline;

  @override
  int get hashCode => (TeamOffline).hashCode;

  @override
  String toString() => 'TeamOffline';
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
  if (tournee == null) return const Err(TourneeGone());
  switch (command(tournee)) {
    case Err(:final failure):
      return Err(TeamCommandRefused(failure));
    case Ok(value: (final changed, final change)):
      return switch (await tournees.save(changed, change)) {
        Ok(:final value) => Ok((value, change)),
        Err(failure: TourneeWriteFailure.noNetwork) => const Err(TeamOffline()),
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

/// The member using the phone: Équipe shows « (vous) » next to them and
/// offers the creator's commands only to the creator.
final class ReadCurrentMember {
  const ReadCurrentMember(this._identity);

  final IdentityProvider _identity;

  MemberId call() => _identity.currentMember;
}

/// « Accepter » a request: the newcomer joins the team, accepted by the
/// member on the phone, now. Works offline.
final class AcceptMember {
  const AcceptMember(this._tournees, this._clock, this._identity);

  final TourneeRepository _tournees;
  final Clock _clock;
  final IdentityProvider _identity;

  Future<Result<MemberAccepted, TeamFailure>> call(
    TourneeId tournee,
    MemberId member,
  ) async {
    final by = _identity.currentMember;
    final at = _clock.now();
    return switch (await _runOnTournee(
      _tournees,
      tournee,
      (tournee) => tournee.accept(member, by: by, at: at),
    )) {
      Ok(value: (_, final change)) => Ok(change),
      Err(:final failure) => Err(failure),
    };
  }
}

/// « Refuser » a request: it is taken out. Works offline.
final class RefuseMember {
  const RefuseMember(this._tournees, this._identity);

  final TourneeRepository _tournees;
  final IdentityProvider _identity;

  Future<Result<MemberRefused, TeamFailure>> call(
    TourneeId tournee,
    MemberId member,
  ) async {
    final by = _identity.currentMember;
    return switch (await _runOnTournee(
      _tournees,
      tournee,
      (tournee) => tournee.refuse(member, by: by),
    )) {
      Ok(value: (_, final change)) => Ok(change),
      Err(:final failure) => Err(failure),
    };
  }
}

/// « Retirer » a member (the creator only): their access is cut at once,
/// their marks stay. Works offline.
final class RemoveMember {
  const RemoveMember(this._tournees, this._identity);

  final TourneeRepository _tournees;
  final IdentityProvider _identity;

  Future<Result<MemberRemoved, TeamFailure>> call(
    TourneeId tournee,
    MemberId member,
  ) async {
    final by = _identity.currentMember;
    return switch (await _runOnTournee(
      _tournees,
      tournee,
      (tournee) => tournee.remove(member, by: by),
    )) {
      Ok(value: (_, final change)) => Ok(change),
      Err(:final failure) => Err(failure),
    };
  }
}

/// « Quitter la tournée »: the member on the phone leaves the team, and the
/// phone forgets the tournée (« Mes tournées »). Works offline; the creator
/// cannot leave (they delete the tournée instead).
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

/// « Nouveau code » (the creator only): the old code stops working, the
/// members stay. Returns the code as stored. Needs the server, which makes
/// sure no other tournée holds the new one.
final class RegenerateJoinCode {
  /// [random] draws the code: `Random.secure()` in the app (PLAN §5.2), a
  /// scripted one in tests.
  const RegenerateJoinCode(this._tournees, this._identity, this._random);

  final TourneeRepository _tournees;
  final IdentityProvider _identity;
  final Random _random;

  Future<Result<JoinCode, TeamFailure>> call(TourneeId tournee) async {
    final by = _identity.currentMember;
    return switch (await _runOnTournee(
      _tournees,
      tournee,
      (tournee) => tournee.regenerateCode(by: by, random: _random),
    )) {
      Ok(value: (final stored, _)) => Ok(stored.joinCode),
      Err(:final failure) => Err(failure),
    };
  }
}

/// « Supprimer la tournée » (the creator only): the tournée and all it
/// holds are deleted for the whole team, and the phone forgets it. Needs
/// the server.
final class DeleteTournee {
  const DeleteTournee(this._tournees, this._identity, this._myTournees);

  final TourneeRepository _tournees;
  final IdentityProvider _identity;
  final MyTourneesStore _myTournees;

  Future<Result<TourneeDeleted, TeamFailure>> call(TourneeId id) async {
    final tournee = await _tournees.find(id);
    if (tournee == null) return const Err(TourneeGone());
    switch (tournee.delete(by: _identity.currentMember)) {
      case Err(:final failure):
        return Err(TeamCommandRefused(failure));
      case Ok(value: final deletion):
        switch (await _tournees.delete(deletion)) {
          case Err(failure: TourneeWriteFailure.noNetwork):
            return const Err(TeamOffline());
          case Ok():
            await _myTournees.save(_myTournees.myTournees.forget(id));
            return Ok(deletion);
        }
    }
  }
}
