import 'dart:ui' show Offset, Rect;

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// Translations between the domain's places and MapLibre's, and where the
/// camera starts. MapLibre types stay in `ui/map/` (PLAN §10.1).

/// The zoom « Me localiser » centres the map at: street zoom, where the
/// house dots show (PLAN §5.3).
const locateZoom = 17.0;

/// The zoom the map opens at on a tournée, before it fits the tournée's
/// area exactly.
const _sectorZoom = 14.0;

/// The whole of mainland France: where the map opens when it has no
/// tournée area to show yet.
const _france = CameraPosition(target: LatLng(46.6, 2.5), zoom: 5);

LatLng latLngOf(GeoPoint point) => LatLng(point.latitude, point.longitude);

/// The point MapLibre reported, or null if it is not a number (`LatLng`
/// keeps its coordinates in range, but lets `NaN` through).
GeoPoint? geoPointOf(LatLng latLng) => switch (GeoPoint.create(
  latitude: latLng.latitude,
  longitude: latLng.longitude,
)) {
  Ok(:final value) => value,
  Err() => null,
};

LatLngBounds latLngBoundsOf(GeoBounds bounds) => LatLngBounds(
  southwest: LatLng(bounds.south, bounds.west),
  northeast: LatLng(bounds.north, bounds.east),
);

/// Where the map opens: on the middle of [area] when there is one (it then
/// fits it once the style is loaded), on France otherwise.
CameraPosition initialCamera(GeoBounds? area) => switch (area) {
  null => _france,
  final area => CameraPosition(
    target: LatLng((area.south + area.north) / 2, (area.west + area.east) / 2),
    zoom: _sectorZoom,
  ),
};

/// How the camera moves so a target stays in view, clear of the panels over
/// the map (#132). `sealed`: the map handles each one.
sealed class CameraReveal {
  const CameraReveal();
}

/// The target is in view already, or there is no room to show it: the map
/// stays where the user put it.
final class StayPut extends CameraReveal {
  const StayPut();

  @override
  bool operator ==(Object other) => other is StayPut;

  @override
  int get hashCode => (StayPut).hashCode;
}

/// The map slides by [offset], in logical pixels, at the same zoom: what
/// was at a point of the screen is then at that point plus [offset].
final class PanBy extends CameraReveal {
  const PanBy(this.offset);

  final Offset offset;

  @override
  bool operator ==(Object other) => other is PanBy && other.offset == offset;

  @override
  int get hashCode => offset.hashCode;

  @override
  String toString() => 'PanBy($offset)';
}

/// The target is larger than the room for it: the map zooms out to fit
/// it.
final class FitTarget extends CameraReveal {
  const FitTarget();

  @override
  bool operator ==(Object other) => other is FitTarget;

  @override
  int get hashCode => (FitTarget).hashCode;
}

/// How the map moves so [target] (a zone, or a ✓ as a rectangle of no
/// size), where it is on screen now, ends up inside [free], the part of
/// the map the panels leave (both in logical pixels).
///
/// The least move that does it: a slide just far enough, never a zoom in.
/// The map zooms out only for a target that cannot fit at this zoom.
CameraReveal cameraReveal(Rect target, Rect free) {
  if (free.width <= 0 || free.height <= 0) return const StayPut();
  if (target.width > free.width || target.height > free.height) {
    return const FitTarget();
  }
  // On each axis the target fits: slide it back in past the edge it
  // crosses, if any.
  double slide(double start, double end, double freeStart, double freeEnd) =>
      start < freeStart
      ? freeStart - start
      : end > freeEnd
      ? freeEnd - end
      : 0;
  final offset = Offset(
    slide(target.left, target.right, free.left, free.right),
    slide(target.top, target.bottom, free.top, free.bottom),
  );
  return offset == Offset.zero ? const StayPut() : PanBy(offset);
}
