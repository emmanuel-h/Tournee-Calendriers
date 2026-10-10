import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/domain/street/corbeille.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/shared/recent_time.dart';
import 'package:tournee_calendriers/presentation/team/team_notifier.dart';
import 'package:tournee_calendriers/presentation/team/team_state.dart';

/// The Corbeille's items as the streets give them, live.
///
/// A `StreamProvider` listens to a stream and holds its latest value as an
/// `AsyncValue` (loading, data or error), and stops listening when nobody
/// reads it any more (`autoDispose`). Kept apart from [corbeilleProvider]
/// so that naming the members again (the team changed) does not listen to
/// the streets again.
final corbeilleItemsProvider = StreamProvider.autoDispose<List<CorbeilleItem>>(
  (ref) => ref.watch(observeCorbeilleProvider)(),
);

/// The Corbeille while Équipe or the Corbeille is shown (`autoDispose`).
final corbeilleProvider =
    NotifierProvider.autoDispose<CorbeilleNotifier, CorbeilleState>(
      CorbeilleNotifier.new,
    );

/// Shows the Corbeille (PLAN §5.11) with who deleted each item and when,
/// and brings an item back. Works offline, with whichever street storage
/// is bound.
final class CorbeilleNotifier extends Notifier<CorbeilleState> {
  @override
  CorbeilleState build() {
    // `.value`: the items once read, null while loading (or should the
    // storage fail, which the phone storage only does with a bug).
    final items = ref.watch(corbeilleItemsProvider).value;
    if (items == null) return CorbeilleState.waiting;
    final team = ref.watch(teamProvider);
    final now = ref.read(clockProvider).now();
    return CorbeilleState(
      loading: false,
      rows: [
        for (final item in items)
          CorbeilleRow(
            item: item,
            // Removed members keep their deletions, unnamed.
            removedBy: switch (team) {
              TeamShown() => team.nameOf(item.removal.by),
              NoTeam() || TeamLoading() || TeamUnavailable() => null,
            },
            removedAt: RecentTime.of(item.removal.at, now: now),
          ),
      ],
    );
  }

  /// « Restaurer »: the street or number is shown again with its marks;
  /// the new Corbeille reaches [state] through the streets. A teammate who
  /// restored it first leaves nothing to do.
  Future<void> restore(CorbeilleRow row) async {
    final item = row.item;
    await ref.read(editStreetNumbersProvider)(item.streetId, switch (item) {
      DeletedStreet() => const RestoreStreet(),
      RemovedNumber(:final number) => RestoreNumber(number),
    });
  }
}
