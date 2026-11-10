import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

// The street card of Accueil (PLAN §5.14): a street of the secteur tapped
// on the map. « Ajouter des rues » ticks streets instead of a card.

/// A street of the secteur: its progress and « Ouvrir » (PLAN §5.14). Every
/// member covers every street, so the card names nobody.
final class StreetCardInSector {
  const StreetCardInSector({
    required this.id,
    required this.name,
    required this.commune,
    required this.done,
    required this.total,
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
    );
  }

  /// The street « Ouvrir » opens.
  final StreetId id;
  final String name;
  final String commune;

  /// Doors visited (done or refused), out of [total].
  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is StreetCardInSector &&
      other.id == id &&
      other.name == name &&
      other.commune == commune &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(id, name, commune, done, total);

  @override
  String toString() =>
      'StreetCardInSector(${id.value}, $name, $commune, $done/$total)';
}
