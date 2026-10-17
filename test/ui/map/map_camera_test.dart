import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/ui/map/map_camera.dart';

import '../../support/geo_fixtures.dart';

/// Around the centre of Villefranche-sur-Saône.
final _area = GeoBounds.around([at(45.98200, 4.70800), at(45.99600, 4.72800)])!;

void main() {
  test('should give MapLibre the point latitude first', () {
    final latLng = latLngOf(at(45.98915, 4.71862));

    // MapLibre wraps the longitude into -180..180, which costs a few
    // digits far past the metre.
    expect(latLng.latitude, 45.98915);
    expect(latLng.longitude, closeTo(4.71862, 1e-9));
  });

  test('should read back the point MapLibre reports', () {
    final point = geoPointOf(const LatLng(45.98915, 4.71862))!;

    expect(point.latitude, 45.98915);
    expect(point.longitude, closeTo(4.71862, 1e-9));
  });

  test('should read nothing when MapLibre reports no number', () {
    expect(geoPointOf(const LatLng(double.nan, 4.71862)), isNull);
  });

  test('should give MapLibre the bounds from south-west to north-east', () {
    final bounds = latLngBoundsOf(_area);

    expect(bounds.southwest, const LatLng(45.982, 4.708));
    expect(bounds.northeast, const LatLng(45.996, 4.728));
  });

  test('should open on the middle of the area when there is one', () {
    final camera = initialCamera(_area);

    expect(camera.target.latitude, closeTo(45.989, 1e-9));
    expect(camera.target.longitude, closeTo(4.718, 1e-9));
    expect(camera.zoom, 14);
  });

  test('should open on France when there is no area', () {
    final camera = initialCamera(null);

    expect(camera.target, const LatLng(46.6, 2.5));
    expect(camera.zoom, 5);
  });

  test('should centre the phone at street zoom', () {
    expect(locateZoom, 17);
  });
}
