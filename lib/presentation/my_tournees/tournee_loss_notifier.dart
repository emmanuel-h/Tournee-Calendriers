import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_loss.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/tournee_loss_notice.dart';

/// The last tournée the member lost, for the whole app. Not `autoDispose`:
/// the member may be removed whatever screen is shown, so the app listens
/// to it from its root as long as it runs.
final tourneeLossProvider =
    NotifierProvider<TourneeLossNotifier, TourneeLossNotice?>(
      TourneeLossNotifier.new,
    );

/// Follows whether the member is still in each of their tournées (PLAN
/// §5.3, §5.8). When the server says they were removed, or the tournée
/// deleted, the phone forgets it (none open any more if it was the open
/// one) and [state] tells it, for the app to say so over the next screen.
///
/// Null until a tournée is lost. Offline the server says nothing, so no
/// tournée is ever forgotten without the network (PLAN §7).
final class TourneeLossNotifier extends Notifier<TourneeLossNotice?> {
  /// The listener of each tournée the member is in, by tournée.
  final _memberships = <TourneeId, StreamSubscription<TourneeLoss>>{};

  @override
  TourneeLossNotice? build() {
    // Every change of « Mes tournées »: a request accepted adds a tournée
    // to follow, a tournée left or lost removes one.
    final changes = ref.watch(observeMyTourneesProvider)().listen(_follow);
    ref.onDispose(() {
      unawaited(changes.cancel());
      for (final membership in _memberships.values) {
        unawaited(membership.cancel());
      }
      _memberships.clear();
    });
    _follow(ref.watch(readMyTourneesProvider)());
    return null;
  }

  /// Listens once to each tournée of [mine] the member is in (a request
  /// is followed by « Mes tournées » until it is answered), and stops
  /// listening to the others.
  void _follow(MyTournees mine) {
    final kept = {
      for (final tournee in mine.tournees)
        if (!tournee.isPending) tournee.id: tournee,
    };
    for (final id in _memberships.keys.toList()) {
      if (!kept.containsKey(id)) unawaited(_memberships.remove(id)!.cancel());
    }
    for (final MapEntry(key: id, value: tournee) in kept.entries) {
      _memberships.putIfAbsent(
        id,
        () => ref
            .read(watchMembershipProvider)(tournee)
            .listen(
              (loss) => unawaited(_forget(id, loss)),
              // A listener that fails (a server error) keeps the tournée:
              // only the server's answer may make the phone forget it.
              onError: (Object _) {},
            ),
      );
    }
  }

  Future<void> _forget(TourneeId id, TourneeLoss loss) async {
    final lost = await ref.read(forgetLostTourneeProvider)(id, loss);
    // Gone already (left meanwhile), or the app went away while the phone
    // forgot it: nothing to tell.
    if (lost == null || !ref.mounted) return;
    state = TourneeLossNotice(
      tournee: lost.tournee.id,
      number: lost.tournee.number.value,
      loss: lost.loss,
      wasOpen: lost.wasOpen,
    );
  }
}
