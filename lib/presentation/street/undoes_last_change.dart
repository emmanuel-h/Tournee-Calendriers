import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/round/given_donation.dart';

/// « Annuler » of the snackbar, for a notifier whose changes can be undone:
/// it keeps the last change it made ([keepForUndo]) and [undo] puts back
/// what that change replaced (`UndoLastChange`).
///
/// During a tournée the change may come with a don (« N° 7 fait · 10 € en
/// espèces »), or be a don alone (« + Ajouter un don »,
/// [keepDonationForUndo]): [undo] takes that don back out of the tournée
/// too (PLAN §5.6).
///
/// Only the last change can be undone (PLAN §5.6), and only once. The
/// notifier is `autoDispose`, so the change is forgotten with the screen.
mixin UndoesLastChange<S> on Notifier<S> {
  StreetChange? _lastChange;
  GivenDonation? _lastDonation;

  /// The `ref` of the build the change was made in. Riverpod keeps the
  /// notifier when it builds again, which happens when the street storage
  /// is replaced (another tournée opened), and gives that build a new
  /// `ref`: the old one is then no longer `mounted`.
  Ref? _keptIn;

  /// Keeps [change], and the [donation] given with it if any, for
  /// « Annuler », in place of what was kept before.
  void keepForUndo(StreetChange change, {GivenDonation? donation}) {
    _lastChange = change;
    _lastDonation = donation;
    _keptIn = ref;
  }

  /// Keeps [donation], given without changing the house (« + Ajouter un
  /// don »), for « Annuler », in place of what was kept before.
  void keepDonationForUndo(GivenDonation donation) {
    _lastChange = null;
    _lastDonation = donation;
    _keptIn = ref;
  }

  /// Puts back what the last change replaced, and takes its don out of
  /// the tournée, once. Should that be impossible (what it touched was
  /// removed since), nothing happens: the screen shows the street as it
  /// is. A change made in another tournée than the open one is not undone:
  /// the same street (moved from the phone, same id) may be in both.
  ///
  /// The don is named by its place in the tournée: the snackbar goes as
  /// soon as the member leaves for « Dons de la tournée » or taps another
  /// house, so no other don can have come or gone meanwhile.
  Future<void> undo() async {
    final change = _lastChange;
    final donation = _lastDonation;
    if (change == null && donation == null) return;
    _lastChange = null;
    _lastDonation = null;
    if (!_keptIn!.mounted) return;
    // Both read before the first `await`: the screen may go meanwhile.
    final undoChange = ref.read(undoLastChangeProvider);
    final removeDonation = ref.read(removeDonationProvider);
    if (change != null) await undoChange(change);
    if (donation != null) await removeDonation(donation.index);
  }
}
