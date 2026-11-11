import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_view.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';

/// « Collecte 2026 » of the open secteur (PLAN §5.13), for Équipe's row
/// and the Collecte screen.
///
/// `autoDispose`: it follows the ledger only while Secteur (or the Collecte
/// screen over it) shows, unlike the team, whose dot on Accueil's title
/// is needed on Accueil too.
final collecteProvider =
    NotifierProvider.autoDispose<CollecteNotifier, CollecteView>(
      CollecteNotifier.new,
    );

/// Follows the validated tournées of the open secteur's current campaign
/// (`WatchCollecte`, from the phone's copy, offline too). Every member
/// sees them, and an admin visiting the secteur too (PLAN §5.12: they see
/// it as a member does). A validated tournée is never changed; one of this
/// phone the server refused may be sent again or erased (PLAN §5.16).
final class CollecteNotifier extends Notifier<CollecteView> {
  @override
  CollecteView build() {
    // `ref.watch`: built again when another secteur opens (or none), which
    // stops following the old one (`onDispose`).
    final sector = ref.watch(currentSectorProvider);
    if (sector == null) return const CollecteUnavailable();
    final listening = ref
        .watch(watchCollecteProvider)(sector.id, sector.campaign)
        .listen(
          (collecte) => state = CollecteShown.of(
            collecte,
            number: sector.number.value,
            campaign: sector.campaign.value,
          ),
          // Whatever the reason, the screen can only say it cannot show it.
          onError: (Object _) => state = const CollecteUnavailable(),
        );
    ref.onDispose(listening.cancel);
    return const CollecteLoading();
  }

  /// « Réessayer » of a tournée the server refused: it waits to be sent
  /// again.
  Future<void> retry(RoundId id) => ref.read(retryUnsentRoundProvider)(id);

  /// « Effacer » of a tournée the server refused, once confirmed: the
  /// phone forgets it.
  Future<void> erase(RoundId id) => ref.read(eraseUnsentRoundProvider)(id);
}
