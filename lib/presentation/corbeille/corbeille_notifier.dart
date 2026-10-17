import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
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
///
/// Someone no longer in the team is asked about once: an admin of the app
/// who is not in it reads « un administrateur » (PLAN §5.12).
final class CorbeilleNotifier extends Notifier<CorbeilleState> {
  /// What each one asked about turned out to be: admin or not. A notifier
  /// is kept when it builds again (only its `ref` is new), so the answers
  /// stay while the Corbeille is shown.
  final _admins = <MemberId, bool>{};

  @override
  CorbeilleState build() {
    final read = ref.watch(corbeilleItemsProvider);
    // `.value`: the items once read, null before (or should the storage
    // fail). While another tournée's streets load, `.value` still holds
    // the old tournée's items (`isLoading` is true then): not shown.
    final items = read.value;
    if (items == null || read.isLoading) return CorbeilleState.waiting;
    final team = ref.watch(teamProvider);
    final now = ref.read(clockProvider).now();
    return CorbeilleState(
      loading: false,
      rows: [
        for (final item in items)
          switch (team) {
            TeamShown() => _row(item, team.nameOf(item.removal.by), now),
            NoTeam() || TeamLoading() || TeamUnavailable() => CorbeilleRow(
              item: item,
              removedBy: null,
              removedAt: RecentTime.of(item.removal.at, now: now),
            ),
          },
      ],
    );
  }

  /// [item] deleted by a member named [name], or by someone no longer in
  /// the team (unnamed) when it is null: whether they are an admin is
  /// asked once, and the Corbeille shown again with the answer.
  CorbeilleRow _row(CorbeilleItem item, String? name, DateTime now) {
    final by = item.removal.by;
    if (name == null && !_admins.containsKey(by)) {
      // Not asked twice while the answer is on its way.
      _admins[by] = false;
      unawaited(
        ref.read(isMemberAdminProvider)(by).then((isAdmin) {
          _admins[by] = isAdmin;
          if (ref.mounted && isAdmin) ref.invalidateSelf();
        }),
      );
    }
    return CorbeilleRow(
      item: item,
      removedBy: name,
      removedAt: RecentTime.of(item.removal.at, now: now),
      removedByAdmin: name == null && (_admins[by] ?? false),
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
