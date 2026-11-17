// A CampaignStore in memory, for « Nouvelle campagne » (PLAN §5.10). A test
// plays the server: the streets of each campaign ([streets]), the campaigns
// each secteur holds ([campaigns]), and a step that fails ([failures], by
// the line [steps] would log for it). Every step asked is logged in
// [steps], in order, so a test checks what ran and in which order.
import 'package:tournee_calendriers/application/ports/campaign_store.dart';
import 'package:tournee_calendriers/domain/sector/campaign_retention.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';

final class FakeCampaignStore implements CampaignStore {
  /// The streets of each (secteur, year).
  final streets = <(SectorId, CampaignYear), List<Street>>{};

  /// The campaigns each secteur holds.
  final campaigns = <SectorId, List<CampaignRecord>>{};

  /// The steps that fail, by their line in [steps]
  /// (`'switchTo t49 2027'`).
  final failures = <String, CampaignFailure>{};

  /// Every step asked, in order: `streetsOf t49 2026`, `writeCopies t49
  /// 2026→2027`, `switchTo t49 2027`, `campaignsOf t49`, `delete t49
  /// [2024, 2025]`.
  final steps = <String>[];

  /// The streets each `writeCopies` wrote, by (secteur, year).
  final copies = <(SectorId, CampaignYear), List<Street>>{};

  Result<T, CampaignFailure> _answer<T>(String step, T Function() value) {
    steps.add(step);
    final failure = failures[step];
    return failure == null ? Ok(value()) : Err(failure);
  }

  @override
  Future<Result<List<Street>, CampaignFailure>> streetsOf(
    SectorId sector,
    CampaignYear campaign,
  ) async => _answer(
    'streetsOf ${sector.value} ${campaign.value}',
    () => streets[(sector, campaign)] ?? const [],
  );

  @override
  Future<Result<void, CampaignFailure>> writeCopies(
    SectorId sector, {
    required CampaignYear from,
    required CampaignYear to,
    required List<Street> streets,
  }) async => _answer(
    'writeCopies ${sector.value} ${from.value}→${to.value}',
    () => copies[(sector, to)] = streets,
  );

  @override
  Future<Result<void, CampaignFailure>> switchTo(
    SectorId sector,
    CampaignYear year,
  ) async => _answer('switchTo ${sector.value} ${year.value}', () {});

  @override
  Future<Result<List<CampaignRecord>, CampaignFailure>> campaignsOf(
    SectorId sector,
  ) async => _answer(
    'campaignsOf ${sector.value}',
    () => campaigns[sector] ?? const [],
  );

  @override
  Future<Result<void, CampaignFailure>> delete(
    SectorId sector,
    Set<CampaignYear> years,
  ) async {
    final sorted = [for (final year in years) year.value]..sort();
    return _answer('delete ${sector.value} $sorted', () {});
  }
}
