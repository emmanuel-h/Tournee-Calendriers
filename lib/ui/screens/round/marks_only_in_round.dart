import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/round/marking_access.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// Houses are marked only during a tournée (PLAN §5.14, mockup
/// StreetIdle): shared by the street screen and the building grid, which
/// both show their marks in any case but open a status picker only while a
/// tournée is on.
///
/// A `mixin ... on` two types: it can only be added to a `ConsumerState`
/// that already has [UndoSnackBarHost] (`with UndoSnackBarHost,
/// MarksOnlyInRound`), whose snackbar it uses.
mixin MarksOnlyInRound<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, UndoSnackBarHost<T> {
  /// What a tap on a house or a door may do now. `ref.watch` in `build`:
  /// the screen redraws when a tournée starts or ends (the tap hint shows
  /// only during one).
  MarkingAccess watchMarkingAccess() => ref.watch(markingAccessProvider);

  /// Whether a tap may open a status picker now. When it may not, says why
  /// in the snackbar: « Commencez une tournée pour marquer les maisons. »
  /// with « Commencer » for a member, « Seuls les membres en tournée
  /// marquent les maisons. » for an admin visiting the secteur.
  bool mayMark() {
    final l10n = AppLocalizations.of(context);
    // `ref.read`: only the answer at the moment of the tap matters here.
    switch (ref.read(markingAccessProvider)) {
      case MarkingAccess.open:
        return true;
      case MarkingAccess.startRoundFirst:
        showAction(
          message: l10n.markingNeedsRound,
          actionLabel: l10n.markingStartRound,
          onAction: () => unawaited(_startRound()),
        );
      case MarkingAccess.membersOnly:
        showMessage(l10n.markingMembersOnly);
      case MarkingAccess.notYetKnown:
        break;
    }
    return false;
  }

  /// « Commencer »: the tournée starts as with Accueil's button (offline
  /// too) and the screen stays; the next tap opens the picker. One
  /// tournée at a time on a phone: refused while one is on in another
  /// secteur.
  Future<void> _startRound() async {
    final message = AppLocalizations.of(context).roundAlreadyOnElsewhere;
    final outcome = await ref.read(roundProvider.notifier).start();
    if (!mounted) return;
    switch (outcome) {
      case StartOutcome.alreadyOnElsewhere:
        showMessage(message);
      case StartOutcome.started || StartOutcome.refused:
        break;
    }
  }
}
