import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/use_cases/refresh_offline_maps.dart';
import 'package:tournee_calendriers/application/use_cases/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// The one [OfflineMapUpkeep] of the app. A plain `Provider`, not
/// `autoDispose`, watching only ports that never change: it lives as long
/// as the app, so the time of the last refresh outlives a switch of
/// tournée. It prunes once when built, then after each change of « Mes
/// tournées ».
final offlineMapUpkeepProvider = Provider<OfflineMapUpkeep>((ref) {
  final upkeep = OfflineMapUpkeep(
    ref.watch(refreshOfflineMapsProvider),
    ref.watch(pruneTourneeDownloadsProvider),
    ref.watch(clockProvider),
  );
  final changes = ref
      .watch(observeMyTourneesProvider)()
      .listen((_) => unawaited(upkeep.prune()));
  ref.onDispose(changes.cancel);
  unawaited(upkeep.prune());
  return upkeep;
});

/// Keeps the maps downloaded on this phone usable offline, unseen by the
/// member (PLAN §7):
/// - [refreshIfDue] downloads every downloaded tournée's map again
///   (`RefreshOfflineMaps`), at most once every [refreshInterval] after it
///   worked, one refresh at a time; [refreshAllBut] does it at once, after
///   a tournée was downloaded;
/// - [prune] deletes the downloads of the tournées the phone forgot
///   (`PruneTourneeDownloads`), whatever forgot them.
final class OfflineMapUpkeep {
  OfflineMapUpkeep(this._refresh, this._prune, this._clock);

  /// How long after a refresh that worked the next one waits. The map's
  /// description, which names the week's tiles, is kept a day by the map
  /// library before it asks for it again (docs/spikes/map.md §5): twice a
  /// day keeps ahead of it, without asking the map's free service for its
  /// fonts at each launch.
  static const refreshInterval = Duration(hours: 12);

  final RefreshOfflineMaps _refresh;
  final PruneTourneeDownloads _prune;
  final Clock _clock;

  DateTime? _refreshedAt;
  Future<MapRefreshOutcome>? _refreshing;
  Future<void>? _pruning;
  var _pruneAgain = false;

  /// Refreshes the maps unless a refresh worked less than
  /// [refreshInterval] ago. A call made while one goes shares its outcome.
  Future<MapRefreshOutcome> refreshIfDue() {
    if (_refreshing case final running?) return running;
    if (_refreshedAt case final at?
        when _clock.now().isBefore(at.add(refreshInterval))) {
      return Future.value(MapRefreshOutcome.refreshed);
    }
    final running = _refreshing = _runRefresh();
    return running;
  }

  /// Refreshes the maps of the tournées other than [tournee], which was
  /// downloaded a moment ago, whenever the last refresh was: the download
  /// made the map's description name this week's tiles, for every region.
  /// Waits for a refresh going first.
  Future<MapRefreshOutcome> refreshAllBut(TourneeId tournee) async {
    if (_refreshing case final running?) await running;
    final refreshing = _refreshing = _runRefresh(except: tournee);
    return refreshing;
  }

  Future<MapRefreshOutcome> _runRefresh({TourneeId? except}) async {
    try {
      final outcome = await _refresh(except: except);
      if (outcome == MapRefreshOutcome.refreshed) _refreshedAt = _clock.now();
      return outcome;
    } finally {
      _refreshing = null;
    }
  }

  /// Deletes the downloads of the tournées no longer in « Mes tournées ».
  /// A call made while one goes runs once more after it, so the last list
  /// is the one pruned.
  Future<void> prune() {
    if (_pruning case final running?) {
      _pruneAgain = true;
      return running;
    }
    final running = _pruning = _runPrune();
    return running;
  }

  Future<void> _runPrune() async {
    try {
      do {
        _pruneAgain = false;
        await _prune();
      } while (_pruneAgain);
    } finally {
      _pruning = null;
    }
  }
}
