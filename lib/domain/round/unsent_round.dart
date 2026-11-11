import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

/// Where a validated tournée not yet with its secteur stands (PLAN §5.16).
enum UnsentState {
  /// « ⏳ En attente d'envoi »: offline, or the server has not answered
  /// yet. It goes by itself once it can.
  waiting,

  /// « ⚠ Refusée par le serveur »: the secteur's rules refused it (the
  /// member was removed, or left, or the secteur is gone). It waits for
  /// « Réessayer » or « Effacer ».
  refused,
}

/// A tournée validated on this phone whose summary the secteur does not
/// have yet (PLAN §5.16, #143, #155): « validated, not yet sent ».
///
/// `Round.validate` makes it; the phone keeps it (`OpenRoundStore`) until
/// the server confirms the summary, so the dons of an outing never exist
/// nowhere. Several may wait at once: a new tournée may start meanwhile.
///
/// Immutable, equal by value: each change of [state] gives a new one.
final class UnsentRound {
  const UnsentRound({
    required this.sector,
    required this.campaign,
    required this.summary,
    this.state = UnsentState.waiting,
  });

  /// The secteur the tournée started in: its summary goes there.
  final SectorId sector;

  /// The campaign of that secteur it counts in.
  final CampaignYear campaign;

  /// All that will leave the phone (no member, no don).
  final RoundSummary summary;

  final UnsentState state;

  /// The tournée's id, which is its summary's document id on the server.
  RoundId get id => summary.id;

  /// The server refused it.
  UnsentRound refused() => _in(UnsentState.refused);

  /// « Réessayer »: it waits to be sent again.
  UnsentRound retried() => _in(UnsentState.waiting);

  UnsentRound _in(UnsentState state) => UnsentRound(
    sector: sector,
    campaign: campaign,
    summary: summary,
    state: state,
  );

  @override
  bool operator ==(Object other) =>
      other is UnsentRound &&
      other.sector == sector &&
      other.campaign == campaign &&
      other.summary == summary &&
      other.state == state;

  @override
  int get hashCode => Object.hash(sector, campaign, summary, state);

  @override
  String toString() =>
      'UnsentRound(${id.value}, ${sector.value}, ${campaign.value}, '
      '${state.name})';
}
