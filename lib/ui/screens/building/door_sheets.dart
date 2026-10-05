import 'package:flutter/material.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/building/floor_names.dart';
import 'package:tournee_calendriers/ui/screens/street/marks_sheet.dart';

/// Opens the sheet of one door (hold a door of the Immeuble grid, PLAN
/// §5.7): the controls of the Fiche maison, without « Transformer en
/// immeuble… ». Its title is the door, then where it is: « 51 · Esc. A ·
/// 5e · 8 Rue des Lilas ».
Future<void> showDoorSheet(BuildContext context, DoorSheetKey door) =>
    showAppBottomSheet<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return MarksSheet(
          provider: doorSheetProvider(door),
          name: 'door',
          goneMessage: l10n.doorGone,
          title: (state) => MarksSheetTitle(
            name: 'door',
            big: door.door.label.text,
            beside: [
              if (state.subject case DoorSubject(:final staircase?))
                l10n.staircaseShort(staircase.letter),
              if (door.door.level case final level?) floorName(l10n, level),
              '${state.number.label} ${state.streetName}',
            ].join(' · '),
          ),
        );
      },
    );

/// Opens the building's own « repasser » (« Repasser » under the grid, or
/// hold a building tile): no status, its doors carry them.
Future<void> showBuildingDetailsSheet(
  BuildContext context,
  HouseSheetKey building,
) => showAppBottomSheet<void>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    return MarksSheet(
      provider: buildingDetailsProvider(building),
      name: 'building',
      goneMessage: l10n.buildingGone,
      title: (state) => MarksSheetTitle(
        name: 'building',
        big: state.number.label,
        beside: state.streetName,
      ),
    );
  },
);
