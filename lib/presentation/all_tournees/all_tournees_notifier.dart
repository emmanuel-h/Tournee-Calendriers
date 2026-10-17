import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/all_tournees/all_tournees_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// « Toutes les tournées ». `autoDispose`: each visit asks the server
/// again, so the list is never older than the screen.
final allTourneesProvider =
    NotifierProvider.autoDispose<AllTourneesNotifier, AllTourneesState>(
      AllTourneesNotifier.new,
    );

/// Lists every tournée of the app for an admin and opens the one tapped
/// (PLAN §5.12). Needs the network: the phone's copy may miss tournées.
final class AllTourneesNotifier extends Notifier<AllTourneesState> {
  /// The tournées last listed, by id, for [open].
  final _overviews = <TourneeId, TourneeOverview>{};

  @override
  AllTourneesState build() {
    // `unawaited`: `build` must return the state now, the answer sets it
    // later.
    unawaited(_load());
    return const AllTourneesLoading();
  }

  /// « Réessayer », after the server could not be reached.
  Future<void> retry() async {
    state = const AllTourneesLoading();
    await _load();
  }

  /// Opens the tournée [id] of the list: the app shows it on its normal
  /// screens, as the admin's own or as visited.
  Future<void> open(TourneeId id) async {
    final overview = _overviews[id];
    if (overview == null) return;
    await ref.read(openAsAdminProvider)(overview);
  }

  Future<void> _load() async {
    final listed = await ref.read(listAllTourneesProvider)();
    // The screen may have closed while the server answered.
    if (!ref.mounted) return;
    switch (listed) {
      case Ok(:final value):
        _overviews
          ..clear()
          ..addEntries([
            for (final overview in value) MapEntry(overview.id, overview),
          ]);
        state = AllTourneesShown.of(value);
      case Err(failure: DirectoryFailure.noNetwork):
        state = const AllTourneesOffline();
      case Err(failure: DirectoryFailure.notAdmin):
        state = const AllTourneesNotAdmin();
    }
  }
}
