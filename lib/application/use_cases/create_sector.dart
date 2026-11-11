import 'dart:math';

import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/sector/sector_repository.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

// « Nouveau secteur » (PLAN §5.2): the centres de secours to pick from,
// the check that number + centre is free, and the creation itself. All of
// it needs the network: only the server knows the other tournées.

/// The centres de secours already known to the app, by name, for the
/// creator to pick from. Fails with [DirectoryFailure.noNetwork] offline.
final class ListRescueCentres {
  const ListRescueCentres(this._directory);

  final SectorDirectory _directory;

  Future<Result<List<RescueCentre>, DirectoryFailure>> call() =>
      _directory.rescueCentres();
}

/// Whether the tournée [SectorNumber] of [RescueCentre] already exists,
/// asked while the creator types (« La tournée 49 du CS Villefranche
/// existe déjà »). Fails with [DirectoryFailure.noNetwork] offline.
final class CheckSectorTaken {
  const CheckSectorTaken(this._directory);

  final SectorDirectory _directory;

  Future<Result<bool, DirectoryFailure>> call(
    RescueCentre centre,
    SectorNumber number,
  ) => _directory.isTaken(centre, number);
}

/// Why « Créer » made no tournée.
enum CreateSectorFailure {
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
/// tournée whose only member is the creator, covering the communes
/// picked, with a join code drawn from the secure source, and opens it on
/// the phone (« Mes secteurs », PLAN
/// §5.3). Returns the tournée as stored: the server may have replaced a
/// code another tournée held.
final class CreateSector {
  const CreateSector(
    this._sectors,
    this._account,
    this._mySectors,
    this._clock,
    this._ids,
    this._random,
  );

  final SectorRepository _sectors;
  final MemberAccount _account;
  final MySectorsStore _mySectors;
  final Clock _clock;
  final IdGenerator _ids;

  /// `Random.secure()` in the app: a code drawn from the plain `Random()`
  /// could be predicted (PLAN §5.2).
  final Random _random;

  Future<Result<Sector, CreateSectorFailure>> call({
    required RescueCentre centre,
    required SectorNumber number,
    required CampaignYear campaign,
    required MemberName creatorName,
    required List<SectorCommune> communes,
  }) async {
    // The server lets in the account's uid only (PLAN §8.2): the phone's
    // own id cannot stand in for it here.
    final MemberId creator;
    switch (await _account.signInIfNeeded()) {
      case Ok(:final value):
        creator = value;
      case Err(:final failure):
        return Err(switch (failure) {
          SignInFailure.noNetwork => CreateSectorFailure.noNetwork,
        });
    }
    final sector = Sector.createdBy(
      id: SectorId(_ids.newId()),
      number: number,
      centre: centre,
      campaign: campaign,
      joinCode: JoinCode.generate(_random),
      creator: creator,
      creatorName: creatorName,
      at: _clock.now(),
      communes: communes,
    );
    switch (await _sectors.add(sector)) {
      case Err(:final failure):
        return Err(switch (failure) {
          AddSectorFailure.alreadyExists => CreateSectorFailure.alreadyExists,
          AddSectorFailure.noNetwork => CreateSectorFailure.noNetwork,
          AddSectorFailure.notAdmin => CreateSectorFailure.notAdmin,
        });
      case Ok(value: final stored):
        await _open(stored);
        return Ok(stored);
    }
  }

  /// Keeps [sector] among the member's and opens it: the app shows it now
  /// and at the next launch.
  Future<void> _open(Sector sector) async {
    var mine = _mySectors.mySectors.remember(
      SectorSummary(
        id: sector.id,
        number: sector.number,
        centre: sector.centre,
        campaign: sector.currentCampaign,
        status: MemberStatus.active,
        // The creator goes by the name the tournée was created with.
        memberName: sector.memberOf(sector.createdBy)?.name,
      ),
    );
    // Always opens: the creator is an active member of what they created.
    if (mine.open(sector.id) case Ok(:final value)) mine = value;
    await _mySectors.save(mine);
  }
}
