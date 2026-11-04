import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/rounds.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';

/// The tournée on in the open secteur (PLAN §5.13, §5.14), for the « En
/// tournée » band, « Dons de la tournée » and « Bilan de la tournée ».
///
/// `autoDispose`: it stops following the tournée once no screen shows it;
/// Accueil, always under the others, keeps it alive while the app runs.
final roundProvider = NotifierProvider.autoDispose<RoundNotifier, RoundView>(
  RoundNotifier.new,
);

/// What « Commencer une tournée » did, for the screen to say.
enum StartOutcome {
  /// The tournée is on: the « En tournée » band shows.
  started,

  /// One is on in another secteur: one tournée at a time on a phone.
  alreadyOnElsewhere,

  /// The secteur closed, or became one the admin visits, while the tap was
  /// on its way: the button goes with the next view.
  refused,
}

/// Follows the tournée on (`WatchOpenRound`, from the phone, offline too)
/// and sends what the member does with it to the use cases: start it, add,
/// change or remove a don, validate it.
final class RoundNotifier extends Notifier<RoundView> {
  /// The tournée as last read; null while none is on here.
  Round? _round;

  /// True once the tournée has been read once.
  var _read = false;

  @override
  RoundView build() {
    _round = null;
    _read = false;
    // `ref.watch`: built again when another secteur opens, whose tournée
    // (or none) shows instead.
    final sector = ref.watch(currentSectorProvider);
    final subscription = ref.watch(watchOpenRoundProvider)(sector?.id).listen((
      round,
    ) {
      _round = round;
      _read = true;
      state = _render();
    });
    ref.onDispose(subscription.cancel);
    return _render();
  }

  RoundView _render() {
    if (!_read) return const RoundLoading();
    final round = _round;
    if (round == null) {
      final status = ref.read(currentSectorProvider)?.status;
      return RoundOff(canStart: status == MemberStatus.active);
    }
    final dons = round.donations;
    return RoundOn(
      startedAt: round.startedAt.toLocal(),
      // The clock, not `DateTime.now()`, so the tests fix the time.
      now: ref.read(clockProvider).now().toLocal(),
      housesVisited: round.housesVisited,
      totals: round.totals,
      // Newest first; each row keeps its place in the order added.
      donations: [
        for (var index = dons.length - 1; index >= 0; index--)
          DonationRow(index: index, donation: dons[index]),
      ],
    );
  }

  /// Time went by: « En tournée · 1 h 20 » and the end of the « Bilan »
  /// are read again from the clock.
  void tick() => state = _render();

  /// « Commencer une tournée »: a tournée of the open secteur starts now.
  Future<StartOutcome> start() async {
    final result = await ref.read(startRoundProvider)();
    return switch (result) {
      Ok() => StartOutcome.started,
      Err(failure: StartRoundFailure.alreadyOn) =>
        StartOutcome.alreadyOnElsewhere,
      Err(failure: StartRoundFailure.noSectorOpen) ||
      Err(failure: StartRoundFailure.notInTheTeam) => StartOutcome.refused,
    };
  }

  /// « Valider » of « Nouveau don »: [donation] joins the tournée.
  Future<void> addDonation(Donation donation) =>
      ref.read(addDonationProvider)(donation);

  /// « Valider » of « Modifier le don »: the don at [index] (its
  /// [DonationRow.index]) becomes [donation]. A don gone meanwhile is
  /// left alone: the list shows the tournée as it is.
  Future<void> changeDonation(int index, Donation donation) =>
      ref.read(changeDonationProvider)(index, donation);

  /// « Supprimer ce don »: the don at [index] (its [DonationRow.index]).
  Future<void> removeDonation(int index) =>
      ref.read(removeDonationProvider)(index);

  /// « Valider » of « Valider la tournée ? »: its summary goes to the
  /// secteur (queued offline) and the phone forgets its dons. Nothing
  /// happens when it was validated already.
  Future<void> validate() => ref.read(validateRoundProvider)();
}
