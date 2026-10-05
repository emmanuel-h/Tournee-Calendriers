import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// Why a door could not be added, removed or renamed, in French
/// (« Ajuster les portes » and the rename sheet of a door).
String buildingChangeMessage(
  AppLocalizations l10n,
  BuildingChangeFailure reason,
) => switch (reason) {
  BuildingChangeFailure.unknownHouse ||
  BuildingChangeFailure.notABuilding => l10n.buildingGone,
  BuildingChangeFailure.unknownStaircase ||
  BuildingChangeFailure.unknownFloor ||
  BuildingChangeFailure.unknownDwelling => l10n.doorGone,
  BuildingChangeFailure.duplicateLabel => l10n.doorLabelTaken,
  BuildingChangeFailure.lastDwelling => l10n.lastDoorRefused,
  BuildingChangeFailure.tooManyDwellings => l10n.setupTooManyDwellings(
    BuildingPlan.maxDwellings,
  ),
  BuildingChangeFailure.noLabelLeft => l10n.setupTooManyDoorsForLetters(
    DoorLabelStyle.letterCount,
  ),
};

/// Why the name typed cannot name a door, in French.
String dwellingLabelMessage(
  AppLocalizations l10n,
  DwellingLabelFailure reason,
) => switch (reason) {
  DwellingLabelFailure.blank => l10n.doorLabelBlank,
  DwellingLabelFailure.tooLong => l10n.doorLabelTooLong(
    DwellingLabel.maxLength,
  ),
};
