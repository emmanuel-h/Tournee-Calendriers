import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// What the map draws of [street]'s road (PLAN §5.15 « Map »): the whole
/// road, or for a street held « du n° a au n° b » on a side only the
/// stretch between its first and last number held, along the road.
///
/// A side held whole covers the whole road, and a part by side alone
/// (« Impairs ») cannot be shown by one line: both draw the whole road.
/// The numbers « + numéros » added outside the part, and those without a
/// position, do not stretch it; when no number held has a position, the
/// whole road is drawn rather than nothing.
StreetShape heldStretchOf(Street street) {
  final part = street.part;
  if (!_isCutAlongTheRoad(part)) return street.shape;
  final held = [
    for (final house in street.houses)
      if (house.position case final position? when part.holds(house.number))
        position,
  ];
  if (held.isEmpty) return street.shape;
  return street.shape.stretchOver(held, beyondMetres: heldStretchBeyondMetres);
}

/// The stretch goes this far beyond its first and last house, so a single
/// house still has a line to tap.
const heldStretchBeyondMetres = 3.0;

/// Whether [part] holds a range on a side and no side whole.
bool _isCutAlongTheRoad(StreetPart part) => switch ((part.odd, part.even)) {
  (AllNumbers(), _) || (_, AllNumbers()) => false,
  (NumberRange(), _) || (_, NumberRange()) => true,
  (NoNumbers(), NoNumbers()) => false,
};
