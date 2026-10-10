import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/pending_sync/pending_sync_state.dart';

/// The line « ☁ Modifications de 3 rues en attente d'envoi » of the start
/// screen. `autoDispose`: it stops following the count with the screen.
final pendingSyncIndicatorProvider =
    NotifierProvider.autoDispose<PendingSyncNotifier, PendingSyncState>(
      PendingSyncNotifier.new,
    );

/// Follows how many streets hold changes the server has not received yet
/// (`ObservePendingSync`). Works offline, which is when the line shows.
final class PendingSyncNotifier extends Notifier<PendingSyncState> {
  @override
  PendingSyncState build() {
    // `ref.watch` on the use case: when another tournée is opened (or
    // none), the composition root binds another pending sync, so this
    // notifier is built again and follows the new one; the old
    // subscription is cancelled first (`onDispose`).
    final subscription = ref
        .watch(observePendingSyncProvider)()
        .listen(
          (streets) =>
              state = streets == 0 ? const AllSent() : ChangesWaiting(streets),
          // The streets can no longer be read (the member left the
          // tournée): nothing this phone can still send there.
          onError: (Object _) => state = const AllSent(),
        );
    ref.onDispose(subscription.cancel);
    // Until the first count arrives, nothing is said: a line that flashes
    // at each launch would worry for nothing.
    return const AllSent();
  }
}
