import 'package:tournee_calendriers/domain/round/donation.dart';

/// A don the status picker added to the tournée on (PLAN §5.6): what it
/// was, for the snackbar (« N° 7 fait · 10 € en espèces »), and where it
/// went in the tournée ([index], in the order added), for its « Annuler »,
/// which takes it back out.
final class GivenDonation {
  const GivenDonation({required this.index, required this.donation});

  final int index;
  final Donation donation;

  @override
  bool operator ==(Object other) =>
      other is GivenDonation &&
      other.index == index &&
      other.donation == donation;

  @override
  int get hashCode => Object.hash(index, donation);

  @override
  String toString() => 'GivenDonation($index, $donation)';
}
