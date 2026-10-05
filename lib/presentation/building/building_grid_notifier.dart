import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_state.dart';
import 'package:tournee_calendriers/presentation/building/chooses_staircase.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street/follows_street.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/presentation/street/undoes_last_change.dart';

/// Which building a grid shows.
typedef BuildingGridKey = ({StreetId street, HouseNumber number});

/// The state of the Immeuble grid of one building (PLAN §5.7).
///
/// `family`: one notifier per building; `autoDispose`: it stops following
/// the street, and forgets its last tap, once the grid is closed.
final buildingGridProvider = NotifierProvider.autoDispose
    .family<BuildingGridNotifier, BuildingGridState, BuildingGridKey>(
      BuildingGridNotifier.new,
    );

/// Follows a building on the phone (`ObserveStreet`, offline), shows one
/// staircase at a time, cycles a door's status on a tap (`MarkDwelling`)
/// and undoes the last tap (`UndoLastChange`), as the street screen does
/// for houses.
final class BuildingGridNotifier extends Notifier<BuildingGridState>
    with
        FollowsStreet<BuildingGridState>,
        ChoosesStaircase<BuildingGridState>,
        UndoesLastChange<BuildingGridState> {
  BuildingGridNotifier(this.key);

  final BuildingGridKey key;

  @override
  BuildingGridState build() {
    followStreet(key.street);
    return render();
  }

  /// A tap on the door at [door]: gives it its next status (`○ → ✓ → ✗ →
  /// ○`) and returns what changed, for the snackbar and the announcement.
  /// Null when nothing changed: the street is not read yet, or the door is
  /// not in the building (any more).
  Future<MarkedDoor?> cycle(DwellingKey door) async {
    final building = _building;
    final dwelling = building?.dwellingAt(door);
    if (building == null || dwelling == null) return null;
    final result = await ref.read(markDwellingProvider)(
      key.street,
      key.number,
      door,
      StatusMark(dwelling.status.next),
    );
    switch (result) {
      case Ok(value: final change):
        keepForUndo(change);
        return (
          key: door,
          status: dwelling.status.next,
          namesStaircase: building.staircases.length > 1,
        );
      // The door was there a moment ago; a refusal can only come from a
      // teammate's change in between (M2): the grid shows the building as
      // it is.
      case Err():
        return null;
    }
  }

  /// The building the grid shows, or null when there is none.
  Building? get _building => street?.houseAt(key.number)?.building;

  @override
  BuildingGridState render() {
    if (!streetRead) return const BuildingGridLoading();
    final building = _building;
    if (building == null) return const BuildingGridGone();
    final shown = shownIn(building);
    final progress = building.progress;
    return BuildingGridShown(
      streetName: street!.name.text,
      number: key.number,
      done: progress.done,
      total: progress.total,
      staircases: [
        for (final staircase in building.staircases)
          (
            name: staircase.name,
            done: staircase.progress.done,
            total: staircase.progress.total,
          ),
      ],
      selected: shown.name,
      hasMarks: building.hasMarks,
      floors: [
        for (final floor in shown.floors)
          if (floor.dwellings.isNotEmpty)
            FloorRow(
              level: floor.level,
              doors: [
                for (final dwelling in floor.dwellings)
                  (
                    key: DwellingKey(shown.name, floor.level, dwelling.label),
                    mark: TileMark.ofDwelling(dwelling),
                  ),
              ],
            ),
      ],
    );
  }
}
