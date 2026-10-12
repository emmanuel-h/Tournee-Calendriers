import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_state.dart';

/// « Mes tournées » for the whole app. Not `autoDispose`: the open
/// tournée is needed by every screen, and the member's requests are
/// followed as long as the app runs, not only while the sheet is shown.
final myTourneesProvider =
    NotifierProvider<MyTourneesNotifier, MyTourneesState>(
      MyTourneesNotifier.new,
    );

/// The tournée the app shows, null when none is open: what the screens of
/// a tournée (the team, its streets) follow. `select` rebuilds the screens
/// that watch it only when the open tournée changes, not when a request
/// elsewhere is answered.
final currentTourneeProvider = Provider<TourneeSummary?>(
  (ref) => ref.watch(myTourneesProvider.select((state) => state.current)),
);

/// Shows the member's tournées and opens the one they tap; follows each of
/// their requests to join until it is answered, and the requests waiting
/// in their tournées not open (PLAN §5.3).
///
/// The list is on the phone, read before the first frame: the open
/// tournée shows at once at launch, offline too. Only following a request
/// needs the network, and it simply waits for it; the teams are read from
/// the phone's copy first.
final class MyTourneesNotifier extends Notifier<MyTourneesState> {
  /// The listener of each pending request, by tournée.
  final _requests = <TourneeId, StreamSubscription<MemberStatus?>>{};

  /// The listener of the team of each tournée not open, by tournée.
  final _teams = <TourneeId, StreamSubscription<Tournee?>>{};

  /// The requests waiting in each tournée followed in [_teams].
  final _waiting = <TourneeId, int>{};

  /// The list last shown, which a team's change shows again.
  var _mine = MyTournees.none;

  @override
  MyTourneesState build() {
    // Every change saved, whoever saved it: this sheet, a request answered,
    // later « Créer » and « Rejoindre ».
    final changes = ref.watch(observeMyTourneesProvider)().listen(_show);
    ref.onDispose(() {
      unawaited(changes.cancel());
      for (final listener in [..._requests.values, ..._teams.values]) {
        unawaited(listener.cancel());
      }
      _requests.clear();
      _teams.clear();
      _waiting.clear();
    });
    _mine = ref.watch(readMyTourneesProvider)();
    _followRequests(_mine);
    _followTeams(_mine);
    return MyTourneesState.of(_mine, waiting: _waiting);
  }

  /// Opens the tournée [id] (a tap in the sheet). The new list reaches
  /// [state] through the store's changes. A tournée that cannot be opened
  /// (its request still pending, or forgotten meanwhile) leaves the open
  /// one as it is: the sheet only offers the others.
  Future<void> open(TourneeId id) async {
    await ref.read(openTourneeProvider)(id);
  }

  void _show(MyTournees mine) {
    _mine = mine;
    _followRequests(mine);
    _followTeams(mine);
    state = MyTourneesState.of(mine, waiting: _waiting);
  }

  /// Follows the team of each tournée of [mine] that the member is in and
  /// that is not open, for the dot of a request waiting there; the open
  /// one's requests show on 👥 (`teamProvider`).
  void _followTeams(MyTournees mine) {
    final others = {
      for (final tournee in mine.tournees)
        if (!tournee.isPending && tournee.id != mine.currentId) tournee.id,
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
              (tournee) => _count(id, tournee?.pendingMembers.length ?? 0),
              // A team that cannot be followed shows no dot: the requests
              // are seen once it is opened.
              onError: (Object _) => _count(id, 0),
            ),
      );
    }
  }

  void _count(TourneeId id, int waiting) {
    _waiting[id] = waiting;
    state = MyTourneesState.of(_mine, waiting: _waiting);
  }

  /// Listens to each pending request of [mine] once, and stops listening
  /// to the ones that are not pending any more.
  void _followRequests(MyTournees mine) {
    final pending = {
      for (final tournee in mine.tournees)
        if (tournee.isPending) tournee.id,
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
