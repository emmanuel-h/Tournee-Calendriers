import 'package:tournee_calendriers/application/ports/campaign_store.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/campaign_retention.dart';
import 'package:tournee_calendriers/domain/sector/campaign_roll_over.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';

// A new campaign (« Nouvelle campagne », PLAN §5.10): an admin moves a
// secteur to a later year (the core, [RollOverSector]), or every secteur of
// a centre de secours on one year at once (a thin wrapper,
// [StartCampaign]); every phone of those teams follows. Which year a
// centre whose secteurs disagree should move to is left to the centre's
// admin view, designed apart.

/// Why a secteur did not move to a new campaign, or did not finish.
enum RollOverFailure {
  /// The phone could not reach the server. What was done stays done:
  /// moving the secteur to the same year again finishes the rest.
  noNetwork,

  /// The server refused: the phone is no longer an admin's (PLAN §5.12).
  notAdmin,

  /// The year is before the one the secteur works on: a campaign never
  /// goes back.
  notLater,
}

/// Moves the secteur [SectorId] from its current campaign `from` to the
/// later campaign `to` (admins only, PLAN §5.10, §5.12). Needs the
/// network.
///
/// The streets of `from` are read from the server, the setup of each one
/// copied into `to` (`Street.forNextCampaign`: the Corbeille is not), and
/// only then the secteur switched to it, so no phone ever opens a
/// half-copied year. Then the years before `to` that the secteur no longer
/// keeps are deleted (`yearsToDeleteAtRollOver`: only the latest one with
/// a validated tournée stays).
///
/// Resumable: cut off midway, the same call finishes what is left; once
/// the secteur is on `to` (`from` == `to`), only the deletions are done
/// again, which delete nothing more once done.
final class RollOverSector {
  const RollOverSector(this._campaigns);

  final CampaignStore _campaigns;

  Future<Result<void, RollOverFailure>> call(
    SectorId sector, {
    required CampaignYear from,
    required CampaignYear to,
  }) async {
    if (to.value < from.value) return const Err(RollOverFailure.notLater);
    if (to.value > from.value) {
      final failure = await _copyAndSwitch(sector, from, to);
      if (failure != null) return Err(_failureOf(failure));
    }
    final failure = await _dropPastYears(sector, to);
    if (failure != null) return Err(_failureOf(failure));
    return const Ok(null);
  }

  /// Copies the setup of [sector] from [from] into [to], then switches it:
  /// null once done, or the step's failure.
  Future<CampaignFailure?> _copyAndSwitch(
    SectorId sector,
    CampaignYear from,
    CampaignYear to,
  ) async {
    final List<Street> streets;
    switch (await _campaigns.streetsOf(sector, from)) {
      case Ok(:final value):
        streets = value;
      case Err(:final failure):
        return failure;
    }
    final copies = await _campaigns.writeCopies(
      sector,
      from: from,
      to: to,
      streets: List.unmodifiable(
        streets.map((street) => street.forNextCampaign()).nonNulls,
      ),
    );
    if (copies case Err(:final failure)) return failure;
    return _failureIn(await _campaigns.switchTo(sector, to));
  }

  /// Deletes the years before [year] that [sector] no longer keeps: null
  /// once done, or the step's failure. [year] itself, and anything after
  /// it, is never deleted.
  Future<CampaignFailure?> _dropPastYears(
    SectorId sector,
    CampaignYear year,
  ) async {
    final List<CampaignRecord> records;
    switch (await _campaigns.campaignsOf(sector)) {
      case Ok(:final value):
        records = value;
      case Err(:final failure):
        return failure;
    }
    final gone = yearsToDeleteAtRollOver(
      records.where((record) => record.year.value < year.value),
    );
    if (gone.isEmpty) return null;
    return _failureIn(await _campaigns.delete(sector, gone));
  }

  CampaignFailure? _failureIn(Result<void, CampaignFailure> result) =>
      switch (result) {
        Ok() => null,
        Err(:final failure) => failure,
      };

  RollOverFailure _failureOf(CampaignFailure failure) => switch (failure) {
    CampaignFailure.noNetwork => RollOverFailure.noNetwork,
    CampaignFailure.notAdmin => RollOverFailure.notAdmin,
  };
}

/// Why the secteurs of a centre did not move to a new campaign together.
enum StartCampaignFailure {
  /// The phone could not reach the server. The secteurs already moved stay
  /// moved: each one left can be moved on its own ([RollOverSector]).
  noNetwork,

  /// The server refused: the phone is no longer an admin's.
  notAdmin,

  /// The centre has no secteur.
  noSector,

  /// The secteurs of the centre do not all work on the same year: nothing
  /// is done (the centre's admin view, designed apart, decides then).
  mixedYears,

  /// The year is before the one the secteurs work on. (The same year
  /// changes nothing but the deletions [RollOverSector] does again.)
  notLater,
}

/// Moves every secteur of a centre de secours to the campaign
/// [CampaignYear] with [RollOverSector], one after the other (admins only,
/// PLAN §5.10). Only when they all work on the same year, read from the
/// server: otherwise nothing is done ([StartCampaignFailure.mixedYears]).
/// A thin wrapper: the policy of a whole centre (which year, ending a
/// year, secteurs that disagree) belongs to the centre's admin view.
final class StartCampaign {
  const StartCampaign(this._directory, this._account, this._campaigns);

  final SectorDirectory _directory;
  final MemberAccount _account;
  final CampaignStore _campaigns;

  Future<Result<void, StartCampaignFailure>> call(
    RescueCentre centre,
    CampaignYear year,
  ) async {
    final admin = switch (await _account.signInIfNeeded()) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (admin == null) return const Err(StartCampaignFailure.noNetwork);
    final List<SectorOverview> all;
    switch (await _directory.allSectors(admin)) {
      case Ok(:final value):
        all = value;
      case Err(failure: DirectoryFailure.noNetwork):
        return const Err(StartCampaignFailure.noNetwork);
      case Err(failure: DirectoryFailure.notAdmin):
        return const Err(StartCampaignFailure.notAdmin);
    }
    final sectors = [
      for (final sector in all)
        if (sector.centre.isSameStationAs(centre)) sector.id,
    ];
    final CampaignYear from;
    switch (commonCampaignOf([
      for (final sector in all)
        if (sector.centre.isSameStationAs(centre)) sector.campaign,
    ])) {
      case Ok(:final value):
        from = value;
      case Err(failure: CentreRollOverRefusal.noSector):
        return const Err(StartCampaignFailure.noSector);
      case Err(failure: CentreRollOverRefusal.mixedYears):
        return const Err(StartCampaignFailure.mixedYears);
    }
    final rollOver = RollOverSector(_campaigns);
    for (final sector in sectors) {
      switch (await rollOver(sector, from: from, to: year)) {
        case Ok():
          break;
        case Err(failure: RollOverFailure.noNetwork):
          return const Err(StartCampaignFailure.noNetwork);
        case Err(failure: RollOverFailure.notAdmin):
          return const Err(StartCampaignFailure.notAdmin);
        // Refused by the first secteur, before anything is written.
        case Err(failure: RollOverFailure.notLater):
          return const Err(StartCampaignFailure.notLater);
      }
    }
    return const Ok(null);
  }
}

/// The campaign the secteur [SectorId] works on, from the server, now and
/// after each change (`SectorDirectory.watchCurrentCampaign`): what
/// [FollowCampaign] moves the phone to.
final class WatchCampaign {
  const WatchCampaign(this._directory);

  final SectorDirectory _directory;

  Stream<CampaignYear> call(SectorId sector) =>
      _directory.watchCurrentCampaign(sector);
}

/// Moves the phone's secteur [SectorId] to the campaign [CampaignYear] its
/// team now works on (a new campaign started, PLAN §5.10): the title
/// shows the new year, and the streets, the Collecte and the offline
/// download follow the open secteur's campaign. Returns the secteur as
/// kept now, or null when nothing changed: the phone has that year or a
/// later one already, does not know the secteur, or only waits for an
/// answer to its request (it cannot read the secteur).
final class FollowCampaign {
  const FollowCampaign(this._store);

  final MySectorsStore _store;

  Future<SectorSummary?> call(SectorId id, CampaignYear year) async {
    final mine = _store.mySectors;
    final sector = mine.find(id);
    if (sector == null || sector.isPending) return null;
    final followed = sector.followedTo(year);
    if (followed == null) return null;
    await _store.save(mine.remember(followed));
    return followed;
  }
}
