import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
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
/// their requests to join until it is answered (PLAN §5.3).
///
/// The list is on the phone, read before the first frame: the open
/// tournée shows at once at launch, offline too. Only following a request
/// needs the network, and it simply waits for it.
final class MyTourneesNotifier extends Notifier<MyTourneesState> {
  /// The listener of each pending request, by tournée.
  final _requests = <TourneeId, StreamSubscription<MemberStatus?>>{};

  @override
  MyTourneesState build() {
    // Every change saved, whoever saved it: this sheet, a request answered,
    // later « Créer » and « Rejoindre ».
    final changes = ref.watch(observeMyTourneesProvider)().listen(_show);
    ref.onDispose(() {
      unawaited(changes.cancel());
      for (final request in _requests.values) {
        unawaited(request.cancel());
      }
      _requests.clear();
    });
    final mine = ref.watch(readMyTourneesProvider)();
    _followRequests(mine);
    return MyTourneesState.of(mine);
  }

  /// Opens the tournée [id] (a tap in the sheet). The new list reaches
  /// [state] through the store's changes. A tournée that cannot be opened
  /// (its request still pending, or forgotten meanwhile) leaves the open
  /// one as it is: the sheet only offers the others.
  Future<void> open(TourneeId id) async {
    await ref.read(openTourneeProvider)(id);
  }

  void _show(MyTournees mine) {
    state = MyTourneesState.of(mine);
    _followRequests(mine);
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
