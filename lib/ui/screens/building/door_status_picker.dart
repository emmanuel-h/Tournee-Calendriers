import 'package:flutter/material.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/building/floor_names.dart';
import 'package:tournee_calendriers/ui/screens/street/status_picker_sheet.dart';
import 'package:tournee_calendriers/ui/screens/street/status_words.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Opens the status picker of one door over the Immeuble grid (a tap on
/// the door, PLAN §5.6, `docs/mockups/Building.dc.html`): the statuses of a
/// house, titled « Porte 51 · Fait » and « Esc. A · 5e · 8 Rue des Lilas »
/// (the staircase only when there are several), with the same steps.
/// [onStored] hears each status stored; the future ends once it is closed.
Future<void> showDoorStatusPicker(
  BuildContext context,
  DoorSheetKey door, {
  required ValueChanged<StoredStatus> onStored,
}) => showAppBottomSheet<void>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final label = door.door.label.text;
    return StatusPickerSheet(
      provider: doorSheetProvider(door),
      name: 'door',
      goneMessage: l10n.doorGone,
      title: (state) => _DoorTitle(
        title: l10n.statusPickerDoor(label, statusName(l10n, state.status!)),
        place: [
          if (state.subject case DoorSubject(:final staircase?))
            l10n.staircaseShort(staircase.letter),
          if (door.door.level case final level?) floorName(l10n, level),
          '${state.number.label} ${state.streetName}',
        ].join(' · '),
      ),
      comeBackSubject: (_) => l10n.doorTitle(label),
      onStored: onStored,
    );
  },
);

/// « Porte 51 · Fait » and, under it, where the door is. Screen readers
/// hear one heading.
final class _DoorTitle extends StatelessWidget {
  const _DoorTitle({required this.title, required this.place});

  final String title;
  final String place;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return MergeSemantics(
      child: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              key: const Key('door.number'),
              style: AppTextStyles.title.copyWith(color: colors.ink),
            ),
            Text(
              place,
              key: const Key('door.place'),
              style: AppTextStyles.small.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
