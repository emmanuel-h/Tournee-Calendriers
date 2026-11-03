import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_state.dart';
import 'package:tournee_calendriers/presentation/building/chooses_staircase.dart';
import 'package:tournee_calendriers/presentation/street/follows_street.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/presentation/street/undoes_last_change.dart';

/// Which building a grid shows.
typedef BuildingGridKey = ({StreetId street, HouseNumber number});

/// The state of the Immeuble grid of one building (PLAN §5.7).
///
/// `family`: one notifier per building; `autoDispose`: it stops following
/// the street, and forgets its last change, once the grid is closed.
final buildingGridProvider = NotifierProvider.autoDispose
    .family<BuildingGridNotifier, BuildingGridState, BuildingGridKey>(
      BuildingGridNotifier.new,
    );

/// Follows a building on the phone (`ObserveStreet`, offline), shows one
/// staircase at a time and undoes the last status a door's picker stored
/// (`keepForUndo`, `UndoLastChange`), as the street screen does for
/// houses. The door's picker (`doorSheetProvider`) stores the status.
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
      done: progress.visited,
      total: progress.total,
      staircases: [
        for (final staircase in building.staircases)
          (
            name: staircase.name,
            done: staircase.progress.visited,
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
                    tries: shownTries(dwelling.tries),
                    calendars: shownCalendars(dwelling.calendars),
                  ),
              ],
            ),
      ],
    );
  }
}
