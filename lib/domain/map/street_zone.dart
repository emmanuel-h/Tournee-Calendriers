import 'package:tournee_calendriers/domain/geometry/clip_line.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

// « Zone » on « Ajouter des rues » (PLAN §5.14, PickZone mockup): a
// rectangle drawn on the map, whose named roads are offered to add at once.

/// The most streets a zone keeps: more, and the list could not be checked
/// street by street. « Zone trop grande : 50 rues au plus. ».
const zoneMaxStreets = 50;

/// Where the ✓ disc of a road found in [zone] sits: half-way along the
/// middle segment of the first piece of [road] inside the zone, so the
/// disc shows inside the rectangle even for a road that runs far beyond
/// it. Null when no piece of [road] is inside.
GeoPoint? markInZone(StreetShape road, GeoBounds zone) {
  for (final line in road.lines) {
    final pieces = clipLine(line, zone);
    if (pieces.isEmpty) continue;
    final piece = pieces.first;
    // A piece has two points or more: its middle segment starts at
    // `(length - 2) ~/ 2`, the only one for two points.
    final start = piece[(piece.length - 2) ~/ 2];
    final end = piece[(piece.length - 2) ~/ 2 + 1];
    // Half-way between two points on Earth is on Earth: it cannot fail.
    return (GeoPoint.create(
      latitude: (start.latitude + end.latitude) / 2,
      longitude: (start.longitude + end.longitude) / 2,
    ) as Ok<GeoPoint, GeoPointFailure>).value;
  }
  return null;
}
