import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// Which tournées this phone has downloaded for offline use, when, and how
/// much (PLAN §6.3, §7): it says whether a tournée can open offline, and
/// what the silent map refresh keeps up to date.
///
/// An application port: an adapter of `infrastructure/local_storage/`
/// keeps it in a file of the phone, tests use a fake. Read without
/// waiting: the adapter loads it before the first screen, so it answers
/// after an offline cold start.
abstract interface class TourneeDownloads {
  /// Every tournée downloaded on this phone, by id.
  Map<TourneeId, TourneeDownload> get downloads;

  /// Each list saved from now on. Nothing is given on listening: read
  /// [downloads] for the list now.
  Stream<Map<TourneeId, TourneeDownload>> get changes;

  /// Keeps [download], in place of the one of the same tournée. [downloads]
  /// gives it at once; the returned `Future` ends once it is on the phone.
  Future<void> save(TourneeDownload download);

  /// Forgets the download of [tournee]; nothing happens when there is
  /// none.
  Future<void> forget(TourneeId tournee);
}

/// A tournée downloaded on this phone: every street read from the server
/// at [downloadedAt] (UTC), and the map of [area] kept, [mapBytes] of it.
/// [area] is null when no street had a place on the map: no map was kept.
final class TourneeDownload {
  const TourneeDownload({
    required this.tournee,
    required this.downloadedAt,
    required this.mapBytes,
    required this.area,
  });

  final TourneeId tournee;
  final DateTime downloadedAt;
  final int mapBytes;
  final GeoBounds? area;

  @override
  bool operator ==(Object other) =>
      other is TourneeDownload &&
      other.tournee == tournee &&
      other.downloadedAt == downloadedAt &&
      other.mapBytes == mapBytes &&
      other.area == area;

  @override
  int get hashCode => Object.hash(tournee, downloadedAt, mapBytes, area);

  @override
  String toString() =>
      'TourneeDownload($tournee, $downloadedAt, $mapBytes, $area)';
}
