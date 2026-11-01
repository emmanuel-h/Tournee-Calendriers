import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

// The tournées downloaded on this phone for offline use (PLAN §6.3, §7).
// The download itself is `DownloadTournee`, run by the app unseen.

/// The tournées downloaded on this phone, by id. Synchronous: read once at
/// start-up, so it answers after an offline cold start.
final class ReadTourneeDownloads {
  const ReadTourneeDownloads(this._downloads);

  final TourneeDownloads _downloads;

  Map<TourneeId, TourneeDownload> call() => _downloads.downloads;
}

/// The tournées downloaded on this phone now, then after each change.
final class ObserveTourneeDownloads {
  const ObserveTourneeDownloads(this._downloads);

  final TourneeDownloads _downloads;

  Stream<Map<TourneeId, TourneeDownload>> call() async* {
    yield _downloads.downloads;
    yield* _downloads.changes;
  }
}

/// Deletes what this phone downloaded of a tournée: the date and size
/// kept first, so the tournée no longer counts as downloaded even if the
/// app is killed meanwhile, then every map region made for it. Offline
/// too.
final class DeleteTourneeDownload {
  const DeleteTourneeDownload(this._maps, this._downloads);

  final OfflineMapStore _maps;
  final TourneeDownloads _downloads;

  Future<void> call(TourneeId tournee) async {
    await _downloads.forget(tournee);
    for (final region in await _maps.regions()) {
      if (region.tournee == tournee) await _maps.delete(region);
    }
  }
}

/// Deletes the downloads of the tournées the phone forgot (left, removed
/// from, deleted, a request refused): whatever forgot them, their map does
/// not stay on the phone. Also the regions a download killed before its
/// end left behind for such a tournée.
final class PruneTourneeDownloads {
  const PruneTourneeDownloads(
    this._myTournees,
    this._delete,
    this._maps,
    this._downloads,
  );

  final MyTourneesStore _myTournees;
  final DeleteTourneeDownload _delete;
  final OfflineMapStore _maps;
  final TourneeDownloads _downloads;

  Future<void> call() async {
    final known = {
      for (final tournee in _myTournees.myTournees.tournees) tournee.id,
    };
    final downloaded = {
      ..._downloads.downloads.keys,
      for (final region in await _maps.regions()) region.tournee,
    };
    for (final tournee in downloaded.difference(known)) {
      await _delete(tournee);
    }
  }
}
