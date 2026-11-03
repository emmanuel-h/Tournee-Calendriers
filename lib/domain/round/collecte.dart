import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';

/// « Collecte 2026 » (PLAN §5.13): the validated tournées of a campaign of
/// the secteur, and what they collected together. Never split per member:
/// a [RoundSummary] names none.
final class Collecte {
  Collecte._(List<RoundSummary> rounds, this.totals)
    : rounds = List.unmodifiable(rounds);

  /// The collecte of [summaries], newest tournée first.
  factory Collecte.of(Iterable<RoundSummary> summaries) {
    final rounds = [...summaries]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return Collecte._(
      rounds,
      rounds.fold(DonationTotals.none, (sum, round) => sum + round.totals),
    );
  }

  /// The validated tournées, newest first (« TOURNÉES »).
  final List<RoundSummary> rounds;

  /// Every tournée added up (« TOTAL DES 4 TOURNÉES »).
  final DonationTotals totals;
}
