import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why the secteurs of a centre de secours cannot move to a new campaign
/// together (PLAN §5.10).
enum CentreRollOverRefusal {
  /// The centre has no secteur: nothing to start.
  noSector,

  /// Its secteurs do not all work on the same year. Which year each one
  /// should then move to is for the centre's own admin view to decide
  /// (being designed apart from #39); each secteur can still be moved on
  /// its own.
  mixedYears,
}

/// The one year every secteur of a centre works on ([currents]), when they
/// all agree: the year a new campaign of the whole centre starts from.
Result<CampaignYear, CentreRollOverRefusal> commonCampaignOf(
  Iterable<CampaignYear> currents,
) {
  final years = currents.toSet();
  if (years.isEmpty) return const Err(CentreRollOverRefusal.noSector);
  if (years.length > 1) return const Err(CentreRollOverRefusal.mixedYears);
  return Ok(years.single);
}
