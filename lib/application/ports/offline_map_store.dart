import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// The map kept on the phone for offline use: one region of map tiles per
/// downloaded tournée (PLAN §6.3, §7), so the map shows after an offline
/// cold start.
///
/// An outbound port: an adapter in `infrastructure/maplibre_offline/`
/// implements it over the map library's offline database, tests use a
/// fake. Listing and deleting work offline; downloading needs the network.
/// Nothing here throws on a failure the member could act on: a download
/// that cannot finish ends with [MapDownloadFailed].
abstract interface class OfflineMapStore {
  /// Every region on the phone made for a tournée, complete or not (a
  /// download cut by the app being killed leaves its region behind).
  Future<List<OfflineMapRegion>> regions();

  /// Downloads a new region of [bounds] for [tournee], from the lowest to
  /// the highest offline zoom (`offline_area.dart`).
  ///
  /// The stream gives [MapDownloadProgress] while it goes, then ends with
  /// exactly one [MapDownloadDone] or [MapDownloadFailed]. Cancelling the
  /// subscription before that deletes the half-made region. The regions
  /// already on the phone are left as they are, unless one has the same
  /// bounds (see `offlineRegionBounds`).
  Stream<MapDownloadEvent> download(TourneeId tournee, GeoBounds bounds);

  /// Deletes [region] and the tiles no other region uses. Nothing happens
  /// when it is gone already.
  Future<void> delete(OfflineMapRegion region);
}

/// A region of the map kept on the phone: its [id] in the map library's
/// database, the [tournee] it was downloaded for, and its [bounds].
final class OfflineMapRegion {
  const OfflineMapRegion({
    required this.id,
    required this.tournee,
    required this.bounds,
  });

  final int id;
  final TourneeId tournee;
  final GeoBounds bounds;

  @override
  bool operator ==(Object other) =>
      other is OfflineMapRegion &&
      other.id == id &&
      other.tournee == tournee &&
      other.bounds == bounds;

  @override
  int get hashCode => Object.hash(id, tournee, bounds);

  @override
  String toString() => 'OfflineMapRegion($id, $tournee, $bounds)';
}

/// What a map download tells while it goes. `sealed`: a `switch` handles
/// each case.
sealed class MapDownloadEvent {
  const MapDownloadEvent();
}

/// The download goes on: [fraction] of the region's resources are on the
/// phone (0 to 1), [bytes] of them so far.
final class MapDownloadProgress extends MapDownloadEvent {
  const MapDownloadProgress({required this.fraction, required this.bytes});

  final double fraction;
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is MapDownloadProgress &&
      other.fraction == fraction &&
      other.bytes == bytes;

  @override
  int get hashCode => Object.hash(fraction, bytes);

  @override
  String toString() => 'MapDownloadProgress($fraction, $bytes)';
}

/// The region is complete on the phone: [bytes] in all.
final class MapDownloadDone extends MapDownloadEvent {
  const MapDownloadDone({required this.bytes});

  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is MapDownloadDone && other.bytes == bytes;

  @override
  int get hashCode => bytes.hashCode;

  @override
  String toString() => 'MapDownloadDone($bytes)';
}

/// The region could not be completed (the map service refused it, the
/// network stayed away too long); its half-made region is deleted.
final class MapDownloadFailed extends MapDownloadEvent {
  const MapDownloadFailed();

  @override
  bool operator ==(Object other) => other is MapDownloadFailed;

  @override
  int get hashCode => (MapDownloadFailed).hashCode;

  @override
  String toString() => 'MapDownloadFailed()';
}
