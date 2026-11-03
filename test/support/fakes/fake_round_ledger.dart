// An in-memory RoundLedger that records what it is given, in order.
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

final class FakeRoundLedger implements RoundLedger {
  /// Every summary recorded, with its secteur and campaign.
  final recorded = <(SectorId, CampaignYear, RoundSummary)>[];

  /// Called inside [record], before it ends: lets a test look at the
  /// phone at that moment.
  void Function()? onRecord;

  @override
  Future<void> record(
    SectorId sector,
    CampaignYear campaign,
    RoundSummary summary,
  ) async {
    onRecord?.call();
    recorded.add((sector, campaign, summary));
  }
}
