import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/open_round_store.dart';
import 'package:tournee_calendriers/domain/round/round_visit.dart';

/// Tells the tournée on about a house or door the member of this phone made
/// ✓ or ⊘, or took back (PLAN §5.13: « 23 maisons visitées »).
///
/// Not a use case of its own but a step of the status use cases
/// (`SetHouseDetails`, `MarkDwelling`, `UndoLastChange`), so the count is
/// right whatever screen marked the house. It counts only on the secteur
/// the tournée started in: a mark made after opening another secteur is
/// not part of it. Needs no network.
final class RoundVisits {
  const RoundVisits(this._rounds, this._mySectors);

  final OpenRoundStore _rounds;
  final MySectorsStore _mySectors;

  /// Adds [visit] to the tournée on, if one is on in the open secteur.
  /// Saves nothing when it changes nothing.
  Future<void> note(RoundVisit visit) async {
    final round = _rounds.openRound;
    if (round == null || round.sector != _mySectors.mySectors.currentId) {
      return;
    }
    switch (visit) {
      case RoundVisit.visited:
        await _rounds.save(round.visited());
      case RoundVisit.unvisited:
        final counted = round.unvisited();
        // Nothing to take back from a tournée that counted no house yet.
        if (counted != round) await _rounds.save(counted);
      case RoundVisit.none:
        return;
    }
  }
}
