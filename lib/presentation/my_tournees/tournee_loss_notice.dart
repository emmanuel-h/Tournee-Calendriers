import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_loss.dart';

/// What the app tells once the phone forgot a tournée the member lost
/// (PLAN §5.3): « Vous avez été retiré de la tournée 49. » or « La tournée
/// 49 a été supprimée. », over the next screen.
final class TourneeLossNotice {
  const TourneeLossNotice({
    required this.tournee,
    required this.number,
    required this.loss,
    required this.wasOpen,
  });

  /// Which tournée was forgotten: two notices about two tournées with the
  /// same number (in two centres) are two notices.
  final TourneeId tournee;

  /// « la tournée 49 ».
  final int number;
  final TourneeLoss loss;

  /// It was the tournée the app showed: the app goes back to its start
  /// screen, with none open.
  final bool wasOpen;

  @override
  bool operator ==(Object other) =>
      other is TourneeLossNotice &&
      other.tournee == tournee &&
      other.number == number &&
      other.loss == loss &&
      other.wasOpen == wasOpen;

  @override
  int get hashCode => Object.hash(tournee, number, loss, wasOpen);

  @override
  String toString() =>
      'TourneeLossNotice(${tournee.value}, $number, ${loss.name}, '
      '${wasOpen ? 'open' : 'closed'})';
}
