import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// A street ticked on the map of « Ajouter des rues » (PLAN §5.14, Pick
/// mockup), as the map draws it: its [road] with a dark casing and a white
/// core, and a ✓ disc at [mark]. A tap on either names the [street], which
/// unticks it.
///
/// The road comes from the map's tiles a moment after the tick, or never
/// (a road OpenStreetMap does not name): until then, and then, only the ✓
/// disc shows.
final class PickedRoad {
  const PickedRoad({
    required this.street,
    required this.road,
    required this.mark,
  });

  /// The BAN street ticked.
  final BanStreetId street;

  /// Its road; [StreetShape.none] while it is not known.
  final StreetShape road;

  /// Where the ✓ disc sits: where the finger tapped the road, or the point
  /// the BAN gives for a street picked in the search.
  final GeoPoint mark;

  @override
  bool operator ==(Object other) =>
      other is PickedRoad &&
      other.street == street &&
      other.road == road &&
      other.mark == mark;

  @override
  int get hashCode => Object.hash(street, road, mark);

  /// The road is left out: its points would make a failing test unreadable.
  @override
  String toString() => 'PickedRoad(${street.value})';
}
