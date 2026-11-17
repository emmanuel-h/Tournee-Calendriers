import 'package:tournee_calendriers/domain/sector/campaign_year.dart';

/// A campaign a secteur still holds, as the retention rule sees it: its
/// [year] and whether at least one tournée of it was validated
/// (a summary under `campaigns/{year}/rounds/`, PLAN §5.16).
final class CampaignRecord {
  const CampaignRecord({required this.year, required this.hasValidatedRound});

  final CampaignYear year;

  /// Whether the year had a validated tournée: a year without one has
  /// nothing worth keeping (no Collecte).
  final bool hasValidatedRound;

  @override
  bool operator ==(Object other) =>
      other is CampaignRecord &&
      other.year == year &&
      other.hasValidatedRound == hasValidatedRound;

  @override
  int get hashCode => Object.hash(year, hasValidatedRound);

  @override
  String toString() =>
      'CampaignRecord(${year.value}, validated tournée: $hasValidatedRound)';
}

/// The years to delete when the next campaign starts (PLAN §5.10), given
/// every [campaigns] the secteur holds now: the current one, about to be
/// closed, and the past ones still kept.
///
/// Once the new year starts they are all past, and a secteur keeps at most
/// one past year (data minimisation): the latest that had a validated
/// tournée. That is the year just closed if it had one, otherwise the last
/// real one before it. Every other year is deleted; all of them when none
/// had a validated tournée. The order of [campaigns] does not matter.
Set<CampaignYear> yearsToDeleteAtRollOver(Iterable<CampaignRecord> campaigns) {
  CampaignYear? kept;
  for (final campaign in campaigns) {
    if (!campaign.hasValidatedRound) continue;
    if (kept == null || campaign.year.value > kept.value) kept = campaign.year;
  }
  return {
    for (final campaign in campaigns)
      if (campaign.year != kept) campaign.year,
  };
}
