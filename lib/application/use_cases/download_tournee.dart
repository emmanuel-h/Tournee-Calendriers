import 'dart:async';

import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/ports/streets_download.dart';
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/application/use_cases/offline_map_download.dart';
import 'package:tournee_calendriers/domain/map/offline_area.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// Downloads a tournée so it works a whole day offline (PLAN §7), cold
/// start included. The app runs it by itself, unseen by the member, when
/// the open tournée is not downloaded yet or its streets now reach beyond
/// the map kept (`OfflineAutoDownload`); run again, it updates the
/// download.
///
/// 1. Every street is read once from the server: Firestore's cache, with
///    no size limit, then holds all of them.
/// 2. The map of the streets' area (`tourneeArea`: the streets plus 300 m)
///    is downloaded as a new region, zooms 12 to 17. The tournée's older
///    regions are deleted only once it is complete, so a cut download
///    keeps the old map ([offlineRegionBounds] keeps the map library from
///    replacing an old region of the same bounds first).
/// 3. The date, the map's size and its area are kept on the phone.
///
/// Nothing is kept when a step fails: the tournée stays as downloaded as
/// it was. Cancelling the stream stops the download the same way.
final class DownloadTournee {
  const DownloadTournee(
    this._streets,
    this._maps,
    this._downloads,
    this._clock, {
    this.stallLimit = defaultStallLimit,
  });

  /// How long a map download may tell nothing before it fails.
  static const defaultStallLimit = Duration(minutes: 1);

  final StreetsDownload _streets;
  final OfflineMapStore _maps;
  final TourneeDownloads _downloads;
  final Clock _clock;
  final Duration stallLimit;

  /// Downloads the streets of [campaign] of [tournee] and their map. The
  /// stream tells each step and ends with [Downloaded] or
  /// [DownloadFailed]. Cancelling it stops the map download at once and
  /// deletes its half-made region; nothing is kept then.
  Stream<DownloadProgress> call(TourneeId tournee, CampaignYear campaign) {
    // Made by hand rather than with `async*`: an `async*` body waiting in
    // an `await for` hears its listener cancel only at its next event,
    // which a stalled map download would put off for [stallLimit].
    late final StreamController<DownloadProgress> out;
    final run = _Run();
    out = StreamController<DownloadProgress>(
      onListen: () => unawaited(
        // A port that throws (the phone's storage, the map library's
        // database) ends the stream with its error.
        _download(tournee, campaign, out, run).catchError((
          Object error,
          StackTrace stack,
        ) {
          out.addError(error, stack);
          return out.close();
        }),
      ),
      onCancel: run.cancel,
    );
    return out.stream;
  }

  Future<void> _download(
    TourneeId tournee,
    CampaignYear campaign,
    StreamController<DownloadProgress> out,
    _Run run,
  ) async {
    void end(DownloadProgress last) {
      out.add(last);
      unawaited(out.close());
    }

    out.add(const DownloadingStreets());
    final List<Street> streets;
    switch (await _streets.fromServer(tournee, campaign)) {
      case Err(:final failure):
        return end(
          DownloadFailed(switch (failure) {
            StreetsDownloadFailure.noNetwork => DownloadFailure.noNetwork,
            StreetsDownloadFailure.serviceError => DownloadFailure.serviceError,
          }),
        );
      case Ok(:final value):
        streets = value;
    }
    if (run.cancelled) return;
    final area = tourneeArea(streets);
    final regions = await _maps.regions();
    final older = [
      for (final region in regions)
        if (region.tournee == tournee) region,
    ];
    var mapBytes = 0;
    if (area != null) {
      final bounds = offlineRegionBounds(area, [
        for (final region in regions) region.bounds,
      ]);
      final last = await run.follow(
        followMapDownload(_maps, tournee, bounds, stallLimit: stallLimit),
        (progress) => out.add(
          DownloadingMap(fraction: progress.fraction, bytes: progress.bytes),
        ),
      );
      switch (last) {
        case null:
          return; // Cancelled.
        case MapDownloadDone(:final bytes):
          mapBytes = bytes;
        case MapDownloadProgress() || MapDownloadFailed():
          return end(const DownloadFailed(DownloadFailure.mapUnavailable));
      }
    }
    if (run.cancelled) return;
    for (final region in older) {
      await _maps.delete(region);
    }
    final download = TourneeDownload(
      tournee: tournee,
      downloadedAt: _clock.now(),
      mapBytes: mapBytes,
      area: area,
    );
    await _downloads.save(download);
    end(Downloaded(download));
  }
}

/// One run of [DownloadTournee]: whether its listener cancelled it, and the
/// map download to stop then.
final class _Run {
  var cancelled = false;
  StreamSubscription<MapDownloadEvent>? _map;
  Completer<MapDownloadEvent?>? _last;

  /// Follows [events], handing each progress to [onProgress]; their last
  /// word, or null when the run is cancelled meanwhile.
  Future<MapDownloadEvent?> follow(
    Stream<MapDownloadEvent> events,
    void Function(MapDownloadProgress progress) onProgress,
  ) {
    final last = _last = Completer<MapDownloadEvent?>();
    _map = events.listen((event) {
      if (event is MapDownloadProgress) {
        onProgress(event);
      } else {
        last.complete(event);
      }
    });
    return last.future;
  }

  Future<void> cancel() async {
    cancelled = true;
    if (_last case final last? when !last.isCompleted) last.complete(null);
    await _map?.cancel();
  }
}

/// Where a [DownloadTournee] is. `sealed`: a `switch` handles each case.
sealed class DownloadProgress {
  const DownloadProgress();
}

/// The streets are being read from the server.
final class DownloadingStreets extends DownloadProgress {
  const DownloadingStreets();

  @override
  bool operator ==(Object other) => other is DownloadingStreets;

  @override
  int get hashCode => (DownloadingStreets).hashCode;
}

/// The map is being downloaded: [fraction] of it (0 to 1), [bytes] so far.
final class DownloadingMap extends DownloadProgress {
  const DownloadingMap({required this.fraction, required this.bytes});

  final double fraction;
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is DownloadingMap &&
      other.fraction == fraction &&
      other.bytes == bytes;

  @override
  int get hashCode => Object.hash(fraction, bytes);

  @override
  String toString() => 'DownloadingMap($fraction, $bytes)';
}

/// The tournée is downloaded, as [download] says; it is kept on the phone.
final class Downloaded extends DownloadProgress {
  const Downloaded(this.download);

  final TourneeDownload download;

  @override
  bool operator ==(Object other) =>
      other is Downloaded && other.download == download;

  @override
  int get hashCode => download.hashCode;

  @override
  String toString() => 'Downloaded($download)';
}

/// The download stopped, for [failure]; the phone keeps what it had.
final class DownloadFailed extends DownloadProgress {
  const DownloadFailed(this.failure);

  final DownloadFailure failure;

  @override
  bool operator ==(Object other) =>
      other is DownloadFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'DownloadFailed($failure)';
}

/// Why a [DownloadTournee] stopped. Each may work later: the app tries
/// again by itself.
enum DownloadFailure {
  /// The server could not be reached.
  noNetwork,

  /// The server refused or failed to give the streets.
  serviceError,

  /// The map could not be downloaded (refused, or the network stayed away
  /// too long).
  mapUnavailable,
}
