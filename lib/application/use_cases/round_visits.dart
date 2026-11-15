import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/open_round_store.dart';
import 'package:tournee_calendriers/domain/round/donation_origin.dart';
import 'package:tournee_calendriers/domain/round/donations_taken_out.dart';
import 'package:tournee_calendriers/domain/round/round_visit.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';

/// What a status use case (`SetHouseDetails`, `MarkDwelling`) stored: the
/// street's [change], and the dons a ✓ taken back took out of the tournée
/// on with it ([takenOut], PLAN §5.21; null when none did), which the
/// snackbar names and its « Annuler » puts back.
final class Marked<C extends StreetChange> {
  const Marked(this.change, {this.takenOut});

  final C change;
  final DonationsTakenOut? takenOut;

  @override
  bool operator ==(Object other) =>
      other is Marked && other.change == change && other.takenOut == takenOut;

  @override
  int get hashCode => Object.hash(change, takenOut);

  @override
  String toString() => 'Marked($change, $takenOut)';
}

/// Tells the tournée on about a house or door the member of this phone made
/// ✓ or ⊘, or took back (PLAN §5.13: « 23 maisons visitées »), and takes out
/// of it the dons noted from a ✓ taken back (PLAN §5.21).
///
/// Not a use case of its own but a step of the status use cases
/// (`SetHouseDetails`, `MarkDwelling`, `UndoLastChange`), so the count and
/// the dons are right whatever screen marked the house. It acts only on
/// the secteur the tournée started in: a mark made after opening another
/// secteur is not part of it. Needs no network.
final class RoundVisits {
  const RoundVisits(this._rounds, this._mySectors);

  final OpenRoundStore _rounds;
  final MySectorsStore _mySectors;

  /// Adds [visit] to the tournée on, if one is on in the open secteur; puts
  /// back the dons [putBack] (the « Annuler » of a ✓ taken back); then takes
  /// out the dons linked to the house or door [leaving] ✓, and returns them
  /// (null when none was). One save, and none when nothing changes.
  Future<DonationsTakenOut?> note(
    RoundVisit visit, {
    DonationOrigin? leaving,
    DonationsTakenOut? putBack,
  }) async {
    final round = _rounds.openRound;
    if (round == null || round.sector != _mySectors.mySectors.currentId) {
      return null;
    }
    var changed = switch (visit) {
      RoundVisit.visited => round.visited(),
      // Never below 0: a mark made before the tournée may be undone in it.
      RoundVisit.unvisited => round.unvisited(),
      RoundVisit.none => round,
    };
    if (putBack != null) changed = changed.putBack(putBack);
    DonationsTakenOut? takenOut;
    if (leaving != null) {
      final (without, taken) = changed.takeOut(leaving);
      changed = without;
      if (!taken.isEmpty) takenOut = taken;
    }
    if (changed != round) await _rounds.save(changed);
    return takenOut;
  }

  /// [note] for [change], a change the member just stored: what it does to
  /// the count, and the dons of the ✓ it took back.
  Future<DonationsTakenOut?> noteChange(StreetChange change) =>
      note(RoundVisit.of(change), leaving: DonationOrigin.leftDoneBy(change));
}
