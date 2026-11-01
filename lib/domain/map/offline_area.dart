import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/street/street.dart';

// The map kept on the phone so a tournée works a whole day offline (PLAN
// §7): what to download, and when the download no longer covers the
// streets. The area itself is `tourneeArea`: the streets plus 300 m.

/// The lowest zoom kept offline: a whole commune on the screen.
const offlineMapMinZoom = 12;

/// The highest zoom kept offline: a few houses on the screen. The map's
/// tiles stop at zoom 14 and are enlarged beyond, so zooms 15 to 17 cost
/// nothing (docs/spikes/map.md).
const offlineMapMaxZoom = 17;

/// How far out a new region is moved when a region already covers its
/// area, in metres.
const offlineRegionShiftMetres = 1.0;

/// Below this gap, in degrees, two sides are taken as one. The map
/// library takes two regions for the same when their sides are within
/// 1e-9° and deletes the old one *before* downloading the new one; a
/// wider tolerance here keeps every new region clear of that. One metre
/// is about 9e-6°.
const _sameSideDegrees = 1e-7;

/// The bounds of a new region for [area], given the bounds of the regions
/// already on the phone ([taken]).
///
/// The area itself when no region holds it; otherwise the area widened by
/// [offlineRegionShiftMetres], or by twice that if that is taken too, and
/// so on. A new region then never replaces an old one before it is
/// complete: the old one is deleted only once the new one is (a cut
/// download keeps the old map). Refreshed again and again, a region goes
/// back and forth between the area and the area 1 m wider: it never grows.
GeoBounds offlineRegionBounds(GeoBounds area, Iterable<GeoBounds> taken) {
  bool isTaken(GeoBounds bounds) =>
      taken.any((region) => region.isCloseTo(bounds, _sameSideDegrees));
  var bounds = area;
  for (var shift = 1; isTaken(bounds); shift++) {
    bounds = area.expandedBy(shift * offlineRegionShiftMetres);
  }
  return bounds;
}

/// Whether the map kept for [area] (null: no map was kept) still covers
/// every place of the [streets] on the map, margin aside: false once a
/// teammate added a street beyond it, so the tournée is downloaded again.
/// Streets with no place on the map (typed in by hand) need no map.
bool coversStreets(GeoBounds? area, Iterable<Street> streets) {
  final places = streetsBounds(streets);
  if (places == null) return true;
  return area != null && area.contains(places);
}
