// Translation between the tournées downloaded on this phone (PLAN §6.3,
// §7) and the JSON the phone keeps for them. Pure functions: no file here,
// so they are tested alone.
//
// The schema, version 1 (downloads sorted by tournée):
//
//   { version: 1, downloads: [{
//       tournee: "t49",
//       at: "2026-11-02T08:12:00.000Z",        (UTC)
//       mapBytes: 6600000,
//       area: [south, west, north, east] | null  (degrees; null: no map)
//   }, …] }
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// The schema version this code writes and reads.
const storedTourneeDownloadsVersion = 1;

/// The stored form of [downloads]. Sorted, so the same downloads always
/// make the same file.
Map<String, Object?> tourneeDownloadsToJson(
  Map<TourneeId, TourneeDownload> downloads,
) => {
  'version': storedTourneeDownloadsVersion,
  'downloads': [
    for (final download in [
      ...downloads.values,
    ]..sort((a, b) => a.tournee.value.compareTo(b.tournee.value)))
      {
        'tournee': download.tournee.value,
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

/// The downloads read from [json] as `jsonDecode` gives it, by tournée.
/// Throws a [FormatException] when it is not a version 1 file.
Map<TourneeId, TourneeDownload> tourneeDownloadsFromJson(Object? json) {
  if (json case {
    'version': storedTourneeDownloadsVersion,
    'downloads': final List<Object?> downloads,
  }) {
    return {
      for (final download in downloads.map(_download))
        download.tournee: download,
    };
  }
  throw FormatException('Not the tournées downloaded: $json');
}

TourneeDownload _download(Object? json) {
  if (json
      case {
        'tournee': final String tournee,
        'at': final String at,
        'mapBytes': final int mapBytes,
        'area': final Object? area,
      }
      when tournee.trim().isNotEmpty && mapBytes >= 0) {
    final time = DateTime.tryParse(at);
    if (time == null) throw FormatException('Not a stored time', at);
    return TourneeDownload(
      tournee: TourneeId(tournee),
      downloadedAt: time.toUtc(),
      mapBytes: mapBytes,
      area: area == null ? null : _area(area),
    );
  }
  throw FormatException('Not a tournée downloaded: $json');
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
