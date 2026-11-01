import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/use_cases/download_tournee.dart';
import 'package:tournee_calendriers/application/use_cases/refresh_offline_maps.dart';
import 'package:tournee_calendriers/application/use_cases/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/map/offline_area.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/offline/offline_map_upkeep.dart';

/// The [OfflineAutoDownload] of the open tournée. Built again when another
/// tournée (or none) opens: the old one is disposed first, which stops its
/// download, so a switch never waits for the tournée left. The composition
/// root keeps it alive and calls [OfflineAutoDownload.check] when the app
/// comes back to the foreground.
final offlineAutoDownloadProvider = Provider<OfflineAutoDownload>((ref) {
  // `select`: only the tournée and its campaign matter; a pending request
  // cannot read its streets (PLAN §8.2), so it counts as none.
  final open = ref.watch(
    currentTourneeProvider.select(
      (tournee) => tournee == null || tournee.isPending
          ? null
          : (tournee.id, tournee.campaign),
    ),
  );
  final auto = OfflineAutoDownload(
    open: open,
    download: ref.watch(downloadTourneeProvider),
    downloads: ref.watch(readTourneeDownloadsProvider),
    upkeep: ref.watch(offlineMapUpkeepProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(auto.dispose);
  if (open != null) {
    // The streets the phone has of the open tournée (its cache first), to
    // see a teammate's new street reach beyond the map kept.
    final streets = ref
        .watch(observeStreetsProvider)()
        .listen(auto.streetsChanged, onError: (Object _) {});
    ref.onDispose(streets.cancel);
  }
  unawaited(auto.check());
  return auto;
});

/// Starts [callback] after [delay]: `Timer.new` in the app, a fake in
/// tests, which call the callback themselves.
typedef Schedule = Timer Function(Duration delay, void Function() callback);

/// Downloads the open tournée for offline use by itself, unseen by the
/// member (PLAN §7): there is no button, no banner, no progress.
///
/// Each [check]:
/// 1. when the open tournée is not downloaded on this phone, or its
///    streets now reach beyond the map kept (`coversStreets`) →
///    `DownloadTournee`, then the maps of the other downloaded tournées
///    are refreshed at once (`OfflineMapUpkeep.refreshAllBut`): the
///    download made the map's description name this week's tiles;
/// 2. otherwise → the silent map refresh of every downloaded tournée when
///    due (`OfflineMapUpkeep.refreshIfDue`), which keeps their maps
///    reachable offline when the map's tiles change every week.
///
/// [check] runs when it is built (start-up, a tournée opened), when the
/// streets change, when the app comes back to the foreground, and
/// [retryDelay] after a failure: offline, it fails and waits, then tries
/// again, until the network is back. One run at a time: a check asked
/// meanwhile runs once more after it.
final class OfflineAutoDownload {
  // `required this._open` as a named parameter: callers write it without
  // the underscore, `open:` (as `FirestoreStreetRepository` does).
  OfflineAutoDownload({
    required this._open,
    required this._download,
    required this._downloads,
    required this._upkeep,
    required this._clock,
    this._schedule = Timer.new,
  });

  /// How long after a failure the next check waits.
  static const retryDelay = Duration(minutes: 2);

  final (TourneeId, CampaignYear)? _open;
  final DownloadTournee _download;
  final ReadTourneeDownloads _downloads;
  final OfflineMapUpkeep _upkeep;
  final Clock _clock;
  final Schedule _schedule;

  /// The open tournée's streets last given; null until the first.
  List<Street>? _streets;

  var _running = false;
  var _again = false;
  var _disposed = false;

  /// No check before this time, after a failure.
  DateTime? _pausedUntil;
  Timer? _retry;

  /// The download going, to stop when this is disposed.
  StreamSubscription<DownloadProgress>? _downloading;
  Completer<bool>? _downloadDone;

  /// The open tournée's streets changed (a teammate added one, a house was
  /// marked): checks whether the map kept still covers them.
  void streetsChanged(List<Street> streets) {
    _streets = streets;
    unawaited(check());
  }

  /// Downloads the open tournée when it needs it, else refreshes the maps
  /// when due (see the class). Returns once the run is over; a call made
  /// while one goes returns at once, and the run goes round once more.
  Future<void> check() async {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    if (_pausedUntil case final until? when _clock.now().isBefore(until)) {
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        if (!await _step()) {
          _pauseAfterFailure();
          return;
        }
      } while (_again && !_disposed);
    } finally {
      _running = false;
    }
  }

  /// Stops the download going (its half-made region is deleted) and every
  /// check to come.
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    if (_downloadDone case final done? when !done.isCompleted) {
      done.complete(true);
    }
    unawaited(_downloading?.cancel());
  }

  /// One check; false when it failed.
  Future<bool> _step() async {
    if (_open case (final tournee, final campaign)) {
      final kept = _downloads()[tournee];
      final streets = _streets;
      if (kept == null ||
          (streets != null && !coversStreets(kept.area, streets))) {
        if (!await _runDownload(tournee, campaign)) return false;
        if (_disposed) return true;
        return _refreshed(() => _upkeep.refreshAllBut(tournee));
      }
    }
    return _refreshed(_upkeep.refreshIfDue);
  }

  /// Whether [refresh] worked. The map library may also fail in a way it
  /// does not say (its database): tried again later, like any failure.
  Future<bool> _refreshed(Future<MapRefreshOutcome> Function() refresh) async {
    try {
      return await refresh() == MapRefreshOutcome.refreshed;
    } on Object {
      return false;
    }
  }

  Future<bool> _runDownload(TourneeId tournee, CampaignYear campaign) {
    final done = _downloadDone = Completer<bool>();
    _downloading = _download(tournee, campaign).listen(
      (progress) {
        switch (progress) {
          case DownloadingStreets() || DownloadingMap():
            break;
          case Downloaded():
            done.complete(true);
          case DownloadFailed():
            done.complete(false);
        }
      },
      onError: (Object _) {
        if (!done.isCompleted) done.complete(false);
      },
    );
    return done.future;
  }

  void _pauseAfterFailure() {
    if (_disposed) return;
    _pausedUntil = _clock.now().add(retryDelay);
    _retry?.cancel();
    _retry = _schedule(retryDelay, () => unawaited(check()));
  }
}
