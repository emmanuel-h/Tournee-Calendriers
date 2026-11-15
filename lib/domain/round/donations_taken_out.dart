import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_origin.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// One don a ✓ taken back took out of the tournée, and its place in the
/// list before (`Round.donations`). A record: two with the same fields are
/// equal.
typedef DonationTakenOut = ({int index, Donation donation});

/// The dons linked to [origin] that a ✓ taken back took out of the tournée
/// [round] (PLAN §5.21), in the order they were in it. What the snackbar
/// says (« son don de 20 € en espèces est retiré de la tournée ») and what
/// its « Annuler » puts back (`Round.putBack`).
final class DonationsTakenOut {
  DonationsTakenOut({
    required this.round,
    required this.origin,
    required List<DonationTakenOut> taken,
  }) : taken = List.unmodifiable(taken);

  /// The tournée they were taken out of: « Annuler » puts them back only
  /// there.
  final RoundId round;

  /// The house or door they were noted from.
  final DonationOrigin origin;

  /// Each don with its place in the list before, the first place first.
  final List<DonationTakenOut> taken;

  /// The dons themselves, in their order.
  List<Donation> get donations => [for (final entry in taken) entry.donation];

  /// Whether no don was taken out (no don was linked to [origin]).
  bool get isEmpty => taken.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is DonationsTakenOut &&
      other.round == round &&
      other.origin == origin &&
      sameItems(other.taken, taken);

  @override
  int get hashCode => Object.hash(round, origin, Object.hashAll(taken));

  @override
  String toString() => 'DonationsTakenOut(${round.value}, $origin, $taken)';
}
