import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_state.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

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
/// A removal is tried on the building first (`Building.withoutDoor`, which
/// stores nothing): a refusal, such as the last door, is said at once,
/// before asking about the door's marks.
final class AdjustDoorsNotifier extends Notifier<AdjustDoorsState> {
  AdjustDoorsNotifier(this.key);

  final BuildingGridKey key;

  Street? _street;
  var _read = false;

  /// The staircase chosen; null until one is, then the first is shown.
  StaircaseName? _chosen;

  /// The last change made here, for « Annuler »; the next one replaces it.
  StreetChange? _lastChange;

  @override
  AdjustDoorsState build() {
    final subscription = ref.watch(observeStreetProvider)(key.street).listen((
      street,
    ) {
      _street = street;
      _read = true;
      state = _view();
    });
    ref.onDispose(subscription.cancel);
    return _view();
  }

  /// The staircase control: shows the floors of [name].
  void selectStaircase(StaircaseName name) {
    _chosen = name;
    state = _view();
  }

  /// « + » at the end of the floor at [level] of [staircase]: one more door,
  /// labelled by the building's rule (`Building.withDoorAdded`).
  Future<DoorEditOutcome> addDoor(StaircaseName staircase, int? level) async {
    final result = await _describe(AddDoor(staircase, level));
    // The new door closes its floor: its label is the last one there.
    return _outcome(
      result,
      (building) => DwellingKey(
        staircase,
        level,
        building.staircases
            .firstWhere((each) => each.name == staircase)
            .floor(level)!
            .dwellings
            .last
            .label,
      ),
    );
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
    return _outcome(await _describe(RemoveDoor(door)), (_) => door);
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
        _lastChange = change;
        return DoorRenamed(DwellingKey(door.staircase, door.level, label));
      case Err(failure: final failure):
        return DoorRenameRefused(_reason(failure));
    }
  }

  /// « Annuler » of the snackbar: puts back what the last change replaced,
  /// once. When that is no longer possible, nothing happens.
  Future<void> undo() async {
    final change = _lastChange;
    if (change == null) return;
    _lastChange = null;
    await ref.read(undoLastChangeProvider)(change);
  }

  Future<Result<HouseChange, CommandFailure<BuildingChangeFailure>>> _describe(
    BuildingEdit edit,
  ) => ref.read(describeBuildingProvider)(key.street, key.number, edit);

  /// Keeps the change of [result] for « Annuler », naming the door it
  /// added or removed ([door], given the building after it), or says why
  /// there is none.
  DoorEditOutcome _outcome(
    Result<HouseChange, CommandFailure<BuildingChangeFailure>> result,
    DwellingKey Function(Building after) door,
  ) {
    switch (result) {
      case Ok(value: final change):
        _lastChange = change;
        // A door added or removed lays the building out again: the change
        // is always a `BuildingLaidOut` here.
        return DoorEditApplied(door((change as BuildingLaidOut).building));
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
  Building? get _building {
    final street = _street;
    if (street == null || street.isDeleted) return null;
    for (final house in street.houses) {
      if (house.number == key.number) return house.building;
    }
    return null;
  }

  AdjustDoorsState _view() {
    if (!_read) return const AdjustDoorsLoading();
    final building = _building;
    if (building == null) return const AdjustDoorsGone();
    final staircases = building.staircases;
    // The chosen staircase, or the first when none was chosen or the
    // chosen one went with a new layout.
    final shown = staircases.firstWhere(
      (staircase) => staircase.name == _chosen,
      orElse: () => staircases.first,
    );
    return AdjustDoorsShown(
      streetName: _street!.name,
      number: key.number,
      staircases: [for (final staircase in staircases) staircase.name],
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
