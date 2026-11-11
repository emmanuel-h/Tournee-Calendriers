import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';

/// « Collecte 2026 » (PLAN §5.13, §5.16): the validated tournées of a
/// campaign of the secteur, and what they collected together. Never split
/// per member: a [RoundSummary] names none.
///
/// The tournées this phone validated that the server does not have yet
/// are apart ([unsent]) and left out of [totals]: the totals are what the
/// secteur has.
final class Collecte {
  Collecte._(List<RoundSummary> rounds, List<UnsentRound> unsent, this.totals)
    : rounds = List.unmodifiable(rounds),
      unsent = List.unmodifiable(unsent);

  /// The collecte of [summaries], newest tournée first, with [unsent] apart.
  ///
  /// A summary whose tournée is among [unsent] is left out of the sent
  /// ones: the phone's copy of the server shows a summary as soon as it is
  /// written, before the server has confirmed it.
  factory Collecte.of(
    Iterable<RoundSummary> summaries, {
    Iterable<UnsentRound> unsent = const [],
  }) {
    final waiting = [...unsent]
      ..sort((a, b) => b.summary.startedAt.compareTo(a.summary.startedAt));
    final waitingIds = {for (final round in waiting) round.id};
    final rounds = [
      for (final summary in summaries)
        if (!waitingIds.contains(summary.id)) summary,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return Collecte._(
      rounds,
      waiting,
      rounds.fold(DonationTotals.none, (sum, round) => sum + round.totals),
    );
  }

  /// The validated tournées the secteur has, newest first (« TOURNÉES »).
  final List<RoundSummary> rounds;

  /// The tournées of this phone not yet with the secteur, newest first
  /// (« PAS ENCORE ENVOYÉES »).
  final List<UnsentRound> unsent;

  /// Every tournée of [rounds] added up (« TOTAL DES 4 TOURNÉES »), without
  /// those of [unsent].
  final DonationTotals totals;
}
