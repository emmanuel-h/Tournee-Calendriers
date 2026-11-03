import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';

/// A don the status picker added to the tournée on (PLAN §5.6): what it
/// was, for the snackbar (« N° 7 fait · 10 € en espèces »), and where it
/// went in the tournée ([index], in the order added), for its « Annuler »,
/// which takes it back out.
///
/// [calendar] is the calendar a house or door done took with it
/// (« + Ajouter un don », #114), which « Annuler » takes back too; null
/// after a « Fait », whose calendar comes with the status.
final class GivenDonation {
  const GivenDonation({
    required this.index,
    required this.donation,
    this.calendar,
  });

  final int index;
  final Donation donation;
  final StreetChange? calendar;

  @override
  bool operator ==(Object other) =>
      other is GivenDonation &&
      other.index == index &&
      other.donation == donation &&
      other.calendar == calendar;

  @override
  int get hashCode => Object.hash(index, donation, calendar);

  /// The calendar only when there is one, so the line stays short.
  @override
  String toString() =>
      'GivenDonation($index, $donation${calendar == null ? '' : ', $calendar'})';
}
