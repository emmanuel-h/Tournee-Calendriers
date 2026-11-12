import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/come_backs/come_backs_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/presentation/round/given_donation.dart';
import 'package:tournee_calendriers/presentation/round/marking_access.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';
import 'package:tournee_calendriers/presentation/street/street_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/building/building_grid_sheet.dart';
import 'package:tournee_calendriers/ui/screens/come_backs/come_back_words.dart';
import 'package:tournee_calendriers/ui/screens/round/marks_only_in_round.dart';
import 'package:tournee_calendriers/ui/screens/round/round_band.dart';
import 'package:tournee_calendriers/ui/screens/street/status_picker_sheet.dart';
import 'package:tournee_calendriers/ui/screens/street/status_words.dart';
import 'package:tournee_calendriers/ui/screens/street/street_header.dart';
import 'package:tournee_calendriers/ui/screens/street/street_tiles.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Rue, the screen used 95 % of the time (PLAN §5.6,
/// `docs/mockups/Main.dc.html`): odd numbers on the left, even on the
/// right; during a tournée, a tap on a house opens its status picker, and
/// what it stores shows in the snackbar with « Annuler » for 4 s; with none
/// on, the tap says to start one (PLAN §5.14, mockup StreetIdle); during
/// one, the « En tournée » band sits above the top bar (RunStreet). A tap on
/// a building opens its Immeuble grid (PLAN §5.7). Works offline:
/// everything it reads and writes is on the phone.
///
/// Opened from « À repasser » or a reminder (PLAN §5.17, StreetRing
/// mockup), it scrolls to the house [ringAt] and rings it for a moment,
/// its come-back in the hint pill until the first tap; nothing opens. With
/// [ringDoor], the building's grid opens at that door, ringed.
final class StreetScreen extends StatelessWidget {
  const StreetScreen({
    super.key,
    required this.streetId,
    this.title,
    this.ringAt,
    this.ringDoor,
  });

  /// Which street; null when the link named none, which shows the same
  /// message as a street that is gone.
  final StreetId? streetId;

  /// The street's name as the previous screen knew it, shown until the
  /// street is read; « Rue » when not given.
  final String? title;

  /// The house to show ringed; null for none.
  final HouseNumber? ringAt;

  /// The door of the building [ringAt] to open the grid at; null for none.
  final DwellingKey? ringDoor;

  @override
  Widget build(BuildContext context) => switch (streetId) {
    final StreetId id => _MarkingScreen(
      streetId: id,
      title: title,
      ringAt: ringAt,
      ringDoor: ringDoor,
    ),
    null => _GoneScaffold(title: title),
  };
}

final class _MarkingScreen extends ConsumerStatefulWidget {
  const _MarkingScreen({
    required this.streetId,
    required this.title,
    required this.ringAt,
    required this.ringDoor,
  });

  final StreetId streetId;
  final String? title;
  final HouseNumber? ringAt;
  final DwellingKey? ringDoor;

  @override
  ConsumerState<_MarkingScreen> createState() => _MarkingScreenState();
}

/// A `State` (not a plain `ConsumerWidget`) because the screen remembers
/// whether its snackbar shows ([UndoSnackBarHost]), the tap hint taking its
/// place meanwhile, and which house's picker shows, outlined.
/// [MarksOnlyInRound] keeps the pickers for a tournée.
final class _MarkingScreenState extends ConsumerState<_MarkingScreen>
    with UndoSnackBarHost, MarksOnlyInRound {
  StreetNotifier get _notifier =>
      ref.read(streetProvider(widget.streetId).notifier);

  /// The house whose status picker shows.
  HouseNumber? _picking;

  /// The house opened from « À repasser » or a reminder: ringed, its
  /// come-back in the hint pill until the first tap; null after it.
  late HouseNumber? _ringing = widget.ringDoor == null ? widget.ringAt : null;

  /// Whether the grid of [_MarkingScreen.ringDoor] was opened already.
  var _doorShown = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // `ref.watch`: the screen redraws whenever the street or « Masquer
    // faits » changes, on this phone or on a teammate's.
    final state = ref.watch(streetProvider(widget.streetId));
    if (state is StreetShown) _showRingedDoorOnce();
    final ringHint = _ringHint(l10n);
    final marking = watchMarkingAccess();
    // `select`: built again when a tournée starts or ends, not for each don.
    final roundOn = ref.watch(
      roundProvider.select((round) => round is RoundOn),
    );
    return ScaffoldMessenger(
      key: messengerKey,
      // The top bar is laid out in the body, not as the `Scaffold`'s
      // `appBar`, so the « En tournée » band can sit above it (PLAN §5.14)
      // whatever its height with a large phone font.
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // « Voir les dons » and « Terminer » drop the snackbar first:
            // its « Annuler » names a don by its place in the tournée.
            RoundBand(onLeave: hideUndo),
            AppBar(
              // `primary`: the top bar keeps clear of the status bar,
              // unless the band above it does.
              primary: !roundOn,
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
            Expanded(
              child: SafeArea(
                top: false,
                child: switch (state) {
                  StreetLoading() => const SizedBox.shrink(),
                  StreetGone() => const _GoneMessage(),
                  StreetShown() => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StreetHeader(
                        state: state,
                        onToggleHideDone: () =>
                            unawaited(_notifier.toggleHideDone()),
                      ),
                      Expanded(
                        child: StreetTiles(
                          state: state,
                          // « Appuyez sur une maison… » only says the truth
                          // during a tournée; the come-back of the house
                          // ringed shows in any case.
                          showHint:
                              !snackBarShown &&
                              (ringHint != null ||
                                  marking == MarkingAccess.open),
                          hint: ringHint,
                          ringed: _ringing,
                          selected: _picking,
                          onTap: (number) {
                            _stopRinging();
                            if (mayMark()) unawaited(_pick(number));
                          },
                          onOpenBuilding: (number) {
                            _stopRinging();
                            _openBuilding(number);
                          },
                        ),
                      ),
                    ],
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// « N° 12 · repasser aujourd'hui vers 19 h » for the house ringed,
  /// while it still is « repasser »; null otherwise.
  String? _ringHint(AppLocalizations l10n) {
    final ringing = _ringing;
    if (ringing == null) return null;
    final row = ref
        .watch(comeBacksProvider)
        .rowAt(ComeBackPlace(street: widget.streetId, number: ringing));
    return row == null ? null : comeBackRingHint(l10n, row);
  }

  /// The first tap ends the ring and its hint.
  void _stopRinging() {
    if (_ringing != null) setState(() => _ringing = null);
  }

  /// Opens the grid at the door to ring, once the street is shown.
  void _showRingedDoorOnce() {
    final (door, number) = (widget.ringDoor, widget.ringAt);
    if (_doorShown || door == null || number == null) return;
    _doorShown = true;
    // After this frame: a sheet cannot open while the screen is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showGrid(number, ringed: door));
    });
  }

  /// A tap on a house tile: a light haptic tick at once, the tile
  /// outlined, and its status picker. The snackbar of the last change goes
  /// first: its « Annuler » would put the house back under the picker.
  ///
  /// Once the picker is closed, what it stored is said aloud for screen
  /// readers and shown in the snackbar, with « Annuler »; nothing when it
  /// stored nothing.
  Future<void> _pick(HouseNumber number) async {
    unawaited(HapticFeedback.lightImpact());
    hideUndo();
    final notifier = _notifier;
    StoredStatus? stored;
    GivenDonation? added;
    setState(() => _picking = number);
    await showHouseStatusPicker(
      context,
      (street: widget.streetId, number: number),
      onStored: (status) {
        // Kept at once: the picker may still change its day and hour.
        notifier.keepForUndo(status.change, donation: status.donation);
        stored = status;
      },
      onDonationAdded: (donation) {
        notifier.keepDonationForUndo(donation);
        added = donation;
      },
    );
    if (!mounted) return;
    setState(() => _picking = null);
    if (stored case final stored?) _tell(number, stored);
    if (added case final added?) _tellDonation(number, added);
  }

  /// Shows the don given to the house [number] already done (« N° 9 · 5 €
  /// en chèque ajouté »), with « Annuler », which takes it back. When the
  /// house took no calendar with it (changed meanwhile, #155), it says
  /// « calendrier non compté ».
  void _tellDonation(HouseNumber number, GivenDonation added) {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    final words = donationWords(l10n, added.donation);
    showUndo(
      message: added.calendarRefused
          ? l10n.houseDonationAddedNoCalendar(number.label, words)
          : l10n.houseDonationAdded(number.label, words),
      undoLabel: l10n.undo,
      onUndo: () => unawaited(notifier.undo()),
    );
  }

  /// Says what was stored on [number] aloud for screen readers
  /// (« Numéro 7, personne, 3e passage ») and shows it in the snackbar
  /// (« N° 7 : personne (3e passage) »), with « Annuler ».
  void _tell(HouseNumber number, StoredStatus stored) {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    final label = number.label;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.houseTileSemantics(
          label,
          spokenMarked(l10n, stored.status, stored.tries),
        ),
        Directionality.of(context),
      ),
    );
    showUndo(
      message: houseStoredMessage(
        l10n,
        label,
        stored.status,
        stored.tries,
        donation: stored.donation?.donation,
      ),
      undoLabel: l10n.undo,
      onUndo: () => unawaited(notifier.undo()),
    );
  }

  /// A tap on a building tile opens its grid.
  void _openBuilding(HouseNumber number) {
    hideUndo();
    unawaited(_showGrid(number));
  }

  /// The grid of the building [number]; left by « Changer en maison »
  /// (confirmed there), the building becomes a house here, with « N° 8
  /// changé en maison [Annuler] ».
  Future<void> _showGrid(HouseNumber number, {DwellingKey? ringed}) async {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    final exit = await showBuildingGrid(context, (
      street: widget.streetId,
      number: number,
    ), ringed: ringed);
    if (exit != BuildingGridExit.backToHouse || !mounted) return;
    if (await notifier.backToSingleHouse(number) && mounted) {
      showUndo(
        message: l10n.backToHouseDone(number.label),
        undoLabel: l10n.undo,
        onUndo: () => unawaited(notifier.undo()),
      );
    }
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
