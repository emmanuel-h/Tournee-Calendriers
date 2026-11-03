import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

/// Where the validated tournées of a secteur go (« Collecte », PLAN §5.13):
/// their summaries only, never a member nor a don. A validated tournée is
/// never changed nor deleted, so the ledger only ever adds.
///
/// An application port: the secteur's Firestore `rounds/` in the end
/// (#110), tests use a fake.
abstract interface class RoundLedger {
  /// Adds [summary] to the tournées of [campaign] of [sector]. Recording
  /// the same tournée again (same id) keeps the first one.
  ///
  /// Works offline: the returned `Future` ends once the summary is in the
  /// ledger's hands (kept on the phone, or queued for the server), not when
  /// the server has it.
  Future<void> record(
    SectorId sector,
    CampaignYear campaign,
    RoundSummary summary,
  );
}
