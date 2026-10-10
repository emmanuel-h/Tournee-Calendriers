import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/move_streets/move_streets_state.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';

/// The card of the start screen that offers the phone's streets to the
/// open tournée. `autoDispose`: it stops with the screen.
final moveStreetsProvider =
    NotifierProvider.autoDispose<MoveStreetsNotifier, MoveStreetsState>(
      MoveStreetsNotifier.new,
    );

/// The tournées whose card « Plus tard » put off, for as long as the app
/// runs: not `autoDispose`, and kept apart from [moveStreetsProvider],
/// whose notifier is made anew each time another tournée is opened.
final postponedMovesProvider = NotifierProvider<PostponedMoves, Set<TourneeId>>(
  PostponedMoves.new,
);

/// Remembers « Plus tard » until the next launch, in memory only.
final class PostponedMoves extends Notifier<Set<TourneeId>> {
  @override
  Set<TourneeId> build() => const {};

  /// Puts off the card of [tournee].
  void postpone(TourneeId tournee) => state = {...state, tournee};
}

/// Offers the streets kept on the phone since M1 to the open tournée and
/// moves them when asked (PLAN §5.0): `CountStreetsToMove`, then
/// `MoveStreetsIntoTournee`. Works offline: the tournée's storage sends the
/// streets when it can.
final class MoveStreetsNotifier extends Notifier<MoveStreetsState> {
  @override
  MoveStreetsState build() {
    // `ref.watch`: another tournée opened (or « Plus tard ») runs `build`
    // again, on a new notifier, which counts again.
    final tournee = ref.watch(currentTourneeProvider);
    if (tournee == null ||
        ref.watch(postponedMovesProvider).contains(tournee.id)) {
      return const NoStreetsToMove();
    }
    final count = ref.watch(countStreetsToMoveProvider);
    // This build's `ref`: Riverpod keeps the notifier but gives each build
    // a new `ref`, so this one is no longer `mounted` once another tournée
    // was opened meanwhile, and the count is not the new one's.
    final built = ref;
    unawaited(
      count(tournee.id).then(
        (streets) {
          if (built.mounted && streets > 0) state = StreetsToMove(streets);
        },
        // The tournée could not be read: no card, nothing else to do.
        onError: (Object _) {},
      ),
    );
    return const NoStreetsToMove();
  }

  /// « Les ajouter à la tournée »: moves the phone's streets into the open
  /// tournée, showing how far it went, and returns what it did for the
  /// message; null when the card was not offering them.
  ///
  /// It finishes in the tournée it started in, even if another one is
  /// opened meanwhile: the use case was taken with that tournée's streets.
  Future<MovedSummary?> move() async {
    final tournee = ref.read(currentTourneeProvider);
    final offer = state;
    if (tournee == null || offer is! StreetsToMove) return null;
    state = MovingStreets(done: 0, total: offer.count);
    // Once another tournée is opened, this `ref` is no longer `mounted`
    // (see `build`): the card is then the new tournée's.
    final started = ref;
    final moved = await ref.read(moveStreetsIntoTourneeProvider)(
      tournee.id,
      onProgress: (done, total) {
        if (started.mounted) state = MovingStreets(done: done, total: total);
      },
    );
    if (started.mounted) state = const NoStreetsToMove();
    return MovedSummary(moved: moved.moved, alreadyThere: moved.alreadyThere);
  }

  /// « Plus tard »: hides the card of the open tournée until the next
  /// launch.
  void later() {
    final tournee = ref.read(currentTourneeProvider);
    if (tournee == null) return;
    ref.read(postponedMovesProvider.notifier).postpone(tournee.id);
  }
}
