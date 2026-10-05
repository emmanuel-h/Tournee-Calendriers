import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_notifier.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_state.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/confirm_dialog.dart';
import 'package:tournee_calendriers/ui/components/dashed_outline.dart';
import 'package:tournee_calendriers/ui/components/ok_button.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/building/door_messages.dart';
import 'package:tournee_calendriers/ui/screens/building/floor_names.dart';
import 'package:tournee_calendriers/ui/screens/building/rename_door_sheet.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Ajuster les portes » (PLAN §5.7, `docs/mockups/Doors.dc.html`),
/// opened from a building's number in edit mode: the floors of one
/// staircase, top first, each door with its ✕ and a « + » closing the
/// floor. A tap on a door renames it. Works offline.
///
/// Every change is stored at once, so ✕ and « OK » both simply leave. A
/// removal shows « Porte 53 supprimée [Annuler] » for 4 s.
final class AdjustDoorsScreen extends ConsumerStatefulWidget {
  const AdjustDoorsScreen({super.key, required this.building});

  /// Which building; null when the link named none.
  final BuildingGridKey? building;

  @override
  ConsumerState<AdjustDoorsScreen> createState() => _AdjustDoorsScreenState();
}

/// A `State`: the screen owns its undo snackbar ([UndoSnackBarHost]).
final class _AdjustDoorsScreenState extends ConsumerState<AdjustDoorsScreen>
    with UndoSnackBarHost {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final building = widget.building;
    final state = building == null
        ? const AdjustDoorsGone()
        : ref.watch(adjustDoorsProvider(building));
    return ScaffoldMessenger(
      key: messengerKey,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 4,
          toolbarHeight: AppSizes.titleBarWithSubtitleHeight,
          leading: IconButton(
            key: const Key('doors.close'),
            tooltip: l10n.adjustDoorsClose,
            icon: const Icon(Icons.close),
            onPressed: _leave,
          ),
          title: _Title(
            subtitle: switch (state) {
              AdjustDoorsShown(:final number, :final streetName) =>
                '${number.label} $streetName',
              AdjustDoorsLoading() || AdjustDoorsGone() => null,
            },
          ),
          actions: [
            OkButton(key: const Key('doors.ok'), onPressed: _leave),
            const SizedBox(width: 12),
          ],
        ),
        body: switch (state) {
          AdjustDoorsLoading() => const SizedBox.shrink(),
          AdjustDoorsGone() => const _GoneMessage(),
          AdjustDoorsShown() => _Floors(
            state: state,
            onSelectStaircase: (name) => ref
                .read(adjustDoorsProvider(building!).notifier)
                .selectStaircase(name),
            onRename: (door) => unawaited(_rename(state, door)),
            onRemove: (door) => unawaited(_remove(door)),
            onAdd: (level) => unawaited(_add(state.selected, level)),
          ),
        },
      ),
    );
  }

  AdjustDoorsNotifier get _notifier =>
      ref.read(adjustDoorsProvider(widget.building!).notifier);

  /// ✕ or « OK »: nothing to keep, every change is stored already.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else if (widget.building case final building?) {
      context.go(AppRoutes.editStreetOf(building.street));
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// A tap on a door opens its rename sheet. The snackbar goes: its
  /// « Annuler » would also undo the new name.
  Future<void> _rename(AdjustDoorsShown state, DwellingKey door) {
    hideUndo();
    return showRenameDoorSheet(
      context,
      building: widget.building!,
      door: door,
      where: '${state.number.label} ${state.streetName}',
      namesStaircase: state.showsStaircases,
    );
  }

  /// « + »: one more door at the end of the floor, or why not.
  Future<void> _add(StaircaseName staircase, int? level) async {
    final l10n = AppLocalizations.of(context);
    // The snackbar goes: its « Annuler » would also remove the new door.
    hideUndo();
    final outcome = await _notifier.addDoor(staircase, level);
    if (outcome case DoorEditRefused(:final reason) when mounted) {
      showMessage(buildingChangeMessage(l10n, reason));
    }
  }

  /// ✕ on a door: removed at once, or after a confirmation when it has a
  /// mark, with « Porte 53 supprimée [Annuler] ».
  Future<void> _remove(DwellingKey door) async {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    final label = door.label.text;
    var outcome = await notifier.remove(door);
    if (outcome is DoorEditNeedsConfirmation) {
      if (!mounted) return;
      hideUndo();
      final confirmed = await showConfirmDialog(
        context,
        name: 'doors.confirmRemove',
        title: l10n.confirmRemoveDoorTitle(label),
        body: l10n.confirmRemoveDoorBody,
        cancelLabel: l10n.keep,
        confirmLabel: l10n.delete,
        destructive: true,
      );
      if (!confirmed) return;
      outcome = await notifier.remove(door, confirmed: true);
    }
    if (!mounted) return;
    switch (outcome) {
      case DoorEditApplied():
        showUndo(
          message: l10n.doorRemoved(label),
          undoLabel: l10n.undo,
          onUndo: () => unawaited(notifier.undo()),
        );
      case DoorEditRefused(:final reason):
        showMessage(buildingChangeMessage(l10n, reason));
      // Only asked when not confirmed yet, which was handled above.
      case DoorEditNeedsConfirmation():
        break;
    }
  }
}

/// « Ajuster les portes » over « 8 Rue des Lilas ».
final class _Title extends StatelessWidget {
  const _Title({required this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.adjustDoorsAction),
        if (subtitle != null)
          Text(
            subtitle,
            key: const Key('doors.subtitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.small.copyWith(
              color: AppColors.of(context).muted,
            ),
          ),
      ],
    );
  }
}

/// The staircase control when there are several, the floors from the top
/// down, then the hint.
final class _Floors extends StatelessWidget {
  const _Floors({
    required this.state,
    required this.onSelectStaircase,
    required this.onRename,
    required this.onRemove,
    required this.onAdd,
  });

  final AdjustDoorsShown state;
  final ValueChanged<StaircaseName> onSelectStaircase;
  final ValueChanged<DwellingKey> onRename;
  final ValueChanged<DwellingKey> onRemove;

  /// « + » of the floor at this level was tapped.
  final ValueChanged<int?> onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.showsStaircases)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.gutter,
              14,
              AppSizes.gutter,
              6,
            ),
            child: SegmentedChoice<StaircaseName>(
              groupLabel: l10n.staircaseGroup,
              selected: state.selected,
              onSelected: onSelectStaircase,
              height: AppSizes.labelStyleHeight,
              textStyle: AppTextStyles.segment,
              segments: [
                for (final name in state.staircases)
                  Segment(
                    value: name,
                    key: ValueKey('doors.staircase.${name.letter}'),
                    label: l10n.staircaseShort(name.letter),
                    semanticsLabel: l10n.staircaseSpoken(name.letter),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            key: const Key('doors.floors'),
            // Room at the bottom so the snackbar never hides the last floor.
            padding: const EdgeInsets.fromLTRB(
              AppSizes.gutter,
              8,
              AppSizes.gutter,
              AppSizes.streetListBottom,
            ),
            children: [
              for (final floor in state.floors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FloorRow(
                    floor: floor,
                    onRename: onRename,
                    onRemove: onRemove,
                    onAdd: () => onAdd(floor.level),
                  ),
                ),
              Text(
                l10n.adjustDoorsHint,
                style: AppTextStyles.small.copyWith(
                  color: colors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A floor: its label, then its doors and « + », wrapping under the label.
final class _FloorRow extends StatelessWidget {
  const _FloorRow({
    required this.floor,
    required this.onRename,
    required this.onRemove,
    required this.onAdd,
  });

  final AdjustFloor floor;
  final ValueChanged<DwellingKey> onRename;
  final ValueChanged<DwellingKey> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final levelKey = floor.level ?? 'x';
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
          child: Wrap(
            spacing: AppSizes.doorGap,
            runSpacing: AppSizes.doorGap,
            children: [
              for (final door in floor.doors)
                _DoorTile(
                  key: ValueKey('doors.door.${door.id}'),
                  door: door,
                  onRename: () => onRename(door),
                  onRemove: () => onRemove(door),
                ),
              _AddDoorButton(
                key: ValueKey('doors.add.$levelKey'),
                semanticsLabel: switch (floor.level) {
                  null => l10n.addDoorUnknownFloorSemantics,
                  0 => l10n.addDoorGroundSemantics,
                  final level => l10n.addDoorSemantics(floorName(l10n, level)),
                },
                onPressed: onAdd,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A door: white, a dashed grey outline, its label to tap and a red ✕, as
/// wide as its label needs.
final class _DoorTile extends StatelessWidget {
  const _DoorTile({
    super.key,
    required this.door,
    required this.onRename,
    required this.onRemove,
  });

  final DwellingKey door;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final label = door.label.text;
    return SizedBox(
      height: AppSizes.doorHeight,
      child: CustomPaint(
        foregroundPainter: DashedOutlinePainter(colors.editTileBorder),
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.tileRadius),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: l10n.renameDoorSemantics(label),
                button: true,
                excludeSemantics: true,
                onTap: onRename,
                child: InkWell(
                  key: const Key('doors.door.rename'),
                  onTap: onRename,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: AppTextStyles.doorLabel.copyWith(
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('doors.door.remove'),
                tooltip: l10n.removeDoorSemantics(label),
                onPressed: onRemove,
                color: colors.accent,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « + », the square closing a floor: one more door there.
final class _AddDoorButton extends StatelessWidget {
  const _AddDoorButton({
    super.key,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: AppSizes.doorHeight,
        child: Material(
          color: colors.ground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.tileRadius),
            side: BorderSide(color: colors.ink, width: AppSizes.borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Text(
                '+',
                style: AppTextStyles.stepperSign.copyWith(color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Ce numéro n'est plus un immeuble de cette rue. »
final class _GoneMessage extends StatelessWidget {
  const _GoneMessage();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        AppLocalizations.of(context).buildingGone,
        key: const Key('doors.gone'),
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.of(context).muted),
      ),
    ),
  );
}
