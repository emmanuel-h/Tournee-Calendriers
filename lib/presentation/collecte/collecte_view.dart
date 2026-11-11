import 'package:tournee_calendriers/domain/round/collecte.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

// The view state of « Collecte 2026 » (PLAN §5.13, mockups RunTeam and
// Cash): what Équipe's « COLLECTE 2026 » row and the Collecte screen show,
// as plain data tested without widgets. Never a member: the summaries name
// none.

/// What the screens show of the collecte. `sealed`: each screen handles
/// every case.
sealed class CollecteView {
  const CollecteView();
}

/// The validated tournées are being read (from the phone's copy first, a
/// moment at most): nothing shows yet.
final class CollecteLoading extends CollecteView {
  const CollecteLoading();

  @override
  bool operator ==(Object other) => other is CollecteLoading;

  @override
  int get hashCode => (CollecteLoading).hashCode;
}

/// No secteur is open, or its tournées cannot be read.
final class CollecteUnavailable extends CollecteView {
  const CollecteUnavailable();

  @override
  bool operator ==(Object other) => other is CollecteUnavailable;

  @override
  int get hashCode => (CollecteUnavailable).hashCode;
}

/// The collecte of the open secteur's current campaign.
final class CollecteShown extends CollecteView {
  CollecteShown({
    required this.number,
    required this.campaign,
    required List<CollecteRound> rounds,
    required this.totals,
    List<CollecteUnsentRound> unsent = const [],
  }) : rounds = List.unmodifiable(rounds),
       unsent = List.unmodifiable(unsent);

  /// [collecte] of the secteur [number] for [campaign], its times at the
  /// phone's time of day.
  factory CollecteShown.of(
    Collecte collecte, {
    required int number,
    required int campaign,
  }) => CollecteShown(
    number: number,
    campaign: campaign,
    rounds: [for (final round in collecte.rounds) CollecteRound.of(round)],
    totals: collecte.totals,
    unsent: [
      for (final round in collecte.unsent)
        CollecteUnsentRound(
          round: CollecteRound.of(round.summary),
          state: round.state,
        ),
    ],
  );

  /// « Secteur 49 · tournées validées ».
  final int number;

  /// « Collecte 2026 ».
  final int campaign;

  /// « TOURNÉES », newest first.
  final List<CollecteRound> rounds;

  /// « TOTAL DES 4 TOURNÉES »: every tournée of [rounds] added up, none
  /// of [unsent].
  final DonationTotals totals;

  /// « PAS ENCORE ENVOYÉES (2) », newest first: this phone's tournées the
  /// server does not have yet (PLAN §5.16). None most of the time.
  final List<CollecteUnsentRound> unsent;

  @override
  bool operator ==(Object other) =>
      other is CollecteShown &&
      other.number == number &&
      other.campaign == campaign &&
      sameItems(other.rounds, rounds) &&
      other.totals == totals &&
      sameItems(other.unsent, unsent);

  @override
  int get hashCode => Object.hash(
    number,
    campaign,
    Object.hashAll(rounds),
    totals,
    Object.hashAll(unsent),
  );
}

/// One validated tournée of « TOURNÉES »: « Samedi 24 oct. · 14:05 →
/// 18:20 », « 23 maisons, 19 dons », its total; unfolded, its methods.
final class CollecteRound {
  const CollecteRound({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.housesVisited,
    required this.totals,
  });

  /// [summary] at the phone's time of day.
  factory CollecteRound.of(RoundSummary summary) => CollecteRound(
    id: summary.id,
    // Kept in UTC; « 14:05 → 18:20 » is the time of the phone.
    startedAt: summary.startedAt.toLocal(),
    endedAt: summary.endedAt.toLocal(),
    housesVisited: summary.housesVisited,
    totals: summary.totals,
  );

  /// Which tournée: the screen keeps a row unfolded by it.
  final RoundId id;

  /// When it started and was validated, at the phone's time of day.
  final DateTime startedAt;
  final DateTime endedAt;

  /// « 23 maisons ».
  final int housesVisited;

  final DonationTotals totals;

  @override
  bool operator ==(Object other) =>
      other is CollecteRound &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.housesVisited == housesVisited &&
      other.totals == totals;

  @override
  int get hashCode =>
      Object.hash(id, startedAt, endedAt, housesVisited, totals);
}

/// One tournée of « PAS ENCORE ENVOYÉES »: the row of a validated tournée,
/// and where it stands: « ⏳ En attente d'envoi », or « ⚠ Refusée par le
/// serveur » with « Réessayer » and « Effacer ».
final class CollecteUnsentRound {
  const CollecteUnsentRound({required this.round, required this.state});

  final CollecteRound round;
  final UnsentState state;

  @override
  bool operator ==(Object other) =>
      other is CollecteUnsentRound &&
      other.round == round &&
      other.state == state;

  @override
  int get hashCode => Object.hash(round, state);
}
