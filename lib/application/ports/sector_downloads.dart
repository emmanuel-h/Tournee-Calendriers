import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

/// Which tournées this phone has downloaded for offline use, when, and how
/// much (PLAN §6.3, §7): it says whether a tournée can open offline, and
/// what the silent map refresh keeps up to date.
///
/// An application port: an adapter of `infrastructure/local_storage/`
/// keeps it in a file of the phone, tests use a fake. Read without
/// waiting: the adapter loads it before the first screen, so it answers
/// after an offline cold start.
abstract interface class SectorDownloads {
  /// Every tournée downloaded on this phone, by id.
  Map<SectorId, SectorDownload> get downloads;

  /// Each list saved from now on. Nothing is given on listening: read
  /// [downloads] for the list now.
  Stream<Map<SectorId, SectorDownload>> get changes;

  /// Keeps [download], in place of the one of the same tournée. [downloads]
  /// gives it at once; the returned `Future` ends once it is on the phone.
  Future<void> save(SectorDownload download);

  /// Forgets the download of [sector]; nothing happens when there is
  /// none.
  Future<void> forget(SectorId sector);
}

/// A tournée downloaded on this phone: every street read from the server
/// at [downloadedAt] (UTC), and the map of [area] kept, [mapBytes] of it.
/// [area] is null when no street had a place on the map: no map was kept.
final class SectorDownload {
  const SectorDownload({
    required this.sector,
    required this.downloadedAt,
    required this.mapBytes,
    required this.area,
  });

  final SectorId sector;
  final DateTime downloadedAt;
  final int mapBytes;
  final GeoBounds? area;

  @override
  bool operator ==(Object other) =>
      other is SectorDownload &&
      other.sector == sector &&
      other.downloadedAt == downloadedAt &&
      other.mapBytes == mapBytes &&
      other.area == area;

  @override
  int get hashCode => Object.hash(sector, downloadedAt, mapBytes, area);

  @override
  String toString() =>
      'SectorDownload($sector, $downloadedAt, $mapBytes, $area)';
}
