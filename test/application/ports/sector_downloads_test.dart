// A download kept on the phone is equal by value and prints what it holds.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/sector_downloads.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

import '../../support/geo_fixtures.dart';

final _area = GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)])!;
final _morning = DateTime.utc(2026, 11, 2, 8, 12);

SectorDownload _download({
  String sector = 't49',
  DateTime? at,
  int mapBytes = 6600000,
  GeoBounds? area,
  bool noArea = false,
}) => SectorDownload(
  sector: SectorId(sector),
  downloadedAt: at ?? _morning,
  mapBytes: mapBytes,
  area: noArea ? null : area ?? _area,
);

void main() {
  test('should be equal to a download with the same fields', () {
    expect(_download(), _download());
    expect(_download().hashCode, _download().hashCode);
  });

  test('should differ when any field differs', () {
    expect(_download(), isNot(_download(sector: 't12')));
    expect(
      _download(),
      isNot(_download(at: _morning.add(const Duration(minutes: 1)))),
    );
    expect(_download(), isNot(_download(mapBytes: 1)));
    expect(_download(), isNot(_download(area: _area.expandedBy(1))));
    expect(_download(), isNot(_download(noArea: true)));
  });

  test('should print its fields', () {
    expect(
      '${_download(noArea: true)}',
      'SectorDownload(SectorId(t49), 2026-11-02 08:12:00.000Z, 6600000, null)',
    );
  });
}
