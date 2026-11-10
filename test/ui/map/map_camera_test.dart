import 'dart:ui' show Offset, Rect;

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

  group('cameraReveal', () {
    // The part of a 400 × 800 map above a 300 dp sheet, a margin in.
    const free = Rect.fromLTRB(40, 40, 360, 460);

    test('should stay put when the target is inside', () {
      expect(
        cameraReveal(const Rect.fromLTRB(100, 100, 200, 200), free),
        const StayPut(),
      );
    });

    test('should stay put when the target touches every edge', () {
      expect(cameraReveal(free, free), const StayPut());
    });

    test('should move the map up by what the sheet hides of the '
        'target', () {
      expect(
        cameraReveal(const Rect.fromLTRB(100, 400, 200, 500), free),
        const PanBy(Offset(0, -40)),
      );
    });

    test('should move the map down by what the top hides of the target', () {
      expect(
        cameraReveal(const Rect.fromLTRB(100, 10, 200, 110), free),
        const PanBy(Offset(0, 30)),
      );
    });

    test('should move the map left by what the right edge hides', () {
      expect(
        cameraReveal(const Rect.fromLTRB(300, 100, 380, 200), free),
        const PanBy(Offset(-20, 0)),
      );
    });

    test('should move the map right by what the left edge hides', () {
      expect(
        cameraReveal(const Rect.fromLTRB(0, 100, 80, 200), free),
        const PanBy(Offset(40, 0)),
      );
    });

    test('should move both ways for a target off a corner', () {
      expect(
        cameraReveal(const Rect.fromLTRB(350, 450, 370, 470), free),
        const PanBy(Offset(-10, -10)),
      );
    });

    test('should move a point hidden by the sheet just into view', () {
      expect(
        cameraReveal(const Rect.fromLTWH(200, 600, 0, 0), free),
        const PanBy(Offset(0, -140)),
      );
    });

    test('should fit a target taller than the free part', () {
      expect(
        cameraReveal(const Rect.fromLTRB(100, 40, 200, 461), free),
        const FitTarget(),
      );
    });

    test('should fit a target wider than the free part', () {
      expect(
        cameraReveal(const Rect.fromLTRB(39, 100, 360, 200), free),
        const FitTarget(),
      );
    });

    test('should stay put when the sheet leaves no room', () {
      expect(
        cameraReveal(
          const Rect.fromLTRB(100, 100, 200, 200),
          const Rect.fromLTRB(40, 460, 360, 460),
        ),
        const StayPut(),
      );
      expect(
        cameraReveal(
          const Rect.fromLTRB(100, 100, 200, 200),
          const Rect.fromLTRB(40, 40, 30, 460),
        ),
        const StayPut(),
      );
    });

    test('should tell its moves apart', () {
      expect(const PanBy(Offset(0, 1)), isNot(const PanBy(Offset(1, 0))));
      expect(
        const PanBy(Offset(0, 1)).hashCode,
        const PanBy(Offset(0, 1)).hashCode,
      );
      expect(const StayPut().hashCode, const StayPut().hashCode);
      expect(const FitTarget().hashCode, const FitTarget().hashCode);
      expect(const StayPut(), isNot(const FitTarget()));
      expect(const PanBy(Offset(0, 1)).toString(), contains('0.0, 1.0'));
    });
  });
}
