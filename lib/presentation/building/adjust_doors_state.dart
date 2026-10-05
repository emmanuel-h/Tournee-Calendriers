import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';

// The view state of « Ajuster les portes » (PLAN §5.7, mockup Doors): the
// floors of one staircase with their doors, and what its commands answer,
// so the screen knows whether to ask first, show « Annuler », or say why
// nothing changed.

/// One floor of the screen: its label (« RdC », « 1er »…, « Logements »
/// when [level] is null) and its doors, left to right. Unlike the grid, an
/// empty floor is listed, so a door can be added back to it.
final class AdjustFloor {
  AdjustFloor({required this.level, required List<DwellingKey> doors})
    : doors = List.unmodifiable(doors);

  /// 0 for the RdC; null for the « Logements » row of unknown floors.
  final int? level;

  /// Each door's key: its label is `key.label`.
  final List<DwellingKey> doors;
}

/// Everything « Ajuster les portes » shows. `sealed`: the screen handles
/// each case.
sealed class AdjustDoorsState {
  const AdjustDoorsState();
}

/// The street is being read from the phone (a moment, at most).
final class AdjustDoorsLoading extends AdjustDoorsState {
  const AdjustDoorsLoading();
}

/// The number is not a building of a street on the phone (any more).
final class AdjustDoorsGone extends AdjustDoorsState {
  const AdjustDoorsGone();
}

/// The building, ready to adjust floor by floor.
final class AdjustDoorsShown extends AdjustDoorsState {
  AdjustDoorsShown({
    required this.streetName,
    required this.number,
    required List<StaircaseName> staircases,
    required this.selected,
    required List<AdjustFloor> floors,
  }) : staircases = List.unmodifiable(staircases),
       floors = List.unmodifiable(floors);

  final String streetName;
  final HouseNumber number;

  /// Every staircase, in order (A, B…).
  final List<StaircaseName> staircases;

  /// The staircase whose floors [floors] shows.
  final StaircaseName selected;

  /// The floors of [selected], top floor first, empty ones included.
  final List<AdjustFloor> floors;

  /// The staircase control shows only when there is a choice to make; the
  /// staircase is named in a door's title only then.
  bool get showsStaircases => staircases.length > 1;
}

/// What « + » or ✕ did. `sealed`: the screen handles each case.
sealed class DoorEditOutcome {
  const DoorEditOutcome();
}

/// The change is stored; « Annuler » can undo a removal.
final class DoorEditApplied extends DoorEditOutcome {
  const DoorEditApplied();
}

/// Nothing was stored: the door has marks that would go with it. The
/// screen asks, then tries again, confirmed.
final class DoorEditNeedsConfirmation extends DoorEditOutcome {
  const DoorEditNeedsConfirmation();
}

/// Nothing was stored, for [reason]: the last door of the building, no
/// label left, too many doors, or the building or door is gone.
final class DoorEditRefused extends DoorEditOutcome {
  const DoorEditRefused(this.reason);

  final BuildingChangeFailure reason;

  @override
  bool operator ==(Object other) =>
      other is DoorEditRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'DoorEditRefused($reason)';
}

/// What « Renommer » did. `sealed`: the sheet handles each case.
sealed class DoorRenameOutcome {
  const DoorRenameOutcome();
}

/// The door has the name typed, its marks kept (or already had it: nothing
/// was stored then). The sheet closes.
final class DoorRenamed extends DoorRenameOutcome {
  const DoorRenamed();
}

/// The text typed cannot name a door, for [reason].
final class DoorLabelInvalid extends DoorRenameOutcome {
  const DoorLabelInvalid(this.reason);

  final DwellingLabelFailure reason;

  @override
  bool operator ==(Object other) =>
      other is DoorLabelInvalid && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'DoorLabelInvalid($reason)';
}

/// The building refused the name, for [reason] (another door of the floor
/// has it, or the door is gone).
final class DoorRenameRefused extends DoorRenameOutcome {
  const DoorRenameRefused(this.reason);

  final BuildingChangeFailure reason;

  @override
  bool operator ==(Object other) =>
      other is DoorRenameRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'DoorRenameRefused($reason)';
}
