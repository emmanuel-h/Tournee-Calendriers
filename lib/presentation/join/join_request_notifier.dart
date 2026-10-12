import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/choose_start_point.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/join/join_request_state.dart';
import 'package:tournee_calendriers/presentation/launch/launch_place.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_state.dart';

/// « Demande envoyée » for one request (`family`: one per tournée;
/// `autoDispose`: it stops with the screen).
final joinRequestProvider = NotifierProvider.autoDispose
    .family<JoinRequestNotifier, JoinRequestState, TourneeId>(
      JoinRequestNotifier.new,
    );

/// Follows the member's request to join [tournee] until it is answered
/// (PLAN §5.2): accepted, the tournée is opened and the start screen shows
/// it; refused or cancelled, the app goes back to « Bienvenue » or to its
/// start screen.
///
/// The request itself is followed by « Mes tournées » (`myTourneesProvider`,
/// kept alive), which settles it on the phone when the server answers; this
/// screen only watches that. Offline, nothing comes: the request stays
/// pending, at every launch too.
final class JoinRequestNotifier extends Notifier<JoinRequestState> {
  JoinRequestNotifier(this.tournee);

  final TourneeId tournee;

  /// « Annuler la demande » was pressed: the request going away is not a
  /// refusal.
  var _cancelled = false;

  /// The request was answered (or found gone): what follows is under way.
  var _settled = false;

  /// Whether the phone has a start screen to go back to.
  var _canLeave = false;

  @override
  JoinRequestState build() {
    ref.listen(myTourneesProvider, (_, mine) => _follow(mine));
    unawaited(_findWayOut());
    final mine = ref.read(myTourneesProvider);
    if (_rowIn(mine) case TourneeRow(
      status: TourneeRowStatus.pending,
      :final number,
      :final centre,
    )) {
      return RequestWaiting(number: number, centre: centre, canLeave: false);
    }
    // Answered before the screen opened.
    _follow(mine, whileShown: false);
    return const RequestUnknown();
  }

  /// « Annuler la demande »: withdraws the request and forgets it on the
  /// phone; works offline.
  Future<void> cancel() async {
    _cancelled = true;
    await ref.read(cancelJoinRequestProvider)(tournee);
  }

  TourneeRow? _rowIn(MyTourneesState mine) {
    for (final row in mine.rows) {
      if (row.id == tournee) return row;
    }
    return null;
  }

  /// Acts on where the request stands in [mine]. A request gone
  /// [whileShown] was refused, unless « Annuler » was pressed; one already
  /// gone when the screen opened is not said to be refused: nobody knows.
  void _follow(MyTourneesState mine, {bool whileShown = true}) {
    if (_settled || !ref.mounted) return;
    switch (_rowIn(mine)) {
      case TourneeRow(
        status: TourneeRowStatus.pending,
        :final number,
        :final centre,
      ):
        state = RequestWaiting(
          number: number,
          centre: centre,
          canLeave: _canLeave,
        );
        // Another tournée opened, streets moved…: a way out may have come.
        unawaited(_findWayOut());
      // Acted on after this turn: opening saves « Mes tournées » again,
      // which must not happen while the store is still telling its last
      // change.
      case TourneeRow():
        _settled = true;
        scheduleMicrotask(() => unawaited(_open()));
      case null:
        _settled = true;
        final refused = whileShown && !_cancelled;
        scheduleMicrotask(() => unawaited(_close(refused: refused)));
    }
  }

  /// Accepted: opens the tournée, which the start screen then shows.
  Future<void> _open() async {
    if (!ref.mounted) return;
    await ref.read(openTourneeProvider)(tournee);
    if (ref.mounted) state = const RequestAccepted();
  }

  Future<void> _close({required bool refused}) async {
    if (!ref.mounted) return;
    final next = await ref.read(chooseStartPointProvider)();
    if (!ref.mounted) return;
    state = RequestClosed(refused: refused, next: launchPlaceOf(next));
  }

  /// Whether a back arrow may lead to the start screen.
  Future<void> _findWayOut() async {
    final start = await ref.read(chooseStartPointProvider)();
    if (!ref.mounted) return;
    _canLeave = start is StartOnStreets;
    if (state case final RequestWaiting waiting) {
      state = waiting.withCanLeave(_canLeave);
    }
  }
}
