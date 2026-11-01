// The offline map of the app ⇄ the map library's offline regions.
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide Error;
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/maplibre_offline/mappers/offline_region_mapper.dart';

import '../../../support/geo_fixtures.dart';

const _style = 'https://tiles.openfreemap.org/styles/liberty';

final _bounds = GeoBounds.around([
  at(45.98225, 4.70827),
  at(45.99575, 4.72773),
])!;

/// A region of the map library with [metadata], over [southwest] to
/// [northeast].
OfflineRegion _region(
  Map<String, dynamic> metadata, {
  LatLng southwest = const LatLng(45.98225, 4.70827),
  LatLng northeast = const LatLng(45.99575, 4.72773),
}) => OfflineRegion(
  id: 7,
  definition: OfflineRegionDefinition(
    bounds: LatLngBounds(southwest: southwest, northeast: northeast),
    mapStyleUrl: _style,
    minZoom: 12,
    maxZoom: 17,
  ),
  metadata: metadata,
);

void main() {
  test('should define the region over the bounds, zooms 12 to 17, with '
      'the style', () {
    final definition = regionDefinition(_bounds, _style);

    expect(definition.bounds.southwest.latitude, 45.98225);
    expect(definition.bounds.southwest.longitude, closeTo(4.70827, 1e-12));
    expect(definition.bounds.northeast.latitude, 45.99575);
    expect(definition.bounds.northeast.longitude, closeTo(4.72773, 1e-12));
    expect(definition.mapStyleUrl, _style);
    expect(definition.minZoom, 12);
    expect(definition.maxZoom, 17);
    expect(definition.includeIdeographs, isFalse);
  });

  test('should name the tournée in the metadata', () {
    expect(regionMetadata(TourneeId('t49')), {'tournee': 't49'});
  });

  // The map library rounds a longitude on its way (`4.70827` comes back
  // as `4.708269999999999`): far below the 1e-7° that tells regions apart.
  test('should read a region made for a tournée', () {
    final region = offlineMapRegionOf(_region({'tournee': 't49'}))!;

    expect(region.id, 7);
    expect(region.tournee, TourneeId('t49'));
    expect(region.bounds.isCloseTo(_bounds, 1e-12), isTrue);
  });

  test('should read what it defined', () {
    final region = offlineMapRegionOf(
      OfflineRegion(
        id: 3,
        definition: regionDefinition(_bounds, _style),
        metadata: regionMetadata(TourneeId('t12')),
      ),
    )!;

    expect(region.id, 3);
    expect(region.tournee, TourneeId('t12'));
    expect(region.bounds.isCloseTo(_bounds, 1e-12), isTrue);
  });

  final notOurs = <String, Map<String, dynamic>>{
    'no metadata': {},
    'a tournée not a text': {'tournee': 49},
    'a blank tournée': {'tournee': ' '},
  };
  for (final MapEntry(key: what, value: metadata) in notOurs.entries) {
    test('should leave out a region with $what', () {
      expect(offlineMapRegionOf(_region(metadata)), isNull);
    });
  }

  // The map library wraps a longitude past 180 round to -180 and clamps a
  // latitude, so a bad region reads as one over the antimeridian.
  test('should leave out a region whose sides are the wrong way '
      'round', () {
    expect(
      offlineMapRegionOf(
        _region({'tournee': 't49'}, northeast: const LatLng(45.99, 190)),
      ),
      isNull,
    );
  });

  test('should turn the percentage into a fraction, with the bytes', () {
    expect(
      progressOf(InProgress(25, completedResourceSize: 1200)),
      const MapDownloadProgress(fraction: 0.25, bytes: 1200),
    );
  });

  test('should keep the fraction between 0 and 1', () {
    expect(progressOf(InProgress(100.5)).fraction, 1);
    expect(progressOf(InProgress(-1)).fraction, 0);
  });
}
