import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/round_corrections.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
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

/// What a tap in « Touchez la maison oubliée » did (PLAN §5.20).
enum ForgottenMarkOutcome {
  /// The house or door is ✓ now, counted on the tournée.
  marked,

  /// It was ✓ or ⊘ already: « N° 9 : déjà marquée ✓. »
  alreadyVisited,

  /// Nothing is left to mark on the tournée (marked or ignored on another
  /// phone meanwhile), or it is gone.
  nothingToMark,

  /// The street, the house or the door is gone.
  houseGone,
}

/// Follows the validated tournées of the open secteur's current campaign
/// (`WatchCollecte`, from the phone's copy, offline too). Every member
/// sees them, and an admin visiting the secteur too (PLAN §5.12: they see
/// it as a member does). One of this phone the server refused may be sent
/// again or erased (PLAN §5.16); one sent may have its forgotten houses
/// marked or ignored (PLAN §5.20), « Corriger » having its own screen
/// (`correctRoundProvider`).
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

  /// « Ignorer » of « ⚠ 1 maison à marquer » of the tournée [round]: one
  /// fewer to mark, asked nothing. Nothing happens when none is left.
  Future<void> ignoreForgottenHouse(RoundId round) async {
    final place = _placeOf(round);
    if (place != null) await ref.read(ignoreForgottenHouseProvider)(place);
  }

  /// A tap on the house [number] of [street] (its door [door] in a
  /// building) in « Touchez la maison oubliée » for the tournée [round]:
  /// marked ✓ with no tournée on, counted on [round].
  Future<ForgottenMarkOutcome> markForgottenHouse(
    RoundId round, {
    required StreetId street,
    required HouseNumber number,
    DwellingKey? door,
  }) async {
    final place = _placeOf(round);
    if (place == null) return ForgottenMarkOutcome.nothingToMark;
    final marked = await ref.read(markForgottenHouseProvider)(place, (
      street: street,
      number: number,
      door: door,
    ));
    return switch (marked) {
      Ok() => ForgottenMarkOutcome.marked,
      Err(failure: MarkForgottenFailure.alreadyVisited) =>
        ForgottenMarkOutcome.alreadyVisited,
      Err(failure: MarkForgottenFailure.nothingToMark) =>
        ForgottenMarkOutcome.nothingToMark,
      Err(failure: MarkForgottenFailure.houseGone) =>
        ForgottenMarkOutcome.houseGone,
    };
  }

  /// The tournée [round] of the open secteur's current campaign; null when
  /// no secteur is open.
  RoundPlace? _placeOf(RoundId round) {
    final sector = ref.read(currentSectorProvider);
    if (sector == null) return null;
    return (sector: sector.id, campaign: sector.campaign, round: round);
  }
}
