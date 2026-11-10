import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_state.dart';

/// « Mes secteurs » for the whole app. Not `autoDispose`: the open
/// tournée is needed by every screen, and the member's requests are
/// followed as long as the app runs, not only while the sheet is shown.
final mySectorsProvider = NotifierProvider<MySectorsNotifier, MySectorsState>(
  MySectorsNotifier.new,
);

/// The tournée the app shows, null when none is open: what the screens of
/// a tournée (the team, its streets) follow. `select` rebuilds the screens
/// that watch it only when the open tournée changes, not when a request
/// elsewhere is answered.
final currentSectorProvider = Provider<SectorSummary?>(
  (ref) => ref.watch(mySectorsProvider.select((state) => state.current)),
);

/// Shows the member's tournées and opens the one they tap; follows each of
/// their requests to join until it is answered, and the requests waiting
/// in their tournées not open (PLAN §5.3).
///
/// The list is on the phone, read before the first frame: the open
/// tournée shows at once at launch, offline too. Only following a request
/// needs the network, and it simply waits for it; the teams are read from
/// the phone's copy first.
final class MySectorsNotifier extends Notifier<MySectorsState> {
  /// The listener of each pending request, by tournée.
  final _requests = <SectorId, StreamSubscription<MemberStatus?>>{};

  /// The listener of the team of each tournée not open, by tournée.
  final _teams = <SectorId, StreamSubscription<Sector?>>{};

  /// The requests waiting in each tournée followed in [_teams].
  final _waiting = <SectorId, int>{};

  /// The list last shown, which a team's change shows again.
  var _mine = MySectors.none;

  @override
  MySectorsState build() {
    // Every change saved, whoever saved it: this sheet, a request answered,
    // later « Créer » and « Rejoindre ».
    final changes = ref.watch(observeMySectorsProvider)().listen(_show);
    ref.onDispose(() {
      unawaited(changes.cancel());
      for (final listener in [..._requests.values, ..._teams.values]) {
        unawaited(listener.cancel());
      }
      _requests.clear();
      _teams.clear();
      _waiting.clear();
    });
    _mine = ref.watch(readMySectorsProvider)();
    _followRequests(_mine);
    _followTeams(_mine);
    return MySectorsState.of(_mine, waiting: _waiting);
  }

  /// Opens the tournée [id] (a tap in the sheet). The new list reaches
  /// [state] through the store's changes. A tournée that cannot be opened
  /// (its request still pending, or forgotten meanwhile) leaves the open
  /// one as it is: the sheet only offers the others.
  Future<void> open(SectorId id) async {
    await ref.read(openSectorProvider)(id);
  }

  void _show(MySectors mine) {
    _mine = mine;
    _followRequests(mine);
    _followTeams(mine);
    state = MySectorsState.of(mine, waiting: _waiting);
  }

  /// Follows the team of each tournée of [mine] that the member is in and
  /// that is not open, for the dot of a request waiting there; the open
  /// one's requests show on Accueil's title (`teamProvider`).
  void _followTeams(MySectors mine) {
    final others = {
      for (final sector in mine.sectors)
        if (!sector.isPending && sector.id != mine.currentId) sector.id,
    };
    for (final id in _teams.keys.toList()) {
      if (!others.contains(id)) {
        unawaited(_teams.remove(id)!.cancel());
        _waiting.remove(id);
      }
    }
    for (final id in others) {
      _teams.putIfAbsent(
        id,
        () => ref
            .read(observeTeamProvider)(id)
            .listen(
              (sector) => _count(id, sector?.pendingMembers.length ?? 0),
              // A team that cannot be followed shows no dot: the requests
              // are seen once it is opened.
              onError: (Object _) => _count(id, 0),
            ),
      );
    }
  }

  void _count(SectorId id, int waiting) {
    _waiting[id] = waiting;
    state = MySectorsState.of(_mine, waiting: _waiting);
  }

  /// Listens to each pending request of [mine] once, and stops listening
  /// to the ones that are not pending any more.
  void _followRequests(MySectors mine) {
    final pending = {
      for (final sector in mine.sectors)
        if (sector.isPending) sector.id,
    };
    for (final id in _requests.keys.toList()) {
      if (!pending.contains(id)) unawaited(_requests.remove(id)!.cancel());
    }
    for (final id in pending) {
      _requests.putIfAbsent(
        id,
        () => ref
            .read(watchJoinRequestProvider)(id)
            .listen(
              (status) =>
                  unawaited(ref.read(settleJoinRequestProvider)(id, status)),
              // A listener that fails (offline for long, a server error)
              // leaves the request pending; the next launch asks again.
              onError: (Object _) {},
            ),
      );
    }
  }
}
