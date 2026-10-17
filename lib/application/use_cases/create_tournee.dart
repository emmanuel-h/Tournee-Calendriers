import 'dart:math';

import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

// « Nouvelle tournée » (PLAN §5.2): the centres de secours to pick from,
// the check that number + centre is free, and the creation itself. All of
// it needs the network: only the server knows the other tournées.

/// The centres de secours already known to the app, by name, for the
/// creator to pick from. Fails with [DirectoryFailure.noNetwork] offline.
final class ListRescueCentres {
  const ListRescueCentres(this._directory);

  final TourneeDirectory _directory;

  Future<Result<List<RescueCentre>, DirectoryFailure>> call() =>
      _directory.rescueCentres();
}

/// Whether the tournée [TourneeNumber] of [RescueCentre] already exists,
/// asked while the creator types (« La tournée 49 du CS Villefranche
/// existe déjà »). Fails with [DirectoryFailure.noNetwork] offline.
final class CheckTourneeTaken {
  const CheckTourneeTaken(this._directory);

  final TourneeDirectory _directory;

  Future<Result<bool, DirectoryFailure>> call(
    RescueCentre centre,
    TourneeNumber number,
  ) => _directory.isTaken(centre, number);
}

/// Why « Créer » made no tournée.
enum CreateTourneeFailure {
  /// The number is already taken in that centre de secours, perhaps by
  /// someone who created it at the same second: ask its creator for the
  /// code.
  alreadyExists,

  /// The phone could not reach the server, for the sign-in or the
  /// creation.
  noNetwork,

  /// The server refused: the member is no longer an admin, though the
  /// phone still showed « Créer » (« Vous n'êtes plus administrateur. »).
  notAdmin,
}

/// « Créer »: signs in when the phone has no account yet, then stores a new
/// tournée whose only member is the creator, with a join code drawn from
/// the secure source, and opens it on the phone (« Mes tournées », PLAN
/// §5.3). Returns the tournée as stored: the server may have replaced a
/// code another tournée held.
final class CreateTournee {
  const CreateTournee(
    this._tournees,
    this._account,
    this._myTournees,
    this._clock,
    this._ids,
    this._random,
  );

  final TourneeRepository _tournees;
  final MemberAccount _account;
  final MyTourneesStore _myTournees;
  final Clock _clock;
  final IdGenerator _ids;

  /// `Random.secure()` in the app: a code drawn from the plain `Random()`
  /// could be predicted (PLAN §5.2).
  final Random _random;

  Future<Result<Tournee, CreateTourneeFailure>> call({
    required RescueCentre centre,
    required TourneeNumber number,
    required CampaignYear campaign,
    required MemberName creatorName,
  }) async {
    // The server lets in the account's uid only (PLAN §8.2): the phone's
    // own id cannot stand in for it here.
    final MemberId creator;
    switch (await _account.signInIfNeeded()) {
      case Ok(:final value):
        creator = value;
      case Err(:final failure):
        return Err(switch (failure) {
          SignInFailure.noNetwork => CreateTourneeFailure.noNetwork,
        });
    }
    final tournee = Tournee.createdBy(
      id: TourneeId(_ids.newId()),
      number: number,
      centre: centre,
      campaign: campaign,
      joinCode: JoinCode.generate(_random),
      creator: creator,
      creatorName: creatorName,
      at: _clock.now(),
    );
    switch (await _tournees.add(tournee)) {
      case Err(:final failure):
        return Err(switch (failure) {
          AddTourneeFailure.alreadyExists => CreateTourneeFailure.alreadyExists,
          AddTourneeFailure.noNetwork => CreateTourneeFailure.noNetwork,
          AddTourneeFailure.notAdmin => CreateTourneeFailure.notAdmin,
        });
      case Ok(value: final stored):
        await _open(stored);
        return Ok(stored);
    }
  }

  /// Keeps [tournee] among the member's and opens it: the app shows it now
  /// and at the next launch.
  Future<void> _open(Tournee tournee) async {
    var mine = _myTournees.myTournees.remember(
      TourneeSummary(
        id: tournee.id,
        number: tournee.number,
        centre: tournee.centre,
        campaign: tournee.currentCampaign,
        status: MemberStatus.active,
      ),
    );
    // Always opens: the creator is an active member of what they created.
    if (mine.open(tournee.id) case Ok(:final value)) mine = value;
    await _myTournees.save(mine);
  }
}
