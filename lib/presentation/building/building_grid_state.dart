import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

// The view state of the Immeuble grid (PLAN §5.7, mockup Building): what the
// grid of one building shows, as plain data tested without widgets.
//
// The small items are records: `({…})` types whose equality and printing
// Dart writes from their fields, so tests compare them whole.

/// One button of the staircase control: « Esc. A · 7/12 ».
typedef StaircaseTab = ({StaircaseName name, int done, int total});

/// One door of the grid: its label (`key.label`) and its look.
typedef DoorTile = ({DwellingKey key, TileMark mark});

/// One floor of the grid: its label (« RdC », « 1er »…, « Logements » when
/// [level] is null) and its doors, left to right.
final class FloorRow {
  FloorRow({required this.level, required List<DoorTile> doors})
    : doors = List.unmodifiable(doors);

  /// 0 for the RdC; null for the « Logements » row of unknown floors.
  final int? level;

  final List<DoorTile> doors;
}

/// Everything the Immeuble grid shows. `sealed`: the sheet handles each
/// case.
sealed class BuildingGridState {
  const BuildingGridState();
}

/// The street is being read from the phone (a moment, at most).
final class BuildingGridLoading extends BuildingGridState {
  const BuildingGridLoading();
}

/// The number is not a building of a street on the phone (any more): it
/// was removed, turned back into a single house, or its street went to the
/// Corbeille.
final class BuildingGridGone extends BuildingGridState {
  const BuildingGridGone();
}

/// The building, ready to mark door by door.
final class BuildingGridShown extends BuildingGridState {
  BuildingGridShown({
    required this.streetName,
    required this.number,
    required this.done,
    required this.total,
    required List<StaircaseTab> staircases,
    required this.selected,
    required List<FloorRow> floors,
    required this.hasMarks,
  }) : staircases = List.unmodifiable(staircases),
       floors = List.unmodifiable(floors);

  final String streetName;
  final HouseNumber number;

  /// « ◐ 15/24 »: the doors done and the doors of the whole building, every
  /// staircase included.
  final int done;
  final int total;

  /// Every staircase, in order (A, B…).
  final List<StaircaseTab> staircases;

  /// The staircase whose floors [floors] shows.
  final StaircaseName selected;

  /// The floors of [selected], top floor first; a floor without a door is
  /// left out.
  final List<FloorRow> floors;

  /// Whether a door has a mark (a status, « repasser » included):
  /// « Changer en maison » asks first, as they would go.
  final bool hasMarks;

  /// The staircase control shows only when there is a choice to make.
  bool get showsStaircases => staircases.length > 1;
}

/// What a tap on a door changed, for the snackbar « 51 → Fait » and the
/// announcement « Escalier A, 5e, porte 51, fait ». [namesStaircase] is
/// false when the building has a single staircase: it is not named then,
/// as the grid shows no staircase control.
typedef MarkedDoor = ({
  DwellingKey key,
  VisitStatus status,
  bool namesStaircase,
});
