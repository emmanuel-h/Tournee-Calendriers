import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// Prefixed: the map library's `Error` (a failed download) would hide
// Dart's own `Error` in this file otherwise.
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/maplibre_offline/mappers/offline_region_mapper.dart';

/// The [OfflineMapStore] of the map library: its offline database on the
/// phone (`files/mbgl-offline.db`), kept until the app is removed.
///
/// SDK glue, kept thin: the translations are in
/// `mappers/offline_region_mapper.dart`, the decisions in the use cases;
/// covered by the device checklist (PLAN §11). What the map spike learnt
/// (docs/spikes/map.md §4–§6):
/// - `downloadOfflineRegion` returns once the region is made, not once it
///   is complete: the end is its `Success` event;
/// - offline, the library never tells a failure: it waits for the network
///   (the use cases give up after a minute without news);
/// - a download over the same bounds as a region of the phone deletes that
///   region first (`offlineRegionBounds` keeps clear of it);
/// - `resetOfflineDatabase` is never called (it once mixed regions up).
final class MapLibreOfflineMapStore implements OfflineMapStore {
  /// [styleUrl]: the style the map shows. Its regions are kept under its
  /// address, so it must be the very one the map widget opens.
  const MapLibreOfflineMapStore({required this.styleUrl});

  final String styleUrl;

  @override
  Future<List<OfflineMapRegion>> regions() async => [
    for (final region in await maplibre.getListOfRegions())
      ?offlineMapRegionOf(region),
  ];

  @override
  Stream<MapDownloadEvent> download(TourneeId tournee, GeoBounds bounds) {
    late final StreamController<MapDownloadEvent> out;
    int? regionId;
    var lastBytes = 0;
    var ended = false;
    var succeeded = false;

    Future<void> deleteRegion() async {
      if (regionId case final id?) await _deleteQuietly(id);
    }

    void end(MapDownloadEvent last) {
      if (ended) return;
      ended = true;
      out.add(last);
      unawaited(out.close());
    }

    Future<void> fail() async {
      if (ended) return;
      await deleteRegion();
      end(const MapDownloadFailed());
    }

    // The size counted by the library once the region is complete; the
    // last progress told when it cannot say.
    Future<void> succeed() async {
      final id = regionId;
      // `Success` came before the region's id: told once it is known.
      if (id == null || ended) return;
      try {
        final status = await maplibre.getOfflineRegionStatus(id);
        end(MapDownloadDone(bytes: status.completedResourceSize));
      } on PlatformException {
        end(MapDownloadDone(bytes: lastBytes));
      }
    }

    out = StreamController<MapDownloadEvent>(
      onListen: () async {
        try {
          final region = await maplibre.downloadOfflineRegion(
            regionDefinition(bounds, styleUrl),
            metadata: regionMetadata(tournee),
            onEvent: (status) {
              // `DownloadRegionStatus` is not sealed: `_` takes any kind a
              // later version of the library adds.
              switch (status) {
                case maplibre.InProgress():
                  if (ended) return;
                  final progress = progressOf(status);
                  lastBytes = progress.bytes;
                  out.add(progress);
                case maplibre.Success():
                  succeeded = true;
                  unawaited(succeed());
                case maplibre.Error(:final cause):
                  debugPrint('Offline map download failed: $cause');
                  unawaited(fail());
                case _:
                  break;
              }
            },
          );
          regionId = region.id;
          // Cancelled while the region was being made: it goes at once.
          if (ended) return await deleteRegion();
          if (succeeded) await succeed();
        } on PlatformException catch (error) {
          debugPrint('Offline map download failed: $error');
          await fail();
        }
      },
      onCancel: () async {
        if (ended) return;
        ended = true;
        await deleteRegion();
      },
    );
    return out.stream;
  }

  @override
  Future<void> delete(OfflineMapRegion region) => _deleteQuietly(region.id);

  /// Deletes the region [id]; one already gone is not a failure, and a
  /// region the library could not delete is left for the next prune or
  /// download of its tournée.
  Future<void> _deleteQuietly(int id) async {
    try {
      await maplibre.deleteOfflineRegion(id);
    } on PlatformException catch (error) {
      debugPrint('Offline map region $id not deleted: $error');
    }
  }
}
