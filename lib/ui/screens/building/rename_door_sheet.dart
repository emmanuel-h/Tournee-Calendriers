import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_notifier.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_state.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/keep_focus.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/building/door_messages.dart';
import 'package:tournee_calendriers/ui/screens/building/floor_names.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Opens the rename sheet of [door] (tap a door of « Modifier les portes »,
/// PLAN §5.7): « Porte 11 », where it is, the « Nom de la porte » field and
/// « Renommer ». [where] is what follows the door's floor in the subtitle
/// (« 8 Rue des Lilas »); the staircase is named when [namesStaircase].
///
/// Completes with the door under its new name once renamed, so the screen
/// can offer « Annuler »; with null when the sheet closed without a change.
Future<DwellingKey?> showRenameDoorSheet(
  BuildContext context, {
  required BuildingGridKey building,
  required DwellingKey door,
  required String where,
  required bool namesStaircase,
}) => showAppBottomSheet<DwellingKey>(
  context: context,
  builder: (_) => RenameDoorSheet(
    building: building,
    door: door,
    where: where,
    namesStaircase: namesStaircase,
  ),
);

/// The door keeps its marks whatever its name. A name refused by the
/// building (one already on the floor) or by the label rules is said under
/// the field until the next edit; the sheet closes once the door has it.
final class RenameDoorSheet extends ConsumerStatefulWidget {
  const RenameDoorSheet({
    super.key,
    required this.building,
    required this.door,
    required this.where,
    required this.namesStaircase,
  });

  final BuildingGridKey building;
  final DwellingKey door;
  final String where;
  final bool namesStaircase;

  @override
  ConsumerState<RenameDoorSheet> createState() => _RenameDoorSheetState();
}

/// A `State`: the sheet keeps the text typed and why it was refused.
final class _RenameDoorSheetState extends ConsumerState<RenameDoorSheet> {
  // The whole name is selected, so typing replaces it (« 11 » → « Gauche »).
  late final _field = TextEditingController(text: widget.door.label.text)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.door.label.text.length,
    );

  /// Why the last « Renommer » was refused; cleared by the next edit.
  String? _refusal;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final door = widget.door;
    return SheetScaffold(
      spacing: 14,
      children: [
        // One heading for screen readers: « Porte 11, Esc. A · 1er · … ».
        MergeSemantics(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  l10n.doorTitle(door.label.text),
                  key: const Key('renameDoor.title'),
                  style: AppTextStyles.title.copyWith(color: colors.ink),
                ),
                Text(
                  [
                    if (widget.namesStaircase)
                      l10n.staircaseShort(door.staircase.letter),
                    if (door.level case final level?) floorName(l10n, level),
                    widget.where,
                  ].join(' · '),
                  key: const Key('renameDoor.where'),
                  style: AppTextStyles.body.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ),
        // `MergeSemantics`: TalkBack names the field « Nom de la porte ».
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(
                l10n.doorNameLabel,
                style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
              ),
              TextField(
                key: const Key('renameDoor.field'),
                controller: _field,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
                onChanged: (_) {
                  if (_refusal != null) setState(() => _refusal = null);
                },
                onEditingComplete: keepFocusOnSubmit,
                onSubmitted: (_) => unawaited(_rename()),
              ),
            ],
          ),
        ),
        if (_refusal case final refusal?)
          // `liveRegion`: TalkBack reads the refusal as soon as it shows.
          Semantics(
            liveRegion: true,
            child: Text(
              refusal,
              key: const Key('renameDoor.refusal'),
              style: AppTextStyles.small.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        PrimaryButton(
          key: const Key('renameDoor.rename'),
          label: l10n.renameDoorAction,
          compact: true,
          onPressed: () => unawaited(_rename()),
        ),
      ],
    );
  }

  /// « Renommer »: closes the sheet once the door has the name typed;
  /// otherwise says why.
  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context);
    final outcome = await ref
        .read(adjustDoorsProvider(widget.building).notifier)
        .rename(widget.door, _field.text);
    if (!mounted) return;
    switch (outcome) {
      case DoorRenamed(:final door):
        Navigator.of(context).pop(door);
      case DoorNameKept():
        Navigator.of(context).pop();
      case DoorLabelInvalid(:final reason):
        setState(() => _refusal = dwellingLabelMessage(l10n, reason));
      case DoorRenameRefused(:final reason):
        setState(() => _refusal = buildingChangeMessage(l10n, reason));
    }
  }
}
