import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/building_status.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';

/// Why a change to the layout of a building (or turning it back into a
/// single house) was refused.
enum BuildingChangeFailure {
  /// The street has no house with that number.
  unknownHouse,

  /// The house is a single house, not a building.
  notABuilding,

  /// The building has no staircase with that name.
  unknownStaircase,

  /// The staircase has no floor at that level (or its floors are unknown
  /// and a level was given, or the reverse).
  unknownFloor,

  /// The building has no door at that staircase, floor and label.
  unknownDwelling,

  /// Another door of the same floor already has that label.
  duplicateLabel,

  /// The door is the only one left in the building: a building has at least
  /// one door (turn it back into a single house instead).
  lastDwelling,

  /// The building already has [BuildingPlan.maxDwellings] doors.
  tooManyDwellings,

  /// The label style has no label left for one more door on that floor
  /// (`5A` stops at Z).
  noLabelLeft,
}

/// Why stored parts cannot make a [Building] (see [Building.create]).
enum NewBuildingFailure {
  /// No staircase at all.
  noStaircase,

  /// Two staircases have the same name.
  duplicateStaircase,

  /// A floor level below the RdC or above [BuildingPlan.maxTopFloor].
  floorOutOfRange,

  /// Two floors of a staircase have the same level (two « Logements » rows
  /// included).
  duplicateFloor,

  /// A staircase has a « Logements » row (unknown level) next to other
  /// floors: its floors are either all known or one unknown row.
  unknownFloorNotAlone,

  /// Two doors of a floor have the same label.
  duplicateLabel,

  /// Not a single door in the whole building.
  noDwelling,

  /// More than [BuildingPlan.maxDwellings] doors.
  tooManyDwellings,
}

/// A house of the street that holds several dwellings (« Immeuble »,
/// PLAN §5.7): staircases `A`, `B`…, each with its floors from the top down,
/// each floor with its doors.
///
/// It lives inside a `House`, inside the `Street` aggregate: only the street
/// root stores a changed building. A `Building` is immutable; each method
/// below returns a new one.
///
/// Invariants, true of every `Building`:
/// - staircases are sorted by name, each name once;
/// - in a staircase, floors are distinct levels from 0 to
///   [BuildingPlan.maxTopFloor], top floor first, or a single « Logements »
///   row of unknown level;
/// - on a floor, each door label once (« Gauche » may be on every floor):
///   a door is identified by its [DwellingKey] (staircase, floor, label);
/// - it has at least one door and at most [BuildingPlan.maxDwellings].
///
/// Its [status] is derived from its doors, never stored or set by hand.
final class Building {
  Building._(this.style, Iterable<Staircase> staircases)
    : staircases = List.unmodifiable(staircases);

  /// The building [plan] lays out.
  ///
  /// For a building described again (« Modifier les étages »), pass the
  /// building as it was in [keeping]: each new door whose label already
  /// existed *on the same floor of the same staircase* takes that dwelling
  /// as it was (status, « repasser », note, last change). The other old
  /// doors are dropped.
  factory Building.laidOut(BuildingPlan plan, {Building? keeping}) {
    final staircases = plan.generate();
    if (keeping == null) return Building._(plan.style, staircases);
    return Building._(plan.style, [
      for (final staircase in staircases)
        Staircase(
          name: staircase.name,
          floors: [
            for (final floor in staircase.floors)
              Floor(
                level: floor.level,
                dwellings: [
                  for (final fresh in floor.dwellings)
                    keeping.dwellingAt(
                          DwellingKey(staircase.name, floor.level, fresh.label),
                        ) ??
                        fresh,
                ],
              ),
          ],
        ),
    ]);
  }

  /// Rebuilds a building from stored parts (on-phone storage, Firestore),
  /// checking every invariant, or fails with the first
  /// [NewBuildingFailure]. Staircases are sorted by name and floors top
  /// first, whatever order they come in.
  static Result<Building, NewBuildingFailure> create({
    required DoorLabelStyle style,
    required Iterable<Staircase> staircases,
  }) {
    final sorted = staircases.toList()
      ..sort((a, b) => a.name.letter.compareTo(b.name.letter));
    if (sorted.isEmpty) return const Err(NewBuildingFailure.noStaircase);
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].name == sorted[i - 1].name) {
        return const Err(NewBuildingFailure.duplicateStaircase);
      }
    }
    for (final staircase in sorted) {
      final failure = _floorsFailure(staircase.floors);
      if (failure != null) return Err(failure);
    }
    final doors = sorted.fold(0, (sum, s) => sum + s.dwellings.length);
    if (doors == 0) return const Err(NewBuildingFailure.noDwelling);
    if (doors > BuildingPlan.maxDwellings) {
      return const Err(NewBuildingFailure.tooManyDwellings);
    }
    return Ok(
      Building._(style, [
        for (final staircase in sorted)
          Staircase(
            name: staircase.name,
            // Top floor first. A « Logements » row is alone (checked
            // above), so the `?? 0` never compares it with a real level.
            floors: staircase.floors.toList()
              ..sort((a, b) => (b.level ?? 0).compareTo(a.level ?? 0)),
          ),
      ]),
    );
  }

  /// How the doors are labelled, which also labels the doors added later.
  final DoorLabelStyle style;

  /// The staircases in order (`A`, `B`…). The list cannot be modified.
  final List<Staircase> staircases;

  /// The progress of every door of every staircase; its total is the
  /// header count of the grid (« ◐ 15/24 »).
  Progress get progress => staircases.fold(
    Progress.empty,
    (sum, staircase) => sum + staircase.progress,
  );

  /// Whether any door of the building has a mark (see
  /// [Dwelling.hasMarks]).
  bool get hasMarks => staircases.any(
    (staircase) => staircase.dwellings.any((dwelling) => dwelling.hasMarks),
  );

  /// Done when every door is done, to do when none is, partial otherwise.
  BuildingStatus get status => BuildingStatus.of(progress);

  /// The dwelling at [key], or null when the building has none.
  Dwelling? dwellingAt(DwellingKey key) =>
      _staircaseNamed(key.staircase)?.floor(key.level)?.dwelling(key.label);

  /// This building with [dwelling] in place of the door that has the same
  /// label on the floor at [level] of [staircase]. Unchanged when there is
  /// no such door: the street checks the door exists before calling.
  Building withDwelling(
    StaircaseName staircase,
    int? level,
    Dwelling dwelling,
  ) => _withFloor(
    staircase,
    level,
    (floor) => [
      for (final other in floor.dwellings)
        other.label == dwelling.label ? dwelling : other,
    ],
  );

  /// This building with one more door at the end of the floor at [level]
  /// (null for the « Logements » row of unknown floors) of [staircase].
  ///
  /// The new door is to do. Its label follows [style]: the number (or
  /// letter) after the count of doors on the floor, skipping labels already
  /// taken on that floor. The door number is not padded with zeros (`110`
  /// after `19`).
  Result<Building, BuildingChangeFailure> withDoorAdded(
    StaircaseName staircase,
    int? level,
  ) {
    final current = _staircaseNamed(staircase);
    if (current == null) {
      return const Err(BuildingChangeFailure.unknownStaircase);
    }
    final floor = current.floor(level);
    if (floor == null) return const Err(BuildingChangeFailure.unknownFloor);
    if (progress.total >= BuildingPlan.maxDwellings) {
      return const Err(BuildingChangeFailure.tooManyDwellings);
    }
    final label = _nextLabel(floor);
    if (label == null) return const Err(BuildingChangeFailure.noLabelLeft);
    return Ok(
      _withFloor(
        staircase,
        level,
        (floor) => [...floor.dwellings, Dwelling(label: label)],
      ),
    );
  }

  /// This building without the door at [key]. Its floor stays, even empty,
  /// so a door can be added back to it.
  Result<Building, BuildingChangeFailure> withoutDoor(DwellingKey key) {
    if (dwellingAt(key) == null) {
      return const Err(BuildingChangeFailure.unknownDwelling);
    }
    if (progress.total == 1) {
      return const Err(BuildingChangeFailure.lastDwelling);
    }
    return Ok(
      _withFloor(
        key.staircase,
        key.level,
        (floor) => floor.dwellings.where((d) => d.label != key.label),
      ),
    );
  }

  /// This building with the door at [key] labelled [label], its marks kept.
  /// Giving a door the label it already has changes nothing.
  Result<Building, BuildingChangeFailure> withDoorRenamed(
    DwellingKey key,
    DwellingLabel label,
  ) {
    final before = dwellingAt(key);
    if (before == null) {
      return const Err(BuildingChangeFailure.unknownDwelling);
    }
    if (label != key.label &&
        dwellingAt(DwellingKey(key.staircase, key.level, label)) != null) {
      return const Err(BuildingChangeFailure.duplicateLabel);
    }
    final renamed = Dwelling(
      label: label,
      status: before.status,
      comeBack: before.comeBack,
      note: before.note,
      lastChange: before.lastChange,
    );
    return Ok(
      _withFloor(
        key.staircase,
        key.level,
        (floor) => [
          for (final other in floor.dwellings)
            other.label == key.label ? renamed : other,
        ],
      ),
    );
  }

  Staircase? _staircaseNamed(StaircaseName name) {
    for (final staircase in staircases) {
      if (staircase.name == name) return staircase;
    }
    return null;
  }

  /// This building with the doors of the floor at [level] of [staircase]
  /// replaced by what [doors] makes of that floor.
  Building _withFloor(
    StaircaseName staircase,
    int? level,
    Iterable<Dwelling> Function(Floor) doors,
  ) => Building._(style, [
    for (final current in staircases)
      if (current.name != staircase)
        current
      else
        Staircase(
          name: current.name,
          floors: [
            for (final floor in current.floors)
              floor.level == level
                  ? Floor(level: level, dwellings: doors(floor))
                  : floor,
          ],
        ),
  ]);

  /// The label of one more door on [floor], or null when [style] has run
  /// out of labels.
  DwellingLabel? _nextLabel(Floor floor) {
    // This loop ends: each turn tries a label never tried before, and the
    // floor holds fewer than BuildingPlan.maxDwellings labels.
    for (var door = floor.dwellings.length + 1; ; door++) {
      final text = style.label(level: floor.level, door: door);
      if (text == null) return null;
      final label = DwellingLabel(text);
      if (floor.dwelling(label) == null) return label;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Building &&
      other.style == style &&
      sameItems(other.staircases, staircases);

  @override
  int get hashCode => Object.hash(style, Object.hashAll(staircases));

  @override
  String toString() => 'Building($style, $staircases)';
}

/// The first broken invariant among the [floors] of one staircase, or null
/// when they are sound.
NewBuildingFailure? _floorsFailure(List<Floor> floors) {
  final levels = <int?>{};
  for (final floor in floors) {
    final level = floor.level;
    if (level != null && (level < 0 || level > BuildingPlan.maxTopFloor)) {
      return NewBuildingFailure.floorOutOfRange;
    }
    // `Set.add` returns false when the set already held the value.
    if (!levels.add(level)) return NewBuildingFailure.duplicateFloor;
    final labels = <DwellingLabel>{};
    for (final dwelling in floor.dwellings) {
      if (!labels.add(dwelling.label)) return NewBuildingFailure.duplicateLabel;
    }
  }
  if (levels.contains(null) && levels.length > 1) {
    return NewBuildingFailure.unknownFloorNotAlone;
  }
  return null;
}
