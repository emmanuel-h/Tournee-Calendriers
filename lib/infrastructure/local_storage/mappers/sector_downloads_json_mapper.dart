// Translation between the secteurs downloaded on this phone (PLAN §6.3,
// §7) and the JSON the phone keeps for them. Pure functions: no file here,
// so they are tested alone.
//
// The schema, version 1 (downloads sorted by secteur):
//
//   { version: 1, downloads: [{
//       tournee: "t49",
//       at: "2026-11-02T08:12:00.000Z",        (UTC)
//       mapBytes: 6600000,
//       area: [south, west, north, east] | null  (degrees; null: no map)
//   }, …] }
//
// The key `tournee` (and the file name, `tournee_downloads.json`) date from
// before the code said « sector » (#116). They stay as they are, so a phone
// updated from an older version keeps its offline downloads.
import 'package:tournee_calendriers/application/ports/sector_downloads.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

/// The schema version this code writes and reads.
const storedSectorDownloadsVersion = 1;

/// The stored form of [downloads]. Sorted, so the same downloads always
/// make the same file.
Map<String, Object?> sectorDownloadsToJson(
  Map<SectorId, SectorDownload> downloads,
) => {
  'version': storedSectorDownloadsVersion,
  'downloads': [
    for (final download in [
      ...downloads.values,
    ]..sort((a, b) => a.sector.value.compareTo(b.sector.value)))
      {
        'tournee': download.sector.value,
        // Always UTC, so the text has one form whatever the time zone.
        'at': download.downloadedAt.toUtc().toIso8601String(),
        'mapBytes': download.mapBytes,
        'area': switch (download.area) {
          null => null,
          final area => [area.south, area.west, area.north, area.east],
        },
      },
  ],
};

/// The downloads read from [json] as `jsonDecode` gives it, by secteur.
/// Throws a [FormatException] when it is not a version 1 file.
Map<SectorId, SectorDownload> sectorDownloadsFromJson(Object? json) {
  if (json case {
    'version': storedSectorDownloadsVersion,
    'downloads': final List<Object?> downloads,
  }) {
    return {
      for (final download in downloads.map(_download))
        download.sector: download,
    };
  }
  throw FormatException('Not the secteurs downloaded: $json');
}

SectorDownload _download(Object? json) {
  if (json
      case {
        'tournee': final String sector,
        'at': final String at,
        'mapBytes': final int mapBytes,
        'area': final Object? area,
      }
      when sector.trim().isNotEmpty && mapBytes >= 0) {
    final time = DateTime.tryParse(at);
    if (time == null) throw FormatException('Not a stored time', at);
    return SectorDownload(
      sector: SectorId(sector),
      downloadedAt: time.toUtc(),
      mapBytes: mapBytes,
      area: area == null ? null : _area(area),
    );
  }
  throw FormatException('Not a secteur downloaded: $json');
}

GeoBounds _area(Object json) {
  if (json case [
    final num south,
    final num west,
    final num north,
    final num east,
  ]) {
    final area = GeoBounds.of(
      south: south.toDouble(),
      west: west.toDouble(),
      north: north.toDouble(),
      east: east.toDouble(),
    );
    if (area != null) return area;
  }
  throw FormatException('Not a stored area: $json');
}
