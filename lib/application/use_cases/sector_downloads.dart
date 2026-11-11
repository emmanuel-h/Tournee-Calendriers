import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/ports/sector_downloads.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

// The secteurs downloaded on this phone for offline use (PLAN §6.3, §7).
// The download itself is `DownloadSector`, run by the app unseen.

/// The secteurs downloaded on this phone, by id. Synchronous: read once at
/// start-up, so it answers after an offline cold start.
final class ReadSectorDownloads {
  const ReadSectorDownloads(this._downloads);

  final SectorDownloads _downloads;

  Map<SectorId, SectorDownload> call() => _downloads.downloads;
}

/// The secteurs downloaded on this phone now, then after each change.
final class ObserveSectorDownloads {
  const ObserveSectorDownloads(this._downloads);

  final SectorDownloads _downloads;

  Stream<Map<SectorId, SectorDownload>> call() async* {
    yield _downloads.downloads;
    yield* _downloads.changes;
  }
}

/// Deletes what this phone downloaded of a secteur: the date and size
/// kept first, so the secteur no longer counts as downloaded even if the
/// app is killed meanwhile, then every map region made for it. Offline
/// too.
final class DeleteSectorDownload {
  const DeleteSectorDownload(this._maps, this._downloads);

  final OfflineMapStore _maps;
  final SectorDownloads _downloads;

  Future<void> call(SectorId sector) async {
    await _downloads.forget(sector);
    for (final region in await _maps.regions()) {
      if (region.sector == sector) await _maps.delete(region);
    }
  }
}

/// Deletes the downloads of the secteurs the phone forgot (left, removed
/// from, deleted, a request refused): whatever forgot them, their map does
/// not stay on the phone. Also the regions a download killed before its
/// end left behind for such a secteur.
final class PruneSectorDownloads {
  const PruneSectorDownloads(
    this._mySectors,
    this._delete,
    this._maps,
    this._downloads,
  );

  final MySectorsStore _mySectors;
  final DeleteSectorDownload _delete;
  final OfflineMapStore _maps;
  final SectorDownloads _downloads;

  Future<void> call() async {
    final known = {
      for (final sector in _mySectors.mySectors.sectors) sector.id,
    };
    final downloaded = {
      ..._downloads.downloads.keys,
      for (final region in await _maps.regions()) region.sector,
    };
    for (final sector in downloaded.difference(known)) {
      await _delete(sector);
    }
  }
}
