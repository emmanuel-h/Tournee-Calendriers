import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/street/street_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/building/building_grid_sheet.dart';
import 'package:tournee_calendriers/ui/screens/building/building_setup_sheet.dart';
import 'package:tournee_calendriers/ui/screens/building/door_sheets.dart';
import 'package:tournee_calendriers/ui/screens/street/house_sheet.dart';
import 'package:tournee_calendriers/ui/screens/street/status_words.dart';
import 'package:tournee_calendriers/ui/screens/street/street_header.dart';
import 'package:tournee_calendriers/ui/screens/street/street_tiles.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Rue, the screen used 95 % of the time (PLAN §5.6,
/// `docs/mockups/Main.dc.html`): odd numbers on the left, even on the
/// right; a tap cycles a house `○ → ✓ → ✗ → ○` with « Annuler » for 4 s.
/// Works offline: everything it reads and writes is on the phone.
///
/// A hold on a house opens its Fiche maison (PLAN §5.7); a tap on a
/// building opens its Immeuble grid, a hold its own « repasser ».
final class StreetScreen extends StatelessWidget {
  const StreetScreen({super.key, required this.streetId, this.title});

  /// Which street; null when the link named none, which shows the same
  /// message as a street that is gone.
  final StreetId? streetId;

  /// The street's name as the previous screen knew it, shown until the
  /// street is read; « Rue » when not given.
  final String? title;

  @override
  Widget build(BuildContext context) => switch (streetId) {
    final StreetId id => _MarkingScreen(streetId: id, title: title),
    null => _GoneScaffold(title: title),
  };
}

final class _MarkingScreen extends ConsumerStatefulWidget {
  const _MarkingScreen({required this.streetId, required this.title});

  final StreetId streetId;
  final String? title;

  @override
  ConsumerState<_MarkingScreen> createState() => _MarkingScreenState();
}

/// A `State` (not a plain `ConsumerWidget`) because the screen remembers
/// whether its snackbar shows ([UndoSnackBarHost]): the tap hint takes its
/// place meanwhile.
final class _MarkingScreenState extends ConsumerState<_MarkingScreen>
    with UndoSnackBarHost {
  StreetNotifier get _notifier =>
      ref.read(streetProvider(widget.streetId).notifier);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // `ref.watch`: the screen redraws whenever the street or « Masquer
    // faits » changes, on this phone or (from M2) on a teammate's.
    final state = ref.watch(streetProvider(widget.streetId));
    return ScaffoldMessenger(
      key: messengerKey,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 4,
          title: Text(switch (state) {
            StreetShown(:final name) => name,
            StreetLoading() ||
            StreetGone() => widget.title ?? l10n.screenStreet,
          }),
          actions: [
            if (state is StreetShown)
              IconButton(
                key: const Key('street.edit'),
                tooltip: l10n.editStreetAction,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push(AppRoutes.editStreetOf(widget.streetId)),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: switch (state) {
            StreetLoading() => const SizedBox.shrink(),
            StreetGone() => const _GoneMessage(),
            StreetShown() => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreetHeader(
                  state: state,
                  onToggleHideDone: () => unawaited(_notifier.toggleHideDone()),
                ),
                Expanded(
                  child: StreetTiles(
                    state: state,
                    showHint: !snackBarShown,
                    onTap: _cycle,
                    onHold: _openSheet,
                    onOpenBuilding: _openBuilding,
                    onHoldBuilding: _openBuildingDetails,
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }

  /// A tap on a house tile: a light haptic tick at once, then the new
  /// status, said aloud for screen readers and shown in the snackbar.
  Future<void> _cycle(HouseNumber number) async {
    unawaited(HapticFeedback.lightImpact());
    // Read now: after the `await`, this context may be gone.
    final l10n = AppLocalizations.of(context);
    final view = View.of(context);
    final direction = Directionality.of(context);
    final notifier = _notifier;

    final marked = await notifier.cycle(number);
    if (marked == null || !mounted) return;

    final label = marked.number.label;
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        l10n.houseTileSemantics(label, spokenStatus(l10n, marked.status)),
        direction,
      ),
    );
    showUndo(
      message: l10n.houseMarked(label, statusName(l10n, marked.status)),
      undoLabel: l10n.undo,
      onUndo: () => unawaited(notifier.undo()),
    );
  }

  /// A hold on a house tile opens its sheet. The snackbar of the last tap
  /// goes: its « Annuler » would put the whole house back as it was before
  /// that tap, wiping what the sheet changes.
  ///
  /// Left by « Transformer en immeuble… », the sheet gives way to
  /// « Décrire l'immeuble », then, once validated, to the new building's
  /// grid: one sheet at a time.
  Future<void> _openSheet(HouseNumber number) async {
    hideUndo();
    final house = (street: widget.streetId, number: number);
    final exit = await showHouseSheet(context, house);
    if (exit != HouseSheetExit.toBuilding || !mounted) return;
    final laidOut = await showBuildingSetup(context, house);
    if (!laidOut || !mounted) return;
    await _showGrid(number);
  }

  /// A tap on a building tile opens its grid.
  void _openBuilding(HouseNumber number) {
    hideUndo();
    unawaited(_showGrid(number));
  }

  /// The grid of the building [number]; left by « Changer en maison »
  /// (confirmed there), the building becomes a house here, with « N° 8
  /// changé en maison [Annuler] ».
  Future<void> _showGrid(HouseNumber number) async {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    final exit = await showBuildingGrid(context, (
      street: widget.streetId,
      number: number,
    ));
    if (exit != BuildingGridExit.backToHouse || !mounted) return;
    if (await notifier.backToSingleHouse(number) && mounted) {
      showUndo(
        message: l10n.backToHouseDone(number.label),
        undoLabel: l10n.undo,
        onUndo: () => unawaited(notifier.undo()),
      );
    }
  }

  /// A hold on a building tile opens its own « repasser ».
  void _openBuildingDetails(HouseNumber number) {
    hideUndo();
    unawaited(
      showBuildingDetailsSheet(context, (
        street: widget.streetId,
        number: number,
      )),
    );
  }
}

/// The screen of a link that names no street.
final class _GoneScaffold extends StatelessWidget {
  const _GoneScaffold({required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 4,
      title: Text(title ?? AppLocalizations.of(context).screenStreet),
    ),
    body: const _GoneMessage(),
  );
}

/// « Cette rue n'est plus sur ce téléphone. »: the street is not on the
/// phone, or went to the Corbeille. The app bar's arrow leads back.
final class _GoneMessage extends StatelessWidget {
  const _GoneMessage();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        AppLocalizations.of(context).streetGone,
        key: const Key('street.gone'),
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.of(context).muted),
      ),
    ),
  );
}
