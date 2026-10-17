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
const _tourneeZoom = 14.0;

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
    zoom: _tourneeZoom,
  ),
};
