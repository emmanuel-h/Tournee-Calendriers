// The values of the offline map port are equal by value and print what
// they hold, so a failing test says what differed.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

import '../../support/geo_fixtures.dart';

final _bounds = GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)])!;

OfflineMapRegion _region({
  int id = 7,
  String tournee = 't49',
  GeoBounds? bounds,
}) => OfflineMapRegion(
  id: id,
  tournee: TourneeId(tournee),
  bounds: bounds ?? _bounds,
);

void main() {
  group('OfflineMapRegion', () {
    test('should be equal to a region with the same fields', () {
      expect(_region(), _region());
      expect(_region().hashCode, _region().hashCode);
    });

    test('should differ when any field differs', () {
      expect(_region(), isNot(_region(id: 8)));
      expect(_region(), isNot(_region(tournee: 't12')));
      expect(_region(), isNot(_region(bounds: _bounds.expandedBy(1))));
    });

    test('should print its fields', () {
      expect(
        '${_region()}',
        'OfflineMapRegion(7, TourneeId(t49), '
            'GeoBounds(south: 45.98, west: 4.7, north: 45.99, east: 4.72))',
      );
    });
  });

  group('MapDownloadEvent', () {
    test('should have a progress equal by value', () {
      const progress = MapDownloadProgress(fraction: 0.5, bytes: 10);

      expect(progress, const MapDownloadProgress(fraction: 0.5, bytes: 10));
      expect(
        progress.hashCode,
        const MapDownloadProgress(fraction: 0.5, bytes: 10).hashCode,
      );
      expect(
        progress,
        isNot(const MapDownloadProgress(fraction: 0.6, bytes: 10)),
      );
      expect(
        progress,
        isNot(const MapDownloadProgress(fraction: 0.5, bytes: 11)),
      );
      expect('$progress', 'MapDownloadProgress(0.5, 10)');
    });

    test('should have an end equal by value', () {
      const done = MapDownloadDone(bytes: 10);

      expect(done, const MapDownloadDone(bytes: 10));
      expect(done.hashCode, const MapDownloadDone(bytes: 10).hashCode);
      expect(done, isNot(const MapDownloadDone(bytes: 11)));
      expect('$done', 'MapDownloadDone(10)');
    });

    test('should have every failure equal', () {
      expect(const MapDownloadFailed(), const MapDownloadFailed());
      expect(
        const MapDownloadFailed().hashCode,
        const MapDownloadFailed().hashCode,
      );
      expect(const MapDownloadFailed(), isNot(const MapDownloadDone(bytes: 0)));
      expect('${const MapDownloadFailed()}', 'MapDownloadFailed()');
    });
  });
}
