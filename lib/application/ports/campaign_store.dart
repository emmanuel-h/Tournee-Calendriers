import 'package:tournee_calendriers/domain/sector/campaign_retention.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';

/// Why the server did not take a step of a new campaign.
enum CampaignFailure {
  /// The phone could not reach the server: a new campaign needs the
  /// network, every step of it (PLAN §5.10).
  noNetwork,

  /// The server refused: only an admin starts a campaign, and the phone is
  /// no longer an admin's (PLAN §5.12).
  notAdmin,
}

/// The campaigns of a secteur on the server, as an admin starting a new
/// one handles them (« Nouvelle campagne », PLAN §5.10): the streets of
/// the year left, their copies in the new year, the switch, and the past
/// years no longer kept.
///
/// An application port: the use case owns this interface, an adapter in
/// `infrastructure/` implements it with Firestore (`campaigns/{year}`,
/// PLAN §6.2), tests use a fake. Every step asks the server, never the
/// phone's copy, which may miss what a teammate wrote; each fails with
/// [CampaignFailure.noNetwork] offline and [CampaignFailure.notAdmin] when
/// the server refuses. Each step can be run again: the use case runs them
/// all again after a cut.
abstract interface class CampaignStore {
  /// The streets of [campaign] of [sector], those in the Corbeille
  /// included (they are not copied). A street the adapter cannot read is
  /// left out: it could not be copied either.
  Future<Result<List<Street>, CampaignFailure>> streetsOf(
    SectorId sector,
    CampaignYear campaign,
  );

  /// Writes the campaign [to] of [sector], copied from [from], holding
  /// exactly [streets] (`Street.forNextCampaign`): it is created if
  /// missing, each street written whole, and a street it held from an
  /// earlier try that is not among [streets] any more is deleted. Members
  /// still see [from] meanwhile: [switchTo] comes after.
  Future<Result<void, CampaignFailure>> writeCopies(
    SectorId sector, {
    required CampaignYear from,
    required CampaignYear to,
    required List<Street> streets,
  });

  /// Moves [sector] to the campaign [year], written before by
  /// [writeCopies]: every member's phone follows. Nothing changes when the
  /// secteur is on [year] or later already (another admin did it).
  Future<Result<void, CampaignFailure>> switchTo(
    SectorId sector,
    CampaignYear year,
  );

  /// Every campaign [sector] holds, the current one included, and whether
  /// each had a validated tournée: what `yearsToDeleteAtRollOver` decides
  /// on.
  Future<Result<List<CampaignRecord>, CampaignFailure>> campaignsOf(
    SectorId sector,
  );

  /// Deletes the campaigns [years] of [sector] for good: their streets,
  /// their validated tournées, then the campaign itself.
  Future<Result<void, CampaignFailure>> delete(
    SectorId sector,
    Set<CampaignYear> years,
  );
}
