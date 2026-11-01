import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/application/use_cases/download_tournee.dart';
import 'package:tournee_calendriers/application/use_cases/offline_map_download.dart';
import 'package:tournee_calendriers/domain/map/offline_area.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// How a [RefreshOfflineMaps] went.
enum MapRefreshOutcome {
  /// Every downloaded tournée's map is fresh (or there was none).
  refreshed,

  /// A map could not be downloaded again (offline, the service down): it
  /// keeps its old region, and the refresh can be tried again later.
  failed,
}

/// Downloads again the map of every tournée downloaded on this phone,
/// silently (PLAN §7).
///
/// The map's tiles get a new version every week, and the map library keeps
/// a region's tiles under the version they were downloaded with: once the
/// app has been online after a change, the stored map points at the new
/// version and the old tiles cannot be reached offline any more
/// (docs/spikes/map.md §5). Downloading the region again while online
/// fetches the few tiles that changed and checks the rest.
///
/// Each map comes as a **new region** of the area kept with the download
/// ([offlineRegionBounds]: 1 m wider when a region holds the area), and the
/// tournée's older regions are deleted only once it is complete: a failure
/// leaves the old map in place. The first failure stops the refresh. The
/// downloads kept (date, size) do not change.
///
/// Also run right after a tournée is downloaded, for the others: the map's
/// description is one for all regions, and the download just made it name
/// this week's tiles.
final class RefreshOfflineMaps {
  const RefreshOfflineMaps(
    this._maps,
    this._downloads, {
    this.stallLimit = DownloadTournee.defaultStallLimit,
  });

  final OfflineMapStore _maps;
  final TourneeDownloads _downloads;

  /// How long a map download may tell nothing before it fails.
  final Duration stallLimit;

  /// Refreshes every downloaded tournée's map, but the map of [except]
  /// (downloaded a moment ago) when given.
  Future<MapRefreshOutcome> call({TourneeId? except}) async {
    for (final download in _downloads.downloads.values) {
      final area = download.area;
      if (area == null || download.tournee == except) continue;
      final regions = await _maps.regions();
      final bounds = offlineRegionBounds(area, [
        for (final region in regions) region.bounds,
      ]);
      final last = await followMapDownload(
        _maps,
        download.tournee,
        bounds,
        stallLimit: stallLimit,
      ).last;
      if (last is! MapDownloadDone) return MapRefreshOutcome.failed;
      for (final region in regions) {
        if (region.tournee == download.tournee) await _maps.delete(region);
      }
    }
    return MapRefreshOutcome.refreshed;
  }
}
