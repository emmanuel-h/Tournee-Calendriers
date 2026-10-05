import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/components/tap_hint.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/building/building_setup_sheet.dart';
import 'package:tournee_calendriers/ui/screens/building/door_sheets.dart';
import 'package:tournee_calendriers/ui/screens/building/floor_names.dart';
import 'package:tournee_calendriers/ui/screens/street/status_words.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// Opens the Immeuble grid of [building] over the street screen (tap a
/// building tile, PLAN §5.7, `docs/mockups/Building.dc.html`).
Future<void> showBuildingGrid(BuildContext context, BuildingGridKey building) =>
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => BuildingGridSheet(building: building),
    );

/// The floors of one staircase from the top down, four doors a row; a tap
/// cycles a door `○ → ✓ → ✗ → ○` with « Annuler » for 4 s, a hold opens
/// its sheet. The header counts the doors of the whole building; the
/// staircase control shows when there are several. Works offline.
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
    with UndoSnackBarHost {
  BuildingGridNotifier get _notifier =>
      ref.read(buildingGridProvider(widget.building).notifier);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(buildingGridProvider(widget.building));
    // Full height but a strip at the top, where the street stays visible.
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: constraints.maxHeight - AppSizes.fullSheetTopGap,
        child: ScaffoldMessenger(
          key: messengerKey,
          child: Scaffold(
            // The sheet's own white and rounded corners show through.
            backgroundColor: Colors.transparent,
            body: Padding(
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
                  const _Grabber(),
                  ...switch (state) {
                    BuildingGridLoading() => const <Widget>[],
                    BuildingGridGone() => [
                      Text(
                        l10n.buildingGone,
                        key: const Key('grid.gone'),
                        style: AppTextStyles.body.copyWith(color: colors.muted),
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
                          onTap: _cycle,
                          onHold: _openDoor,
                        ),
                      ),
                      // Gives way to the snackbar, which floats here.
                      SizedBox(
                        height: AppSizes.minTapTarget,
                        child: snackBarShown
                            ? null
                            : Center(
                                child: TapHintText(
                                  key: const Key('grid.hint'),
                                  hold: l10n.gridHintHold,
                                  semanticsLabel: l10n.gridHintSemantics,
                                ),
                              ),
                      ),
                    ],
                  },
                ],
              ),
            ),
            // The snackbar floats above these buttons, over the hint.
            bottomNavigationBar: state is BuildingGridShown
                ? _Actions(onEditFloors: _editFloors, onDetails: _openDetails)
                : null,
          ),
        ),
      ),
    );
  }

  /// A tap on a door: a light haptic tick at once, then the new status,
  /// said aloud for screen readers (« Escalier A, 5e, porte 51, fait ») and
  /// shown in the snackbar (« 51 → Fait »).
  Future<void> _cycle(DwellingKey door) async {
    unawaited(HapticFeedback.lightImpact());
    // Read now: after the `await`, this context may be gone.
    final l10n = AppLocalizations.of(context);
    final view = View.of(context);
    final direction = Directionality.of(context);
    final notifier = _notifier;

    final marked = await notifier.cycle(door);
    if (marked == null || !mounted) return;

    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        doorSpoken(
          l10n,
          marked.key,
          namesStaircase: marked.namesStaircase,
          status: spokenStatus(l10n, marked.status),
        ),
        direction,
      ),
    );
    showUndo(
      message: l10n.houseMarked(
        marked.key.label.text,
        statusName(l10n, marked.status),
      ),
      undoLabel: l10n.undo,
      onUndo: () => unawaited(notifier.undo()),
    );
  }

  /// A hold on a door opens its sheet. The snackbar goes: its « Annuler »
  /// would put the whole door back, wiping what the sheet changes.
  void _openDoor(DwellingKey door) {
    hideUndo();
    unawaited(
      showDoorSheet(context, (
        street: widget.building.street,
        number: widget.building.number,
        door: door,
      )),
    );
  }

  /// « Modifier les étages »: the setup sheet, prefilled, over the grid,
  /// which shows the new layout as soon as it is stored.
  void _editFloors() {
    hideUndo();
    unawaited(showBuildingSetup(context, widget.building));
  }

  /// « Note · Repasser »: the building's own note and « repasser ».
  void _openDetails() {
    hideUndo();
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

/// « 8 Rue des Lilas        ◐ 15/24 ».
final class _Header extends StatelessWidget {
  const _Header({required this.state});

  final BuildingGridShown state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Row(
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
    required this.onTap,
    required this.onHold,
  });

  final BuildingGridShown state;
  final ValueChanged<DwellingKey> onTap;
  final ValueChanged<DwellingKey> onHold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return ListView.separated(
      key: const Key('grid.floors'),
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
                            onTap: () => onTap(door.key),
                            onHold: () => onHold(door.key),
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

/// One door: its label and glyph, tinted per status, a dot for a note.
final class _DoorButton extends StatelessWidget {
  const _DoorButton({
    required this.door,
    required this.namesStaircase,
    required this.onTap,
    required this.onHold,
  });

  final DoorTile door;
  final bool namesStaircase;
  final VoidCallback onTap;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final look = StatusLook.of(tileStatusOf(door.mark), AppColors.of(context));
    final spoken = doorSpoken(
      l10n,
      door.key,
      namesStaircase: namesStaircase,
      status: spokenMark(l10n, door.mark),
    );
    return Semantics(
      key: ValueKey('grid.door.${door.key.id}'),
      label: door.hasNote ? l10n.tileWithNoteSemantics(spoken) : spoken,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onHold,
      child: SizedBox(
        height: AppSizes.doorHeight,
        child: Material(
          color: look.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.tileRadius),
            side: BorderSide(color: look.border, width: AppSizes.borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onHold,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  // A long free label (« Fond cour ») shrinks rather than
                  // being cut.
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
                      ],
                    ),
                  ),
                ),
                if (door.hasNote)
                  Positioned(
                    top: AppSizes.noteDot,
                    right: AppSizes.noteDot,
                    child: Container(
                      width: AppSizes.noteDot,
                      height: AppSizes.noteDot,
                      decoration: BoxDecoration(
                        color: look.foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « Modifier les étages » and « Note · Repasser », side by side.
final class _Actions extends StatelessWidget {
  const _Actions({required this.onEditFloors, required this.onDetails});

  final VoidCallback onEditFloors;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size.fromHeight(AppSizes.gridButtonHeight),
      ),
      textStyle: WidgetStatePropertyAll(AppTextStyles.segment),
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
        child: Row(
          spacing: 10,
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('grid.editFloors'),
                style: style,
                onPressed: onEditFloors,
                child: Text(l10n.editFloors),
              ),
            ),
            Expanded(
              child: OutlinedButton(
                key: const Key('grid.details'),
                style: style,
                onPressed: onDetails,
                child: Text(l10n.buildingDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
