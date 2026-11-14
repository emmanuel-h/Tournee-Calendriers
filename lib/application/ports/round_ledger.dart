import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

/// What the server said of a summary handed to [RoundLedger.record].
enum LedgerAnswer {
  /// The server has the summary: sent now, or by an earlier try.
  kept,

  /// The server refused it (the secteur's rules: the member was removed,
  /// or left, or the secteur or its campaign is gone).
  refused,
}

/// Where the validated tournées of a secteur go (« Collecte », PLAN §5.13):
/// their summaries, never a member, and dons that name no house nor time
/// (#168). A tournée is never deleted here; its dons and money may be
/// corrected, and its forgotten houses settled (PLAN §5.20).
///
/// An application port: the secteur's Firestore `rounds/` (#110), tests
/// use a fake.
abstract interface class RoundLedger {
  /// Adds [summary] to the tournées of [campaign] of [sector], and ends
  /// with the server's answer (#143): [LedgerAnswer.kept] once the server
  /// has it, [LedgerAnswer.refused] when it will not take it. Offline it
  /// waits, however long, until the server can answer.
  ///
  /// Safe to call again for the same tournée (same id), after a kill or a
  /// refusal: a summary the server already has is [LedgerAnswer.kept] as
  /// it is, never written twice.
  Future<LedgerAnswer> record(
    SectorId sector,
    CampaignYear campaign,
    RoundSummary summary,
  );

  /// The validated tournées of [campaign] of [sector], in no particular
  /// order (`Collecte.of` sorts them), again at each change: a teammate's
  /// tournée arriving, or this phone's own once recorded.
  ///
  /// Answers from the phone's copy first, so it works offline once read.
  /// A phone that may not read the secteur (removed, left) gets none.
  Stream<List<RoundSummary>> watch(SectorId sector, CampaignYear campaign);

  /// The validated tournée [round] of [campaign] of [sector], from the
  /// phone's copy first (offline too); null when there is none.
  Future<RoundSummary?> find(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
  );

  /// Writes [correction] on the tournée [round]: its totals, its list of
  /// dons when it changed, when it was corrected, and the houses it adds
  /// to « maisons à marquer » (added to those there, whoever left them).
  ///
  /// Kept on the phone at once ([watch] shows it) and sent when the network
  /// allows; it never waits for the server. Two phones correcting the same
  /// tournée: the last one sent wins.
  Future<void> correct(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
    RoundCorrected correction,
  );

  /// One of the « maisons à marquer » of [round] is [settled]: one fewer to
  /// mark, and one more house visited when marked. Counted from what the
  /// server has, so two phones settling one each both count. Kept and sent
  /// as [correct] is.
  Future<void> settleForgottenHouse(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
    ForgottenHouse settled,
  );
}
