import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';

/// What the app tells once the phone forgot a secteur the member lost
/// (PLAN §5.3): « Vous avez été retiré du secteur 49. » or « Le secteur
/// 49 a été supprimé. », over the next screen.
final class SectorLossNotice {
  const SectorLossNotice({
    required this.sector,
    required this.number,
    required this.loss,
    required this.wasOpen,
  });

  /// Which secteur was forgotten: two notices about two secteurs with the
  /// same number (in two centres) are two notices.
  final SectorId sector;

  /// « le secteur 49 ».
  final int number;
  final SectorLoss loss;

  /// It was the secteur the app showed: the app goes back to its start
  /// screen, with none open.
  final bool wasOpen;

  @override
  bool operator ==(Object other) =>
      other is SectorLossNotice &&
      other.sector == sector &&
      other.number == number &&
      other.loss == loss &&
      other.wasOpen == wasOpen;

  @override
  int get hashCode => Object.hash(sector, number, loss, wasOpen);

  @override
  String toString() =>
      'SectorLossNotice(${sector.value}, $number, ${loss.name}, '
      '${wasOpen ? 'open' : 'closed'})';
}
