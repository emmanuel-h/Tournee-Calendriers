import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';

/// Whether a tap on a house or a door may change its mark: houses are
/// marked only during a tournée (PLAN §5.14, « Marking only in a
/// tournée »). The tournée lives on the phone only, so this is an app
/// rule, not a security rule.
///
/// The street screen and the building grid show every status in any case;
/// this only decides what a tap on a house, a door or the building's
/// « Repasser » does. Changing the street itself (« Modifier la rue »,
/// « Gérer l'immeuble ») is preparation and needs no tournée.
enum MarkingAccess {
  /// A tournée is on: the status picker opens.
  open,

  /// No tournée on, and the member may start one: « Commencez une tournée
  /// pour marquer les maisons. » with « Commencer ».
  startRoundFirst,

  /// The phone may not start a tournée here (an admin visiting the
  /// secteur, PLAN §5.12): « Seuls les membres en tournée marquent les
  /// maisons. », with no action.
  membersOnly,

  /// The phone's tournée is still being read (a moment, at most): a tap
  /// does nothing rather than say something wrong.
  notYetKnown;

  /// What a tap may do while the screens show [round].
  static MarkingAccess of(RoundView round) => switch (round) {
    RoundOn() => MarkingAccess.open,
    RoundOff(canStart: true) => MarkingAccess.startRoundFirst,
    RoundOff(canStart: false) => MarkingAccess.membersOnly,
    RoundLoading() => MarkingAccess.notYetKnown,
  };
}

/// What a tap on a house or a door may do now, following the tournée of
/// the open secteur.
///
/// A plain `Provider` derived from `roundProvider`: it is computed again
/// whenever the tournée's view changes (every 30 s, for « depuis »), but the
/// screens watching it are only rebuilt when the answer itself changes.
final markingAccessProvider = Provider.autoDispose<MarkingAccess>(
  (ref) => MarkingAccess.of(ref.watch(roundProvider)),
);
