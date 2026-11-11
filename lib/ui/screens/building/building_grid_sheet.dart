import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_state.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/presentation/round/given_donation.dart';
import 'package:tournee_calendriers/presentation/round/marking_access.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/calendars_badge.dart';
import 'package:tournee_calendriers/ui/components/close_icon_button.dart';
import 'package:tournee_calendriers/ui/components/confirm_dialog.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/components/tries_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/building/building_details_sheet.dart';
import 'package:tournee_calendriers/ui/screens/building/building_menu_sheet.dart';
import 'package:tournee_calendriers/ui/screens/building/building_setup_sheet.dart';
import 'package:tournee_calendriers/ui/screens/building/door_status_picker.dart';
import 'package:tournee_calendriers/ui/screens/building/floor_names.dart';
import 'package:tournee_calendriers/ui/screens/round/marks_only_in_round.dart';
import 'package:tournee_calendriers/ui/screens/round/round_band.dart';
import 'package:tournee_calendriers/ui/screens/street/status_words.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// How the grid was left, when its opener has something to do next.
enum BuildingGridExit {
  /// « Changer en maison », confirmed when doors had marks: the opener
  /// turns the building back into a house and offers « Annuler ».
  backToHouse,
}

/// Opens the Immeuble grid of [building] (tap a building tile, or
/// « Ouvrir l'immeuble » in edit mode; PLAN §5.7,
/// `docs/mockups/Building.dc.html`). Returns what to do next, or null.
Future<BuildingGridExit?> showBuildingGrid(
  BuildContext context,
  BuildingGridKey building,
) => showAppBottomSheet<BuildingGridExit>(
  context: context,
  builder: (_) => BuildingGridSheet(building: building),
);

/// The floors of one staircase from the top down, four doors a row; during
/// a tournée, a tap on a door opens its status picker (PLAN §5.6), and what
/// it stores shows in the snackbar with « Annuler » for 4 s; with none on,
/// the grid is read-only as the street is (PLAN §5.14), and the « En
/// tournée » band shows above the header during one. The header counts
/// the doors of the whole building; the staircase control shows when there
/// are several.
/// « Gérer l'immeuble » holds every change to the building itself. Works
/// offline.
///
/// The sheet has its own `ScaffoldMessenger`, like the street screen: the
/// snackbar of a door, and its « Annuler », goes away with the grid.
final class BuildingGridSheet extends ConsumerStatefulWidget {
  const BuildingGridSheet({super.key, required this.building});

  final BuildingGridKey building;

  @override
  ConsumerState<BuildingGridSheet> createState() => _BuildingGridSheetState();
}

final class _BuildingGridSheetState extends ConsumerState<BuildingGridSheet>
    with UndoSnackBarHost, MarksOnlyInRound {
  BuildingGridNotifier get _notifier =>
      ref.read(buildingGridProvider(widget.building).notifier);

  /// The door whose status picker shows, outlined.
  DwellingKey? _picking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(buildingGridProvider(widget.building));
    final marking = watchMarkingAccess();
    // Full height but a strip at the top, where the street stays visible.
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: constraints.maxHeight - AppSizes.fullSheetTopGap,
        child: ScaffoldMessenger(
          key: messengerKey,
          child: Scaffold(
            // The sheet's own white and rounded corners show through.
            backgroundColor: Colors.transparent,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: _Grabber(),
                ),
                // Above the grid's header during a tournée (PLAN §5.14),
                // the width of the sheet. « Voir les dons » and
                // « Terminer » drop the snackbar first: its « Annuler »
                // names a don by its place in the tournée.
                RoundBand(
                  onLeave: hideUndo,
                  margin: const EdgeInsets.only(top: 12),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.gutter,
                      12,
                      AppSizes.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        ...switch (state) {
                          BuildingGridLoading() => const <Widget>[],
                          BuildingGridGone() => [
                            Text(
                              l10n.buildingGone,
                              key: const Key('grid.gone'),
                              style: AppTextStyles.body.copyWith(
                                color: colors.muted,
                              ),
                            ),
                          ],
                          BuildingGridShown() => [
                            _Header(state: state),
                            if (state.showsStaircases)
                              _StaircaseControl(
                                state: state,
                                onSelected: _notifier.selectStaircase,
                              ),
                            Expanded(
                              child: _Floors(
                                state: state,
                                selected: _picking,
                                onTap: (door) {
                                  if (mayMark()) unawaited(_pick(door, state));
                                },
                              ),
                            ),
                            // Gives way to the snackbar, which floats here, and
                            // shows only during a tournée. At least 48 dp; taller
                            // with a large phone font.
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: AppSizes.minTapTarget,
                              ),
                              child:
                                  snackBarShown || marking != MarkingAccess.open
                                  ? null
                                  : Center(
                                      child: Text(
                                        l10n.gridHint,
                                        key: const Key('grid.hint'),
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.small.copyWith(
                                          color: colors.muted,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        },
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // The snackbar floats above these buttons, over the hint.
            bottomNavigationBar: switch (state) {
              BuildingGridShown() => _Actions(
                onManage: () => unawaited(_manage(state)),
                onDetails: _openDetails,
              ),
              BuildingGridLoading() || BuildingGridGone() => null,
            },
          ),
        ),
      ),
    );
  }

  /// A tap on a door: a light haptic tick at once, the door outlined, and
  /// its status picker. The snackbar of the last door goes first: its
  /// « Annuler » would put a door back under the picker.
  ///
  /// Once the picker is closed, what it stored is said aloud for screen
  /// readers (« Escalier A, 5e, porte 51, fait ») and shown in the snackbar
  /// (« Porte 51 : fait »), with « Annuler ».
  Future<void> _pick(DwellingKey door, BuildingGridShown state) async {
    unawaited(HapticFeedback.lightImpact());
    hideUndo();
    final notifier = _notifier;
    StoredStatus? stored;
    GivenDonation? added;
    setState(() => _picking = door);
    await showDoorStatusPicker(
      context,
      (
        street: widget.building.street,
        number: widget.building.number,
        door: door,
      ),
      onStored: (status) {
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
    if (stored case final stored?) {
      _tell(door, stored, namesStaircase: state.showsStaircases);
    }
    if (added case final added?) {
      final l10n = AppLocalizations.of(context);
      final words = donationWords(l10n, added.donation);
      showUndo(
        // « calendrier non compté » when the door took none (#155).
        message: added.calendarRefused
            ? l10n.doorDonationAddedNoCalendar(door.label.text, words)
            : l10n.doorDonationAdded(door.label.text, words),
        undoLabel: l10n.undo,
        onUndo: () => unawaited(notifier.undo()),
      );
    }
  }

  void _tell(
    DwellingKey door,
    StoredStatus stored, {
    required bool namesStaircase,
  }) {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        doorSpoken(
          l10n,
          door,
          namesStaircase: namesStaircase,
          status: spokenMarked(l10n, stored.status, stored.tries),
        ),
        Directionality.of(context),
      ),
    );
    showUndo(
      message: doorStoredMessage(
        l10n,
        door.label.text,
        stored.status,
        stored.tries,
        donation: stored.donation?.donation,
      ),
      undoLabel: l10n.undo,
      onUndo: () => unawaited(notifier.undo()),
    );
  }

  /// « Gérer l'immeuble »: the menu, then the choice. The snackbar goes
  /// first: its « Annuler » would undo a door behind the change.
  Future<void> _manage(BuildingGridShown state) async {
    hideUndo();
    final action = await showBuildingMenu(context);
    if (action == null || !mounted) return;
    switch (action) {
      // The setup sheet, prefilled, over the grid, which shows the new
      // layout as soon as it is stored.
      case BuildingAction.editFloors:
        await showBuildingSetup(context, widget.building);
      // A screen over the grid (`push`), back to it when left.
      case BuildingAction.adjustDoors:
        await context.push<void>(
          AppRoutes.adjustDoorsOf(
            widget.building.street,
            widget.building.number,
          ),
        );
      case BuildingAction.backToHouse:
        await _backToHouse(state);
    }
  }

  /// « Changer en maison »: asks first when a door has a mark, then
  /// closes the grid; its opener makes the house and offers « Annuler ».
  Future<void> _backToHouse(BuildingGridShown state) async {
    if (state.hasMarks) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showConfirmDialog(
        context,
        name: 'grid.confirmBackToHouse',
        title: l10n.confirmBackToHouseTitle,
        body: l10n.confirmBackToHouseBody,
        confirmLabel: l10n.backToHouseAction,
      );
      if (!confirmed || !mounted) return;
    }
    Navigator.of(context).pop(BuildingGridExit.backToHouse);
  }

  /// « Repasser »: the building's own « repasser », a mark like a door's,
  /// so only during a tournée.
  void _openDetails() {
    hideUndo();
    if (!mayMark()) return;
    unawaited(showBuildingDetailsSheet(context, widget.building));
  }
}

final class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: AppSizes.dragHandleWidth,
      height: AppSizes.dragHandleHeight,
      decoration: BoxDecoration(
        color: AppColors.of(context).line,
        borderRadius: BorderRadius.circular(AppSizes.dragHandleHeight / 2),
      ),
    ),
  );
}

/// « ✕ 8 Rue des Lilas      ◐ 15/24 ». The street name shortens first, so
/// the count always shows.
final class _Header extends StatelessWidget {
  const _Header({required this.state});

  final BuildingGridShown state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // Two rows: the ✕ has no text baseline, so it is centred against the
    // line, while the number, the name and the count share their baseline.
    return Row(
      spacing: 4,
      children: [
        // Closes as a swipe down does: a plain `pop` returns null, so the
        // opener has nothing to do next.
        CloseIconButton(
          key: const Key('grid.close'),
          tooltip: l10n.gridClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 10,
            children: [
              Expanded(
                // One heading for screen readers: « 8 Rue des Lilas ».
                child: MergeSemantics(
                  child: Semantics(
                    header: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      spacing: 10,
                      children: [
                        Text(
                          state.number.label,
                          style: AppTextStyles.sheetNumber.copyWith(
                            color: colors.ink,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            state.streetName,
                            key: const Key('grid.streetName'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sheetStreetName.copyWith(
                              color: colors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Semantics(
                label: l10n.buildingCountSemantics(state.done, state.total),
                excludeSemantics: true,
                child: Text.rich(
                  key: const Key('grid.count'),
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: StatusGlyph(
                          StatusGlyphs.buildingPartial,
                          size: AppSizes.gridCountGlyph,
                          color: colors.ink,
                        ),
                      ),
                      TextSpan(text: ' ${state.done}/${state.total}'),
                    ],
                  ),
                  style: AppTextStyles.gridCount.copyWith(color: colors.ink),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// « Esc. A · 7/12 | Esc. B · 2/6 ».
final class _StaircaseControl extends StatelessWidget {
  const _StaircaseControl({required this.state, required this.onSelected});

  final BuildingGridShown state;
  final ValueChanged<StaircaseName> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedChoice<StaircaseName>(
      groupLabel: l10n.staircaseGroup,
      selected: state.selected,
      onSelected: onSelected,
      height: AppSizes.labelStyleHeight,
      textStyle: AppTextStyles.segment,
      segments: [
        for (final tab in state.staircases)
          Segment(
            value: tab.name,
            key: ValueKey('grid.staircase.${tab.name.letter}'),
            label: l10n.staircaseTab(tab.name.letter, tab.done, tab.total),
            semanticsLabel: l10n.staircaseTabSemantics(
              tab.name.letter,
              tab.done,
              tab.total,
            ),
          ),
      ],
    );
  }
}

/// The floors from the top down, each label left of its doors, four doors
/// a row, wrapping under the same label.
final class _Floors extends StatelessWidget {
  const _Floors({
    required this.state,
    required this.selected,
    required this.onTap,
  });

  final BuildingGridShown state;

  /// The door whose status picker shows; null when none does.
  final DwellingKey? selected;
  final ValueChanged<DwellingKey> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return ListView.separated(
      key: const Key('grid.floors'),
      // A little room at the top and the end for the calendars badge of a
      // door of the first row or the last column, drawn past its edge: the
      // list cuts what goes past its own.
      padding: const EdgeInsetsDirectional.only(
        top: AppSizes.calendarBadgeOverhang,
        end: AppSizes.calendarBadgeOverhang,
      ),
      itemCount: state.floors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final floor = state.floors[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            SizedBox(
              width: AppSizes.floorLabelWidth,
              child: Padding(
                // Centres the label on the first row of doors.
                padding: const EdgeInsets.only(top: 15),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    floorName(l10n, floor.level),
                    style: AppTextStyles.segment.copyWith(color: colors.muted),
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const columns = AppSizes.doorsPerRow;
                  final width =
                      (constraints.maxWidth -
                          (columns - 1) * AppSizes.doorGap) /
                      columns;
                  return Wrap(
                    spacing: AppSizes.doorGap,
                    runSpacing: AppSizes.doorGap,
                    children: [
                      for (final door in floor.doors)
                        SizedBox(
                          width: width,
                          child: _DoorButton(
                            door: door,
                            namesStaircase: state.showsStaircases,
                            selected: door.key == selected,
                            onTap: () => onTap(door.key),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One door: its label and glyph, tinted per status; outlined in ink while
/// its status picker shows ([selected]).
final class _DoorButton extends StatelessWidget {
  const _DoorButton({
    required this.door,
    required this.namesStaircase,
    required this.selected,
    required this.onTap,
  });

  final DoorTile door;
  final bool namesStaircase;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final look = StatusLook.of(tileStatusOf(door.mark), colors);
    final spoken = doorSpoken(
      l10n,
      door.key,
      namesStaircase: namesStaircase,
      status: spokenWithCalendars(
        l10n,
        spokenWithTries(
          l10n,
          spokenMark(l10n, door.mark),
          nobodyHome: door.mark is NobodyHomeMark,
          tries: door.tries,
        ),
        calendars: door.calendars,
      ),
    );
    final tries = door.tries;
    return Semantics(
      key: ValueKey('grid.door.${door.key.id}'),
      label: spoken,
      button: true,
      // Only said while the picker shows: no « non sélectionné » on
      // every other tile.
      selected: selected ? true : null,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        height: AppSizes.doorHeight,
        child: WithCalendarsBadge(
          calendars: door.calendars,
          child: Material(
            color: look.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.tileRadius),
              // Inside the edge, as on a house tile: the doors do not move.
              side: selected
                  ? BorderSide(
                      color: colors.ink,
                      width: AppSizes.selectedTileOutline,
                    )
                  : BorderSide(color: look.border, width: AppSizes.borderWidth),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                // A long free label (« Fond cour ») shrinks rather than being
                // cut.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    spacing: 6,
                    children: [
                      Text(
                        door.key.label.text,
                        style: AppTextStyles.doorLabel.copyWith(
                          color: look.foreground,
                        ),
                      ),
                      StatusGlyph(
                        look.glyph,
                        size: AppSizes.doorGlyph,
                        color: look.foreground,
                      ),
                      if (tries != null)
                        Text(
                          l10n.tileTries(tries),
                          style: AppTextStyles.tileCount.copyWith(
                            color: look.foreground,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Gérer l'immeuble ▾ » and « Repasser »: side by side, half the width
/// each, when both labels hold on one line there; else one above the
/// other, full width, so a large phone font never breaks a word (#35).
final class _Actions extends StatelessWidget {
  const _Actions({required this.onManage, required this.onDetails});

  final VoidCallback onManage;
  final VoidCallback onDetails;

  static const _gap = 10.0;
  static const _padding = 16.0;
  static const _iconGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size.fromHeight(AppSizes.gridButtonHeight),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: _padding),
      ),
      textStyle: WidgetStatePropertyAll(AppTextStyles.segment),
    );
    final manage = OutlinedButton(
      key: const Key('grid.manage'),
      style: style,
      onPressed: onManage,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: _iconGap,
        children: [
          Flexible(child: Text(l10n.manageBuilding)),
          // The ▾ after the label says a menu opens; decoration only.
          const Icon(Icons.arrow_drop_down, size: AppSizes.gridButtonIcon),
        ],
      ),
    );
    final details = OutlinedButton(
      key: const Key('grid.details'),
      style: style,
      onPressed: onDetails,
      child: Text(l10n.buildingDetails),
    );
    // `SafeArea`: above the gesture bar of the phone.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          0,
          AppSizes.gutter,
          AppSizes.floatingBottom,
        ),
        // `LayoutBuilder` gives the width the buttons share; the labels are
        // measured in the phone's own text size before choosing the layout.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final room = (constraints.maxWidth - _gap) / 2 - 2 * _padding;
            final sideBySide =
                _lineWidth(context, l10n.manageBuilding) +
                        _iconGap +
                        AppSizes.gridButtonIcon <=
                    room &&
                _lineWidth(context, l10n.buildingDetails) <= room;
            return sideBySide
                ? Row(
                    key: const Key('grid.actions.row'),
                    spacing: _gap,
                    children: [
                      Expanded(child: manage),
                      Expanded(child: details),
                    ],
                  )
                : Column(
                    key: const Key('grid.actions.column'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: _gap,
                    children: [manage, details],
                  );
          },
        ),
      ),
    );
  }

  /// How wide [label] is on one line, in the buttons' style and the
  /// phone's text size. A `TextPainter` lays text out without drawing it.
  double _lineWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: AppTextStyles.segment),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
