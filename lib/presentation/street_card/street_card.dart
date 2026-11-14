import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';

// The card of a street of the secteur tapped on a map: on Accueil, with
// « Ouvrir » (PLAN §5.14); on « Ajouter des rues », with « Modifier la
// rue » and « Supprimer la rue » (PLAN §5.19).

/// A street of the secteur: its progress, and the part of it the secteur
/// holds (PLAN §5.15). Every member covers every street, so the card names
/// nobody.
final class StreetCardInSector {
  const StreetCardInSector({
    required this.id,
    required this.name,
    required this.commune,
    required this.done,
    required this.total,
    this.part = StreetPart.whole,
  });

  /// The card of [street].
  factory StreetCardInSector.of(Street street) {
    final progress = street.progress;
    return StreetCardInSector(
      id: street.id,
      name: street.name.text,
      commune: street.commune.name,
      done: progress.visited,
      total: progress.total,
      part: street.part,
    );
  }

  /// The street the card's buttons open, change or delete.
  final StreetId id;
  final String name;
  final String commune;

  /// Doors visited (done or refused), out of [total].
  final int done;
  final int total;

  /// The part of the street the secteur holds: « Toute la rue » most of
  /// the time. Shown on « Ajouter des rues » only.
  final StreetPart part;

  @override
  bool operator ==(Object other) =>
      other is StreetCardInSector &&
      other.id == id &&
      other.name == name &&
      other.commune == commune &&
      other.done == done &&
      other.total == total &&
      other.part == part;

  @override
  int get hashCode => Object.hash(id, name, commune, done, total, part);

  @override
  String toString() =>
      'StreetCardInSector(${id.value}, $name, $commune, $done/$total'
      '${part.isWhole ? '' : ', $part'})';
}
