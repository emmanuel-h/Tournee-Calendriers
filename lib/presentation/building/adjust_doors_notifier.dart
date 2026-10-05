import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_state.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/presentation/building/chooses_staircase.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street/follows_street.dart';
import 'package:tournee_calendriers/presentation/street/undoes_last_change.dart';

/// The state of « Modifier les portes » for one building (`family`: one per
/// street and number, the key of the grid; `autoDispose`: it stops
/// following the street, and forgets its last change, when the screen
/// goes).
final adjustDoorsProvider = NotifierProvider.autoDispose
    .family<AdjustDoorsNotifier, AdjustDoorsState, BuildingGridKey>(
      AdjustDoorsNotifier.new,
    );

/// « Modifier les portes » (PLAN §5.7): follows a building on the phone
/// (`ObserveStreet`, offline), shows one staircase at a time, and adds,
/// removes or renames one door at a time through `DescribeBuilding`, then
/// undoes the last change (`UndoLastChange`). Needs no network.
///
/// An addition or a removal is tried on the building first
/// (`Building.nextDoor`, `Building.withoutDoor`, which store nothing): a
/// refusal, such as the last door, is said at once, before asking about the
/// door's marks, and the new door is named by the building's own rule.
final class AdjustDoorsNotifier extends Notifier<AdjustDoorsState>
    with
        FollowsStreet<AdjustDoorsState>,
        ChoosesStaircase<AdjustDoorsState>,
        UndoesLastChange<AdjustDoorsState> {
  AdjustDoorsNotifier(this.key);

  final BuildingGridKey key;

  @override
  AdjustDoorsState build() {
    followStreet(key.street);
    return render();
  }

  /// « + » at the end of the floor at [level] of [staircase]: one more door,
  /// labelled by the building's rule (`Building.nextDoor`).
  Future<DoorEditOutcome> addDoor(StaircaseName staircase, int? level) async {
    switch (_building?.nextDoor(staircase, level)) {
      // No building on the screen: it says so as for a number gone.
      case null:
        return const DoorEditRefused(BuildingChangeFailure.unknownHouse);
      case Err(:final failure):
        return DoorEditRefused(failure);
      case Ok(value: final door):
        return _outcome(await _describe(AddDoor(staircase, level)), door);
    }
  }

  /// ✕ on [door]: the door goes with its marks. When it has marks, nothing
  /// happens unless [confirmed]: the screen asks first.
  Future<DoorEditOutcome> remove(
    DwellingKey door, {
    bool confirmed = false,
  }) async {
    // A number that is no longer a building goes on to the use case, which
    // says why.
    if (_building case final building?) {
      if (building.withoutDoor(door) case Err(:final failure)) {
        return DoorEditRefused(failure);
      }
      if (building.dwellingAt(door)!.hasMarks && !confirmed) {
        return const DoorEditNeedsConfirmation();
      }
    }
    return _outcome(await _describe(RemoveDoor(door)), door);
  }

  /// « Renommer » of a door's sheet: gives [door] the name typed as
  /// [text] (« Gauche »), its marks kept, and keeps the change for
  /// « Annuler ». The name it already has stores nothing, so the door is
  /// not stamped for nothing.
  Future<DoorRenameOutcome> rename(DwellingKey door, String text) async {
    final DwellingLabel label;
    switch (DwellingLabel.parse(text)) {
      case Err(:final failure):
        return DoorLabelInvalid(failure);
      case Ok(:final value):
        label = value;
    }
    if (label == door.label) return const DoorNameKept();
    switch (await _describe(RenameDoor(door, label))) {
      case Ok(value: final change):
        keepForUndo(change);
        return DoorRenamed(DwellingKey(door.staircase, door.level, label));
      case Err(failure: final failure):
        return DoorRenameRefused(_reason(failure));
    }
  }

  Future<Result<HouseChange, CommandFailure<BuildingChangeFailure>>> _describe(
    BuildingEdit edit,
  ) => ref.read(describeBuildingProvider)(key.street, key.number, edit);

  /// Keeps the change of [result] for « Annuler », naming the [door] it
  /// added or removed, or says why there is none.
  DoorEditOutcome _outcome(
    Result<HouseChange, CommandFailure<BuildingChangeFailure>> result,
    DwellingKey door,
  ) {
    switch (result) {
      case Ok(value: final change):
        keepForUndo(change);
        return DoorEditApplied(door);
      case Err(:final failure):
        return DoorEditRefused(_reason(failure));
    }
  }

  /// A street no longer on the phone has no building either: the screen
  /// says so as it does for a number gone from the street.
  BuildingChangeFailure _reason(
    CommandFailure<BuildingChangeFailure> failure,
  ) => switch (failure) {
    CommandRefused(:final reason) => reason,
    StreetNotFound() => BuildingChangeFailure.unknownHouse,
  };

  /// The building adjusted, or null when there is none.
  Building? get _building => street?.houseAt(key.number)?.building;

  @override
  AdjustDoorsState render() {
    if (!streetRead) return const AdjustDoorsLoading();
    final building = _building;
    if (building == null) return const AdjustDoorsGone();
    final shown = shownIn(building);
    return AdjustDoorsShown(
      streetName: street!.name.text,
      number: key.number,
      staircases: [for (final staircase in building.staircases) staircase.name],
      selected: shown.name,
      floors: [
        for (final floor in shown.floors)
          AdjustFloor(
            level: floor.level,
            doors: [
              for (final dwelling in floor.dwellings)
                DwellingKey(shown.name, floor.level, dwelling.label),
            ],
          ),
      ],
    );
  }
}
