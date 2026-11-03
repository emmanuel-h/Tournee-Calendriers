import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

// The view state of the tournée on (PLAN §5.13, mockups RunStart, RunHome,
// RunStreet, RunDons, RunRecap): what Accueil's card, the street's line,
// « Dons de la tournée » and « Bilan de la tournée » show, as plain data
// tested without widgets.

/// What the screens show of the tournée. `sealed`: each screen handles
/// every case.
sealed class RoundView {
  const RoundView();
}

/// The phone's tournée is being read (a moment, at most): nothing shows,
/// rather than a « Commencer une tournée » that would vanish a frame later.
final class RoundLoading extends RoundView {
  const RoundLoading();

  @override
  bool operator ==(Object other) => other is RoundLoading;

  @override
  int get hashCode => (RoundLoading).hashCode;

  @override
  String toString() => 'RoundLoading';
}

/// No tournée on in the secteur shown.
final class RoundOff extends RoundView {
  const RoundOff({required this.canStart});

  /// « Commencer une tournée » shows: the member of this phone is in the
  /// team of the open secteur (not an admin visiting it, PLAN §5.12).
  final bool canStart;

  @override
  bool operator ==(Object other) =>
      other is RoundOff && other.canStart == canStart;

  @override
  int get hashCode => Object.hash(RoundOff, canStart);

  @override
  String toString() => 'RoundOff(canStart: $canStart)';
}

/// One don of « Dons de la tournée », with where it is in the tournée.
///
/// The list shows the dons newest first, but the tournée names a don by
/// its place in the order they were added (`Round.donations`): [index] is
/// that place, which « Modifier le don » and « Supprimer ce don » send
/// back.
final class DonationRow {
  const DonationRow({required this.index, required this.donation});

  /// The place of [donation] in the order added: 0 is the first don.
  final int index;
  final Donation donation;

  @override
  bool operator ==(Object other) =>
      other is DonationRow &&
      other.index == index &&
      other.donation == donation;

  @override
  int get hashCode => Object.hash(index, donation);

  @override
  String toString() => 'DonationRow($index, $donation)';
}

/// A tournée is on in the secteur shown.
final class RoundOn extends RoundView {
  RoundOn({
    required this.startedAt,
    required this.now,
    required this.housesVisited,
    required this.totals,
    required List<DonationRow> donations,
  }) : donations = List.unmodifiable(donations);

  /// « Commencer une tournée », in the phone's time zone.
  final DateTime startedAt;

  /// When this view was made, in the phone's time zone, from the `Clock`:
  /// the end of « de 14 h 05 à 18 h 20 » until the tournée is validated.
  final DateTime now;

  /// « 23 maisons visitées ».
  final int housesVisited;

  /// « 19 dons · 280 € », and the money per method of the « Bilan ».
  final DonationTotals totals;

  /// The dons, newest first (« Dons de la tournée »).
  final List<DonationRow> donations;

  /// How long the tournée has been on (« En tournée depuis 1 h 20 »);
  /// never negative, should the phone's clock be set back meanwhile.
  Duration get elapsed {
    final elapsed = now.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  @override
  bool operator ==(Object other) =>
      other is RoundOn &&
      other.startedAt == startedAt &&
      other.now == now &&
      other.housesVisited == housesVisited &&
      other.totals == totals &&
      sameItems(other.donations, donations);

  @override
  int get hashCode => Object.hash(
    startedAt,
    now,
    housesVisited,
    totals,
    Object.hashAll(donations),
  );

  @override
  String toString() =>
      'RoundOn($startedAt, $now, $housesVisited, $totals, $donations)';
}
