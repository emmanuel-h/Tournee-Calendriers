import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';

/// How the doors of a building are labelled: the « Numéros des portes »
/// choice of the « Décrire l'immeuble » sheet (PLAN §5.7).
enum DoorLabelStyle {
  /// « 51, 52… »: the floor, then the door number on that floor (RdC 01–04,
  /// 1er 11–14, 5e 51–54).
  floorAndNumber,

  /// « 5A, 5B… »: the floor, then a letter per door (A to Z).
  floorAndLetter,

  /// « Libres »: placeholder numbers 1, 2, 3… on each floor, renamed one by
  /// one afterwards (« Gauche », « Droite » on every floor).
  free;

  /// The label of [door] (counted from 1 on its floor) on the floor at
  /// [level] (null when the floors are unknown, then no floor is shown).
  ///
  /// With [floorAndNumber], the door number is padded with zeros to [width]
  /// digits, so a floor of ten doors or more reads `101…110`, not
  /// `11…110`, and floor 1 door 11 (`111`) is not shown like floor 11
  /// door 1 (`1101`). Returns null when the style has no label left:
  /// [floorAndLetter] stops at Z.
  String? label({required int? level, required int door, int width = 1}) =>
      switch (this) {
        floorAndNumber when level == null => '$door',
        floorAndNumber => '$level${'$door'.padLeft(width, '0')}',
        floorAndLetter when door > letterCount => null,
        // 64 is the code just before `A`: door 1 is A, door 2 is B…
        floorAndLetter => '${level ?? ''}${String.fromCharCode(64 + door)}',
        free => '$door',
      };

  /// The doors a floor can have with [floorAndLetter]: one per letter.
  static const letterCount = 26;
}

/// Why the answers of the « Décrire l'immeuble » sheet cannot lay a
/// building out.
enum BuildingPlanFailure {
  /// Fewer than one staircase.
  noStaircase,

  /// More staircases than letters ([StaircaseName.maxCount]).
  tooManyStaircases,

  /// A top floor below the RdC (basements are not covered).
  belowGroundFloor,

  /// A top floor above [BuildingPlan.maxTopFloor].
  tooManyFloors,

  /// Fewer than one door per floor (in any staircase).
  noDoor,

  /// More doors per floor than letters in a staircase, with
  /// [DoorLabelStyle.floorAndLetter].
  tooManyDoorsForLetters,

  /// More than [BuildingPlan.maxDwellings] dwellings in all, every
  /// staircase counted.
  tooManyDwellings,
}

/// The floors and doors of one staircase in a [BuildingPlan]: floors from
/// the RdC up to [topFloor] (null: unknown floors, one « Logements » row),
/// [doorsPerFloor] doors on each.
///
/// Only answers: [BuildingPlan.perStaircase] checks them, with the label
/// style and the other staircases (a 5A style stops at 26 doors, a
/// building at 500 dwellings).
final class StaircasePlan {
  const StaircasePlan({required this.topFloor, required this.doorsPerFloor});

  /// The highest floor (0 is the RdC alone); null when the floors are
  /// unknown.
  final int? topFloor;

  final int doorsPerFloor;

  /// How many dwellings the staircase gets: one row when the floors are
  /// unknown.
  int get dwellingCount => ((topFloor ?? 0) + 1) * doorsPerFloor;

  /// One floor more (the « + » of the sheet): from unknown floors to the
  /// RdC alone, then up.
  StaircasePlan oneFloorMore() => StaircasePlan(
    topFloor: switch (topFloor) {
      null => 0,
      final top => top + 1,
    },
    doorsPerFloor: doorsPerFloor,
  );

  /// One floor less (the « − » of the sheet): down to the RdC alone, then
  /// unknown floors. Below unknown floors comes a top floor under the RdC,
  /// which [BuildingPlan.perStaircase] refuses
  /// ([BuildingPlanFailure.belowGroundFloor]), so the sheet can say why.
  StaircasePlan oneFloorLess() => StaircasePlan(
    topFloor: switch (topFloor) {
      0 => null,
      null => -1,
      final top => top - 1,
    },
    doorsPerFloor: doorsPerFloor,
  );

  /// One door more on each floor.
  StaircasePlan oneDoorMore() =>
      StaircasePlan(topFloor: topFloor, doorsPerFloor: doorsPerFloor + 1);

  /// One door less on each floor; [BuildingPlan.perStaircase] refuses none
  /// ([BuildingPlanFailure.noDoor]).
  StaircasePlan oneDoorLess() =>
      StaircasePlan(topFloor: topFloor, doorsPerFloor: doorsPerFloor - 1);

  @override
  bool operator ==(Object other) =>
      other is StaircasePlan &&
      other.topFloor == topFloor &&
      other.doorsPerFloor == doorsPerFloor;

  @override
  int get hashCode => Object.hash(topFloor, doorsPerFloor);

  @override
  String toString() =>
      'StaircasePlan(top floor $topFloor, $doorsPerFloor door(s) per floor)';
}

/// The answers of the « Décrire l'immeuble » sheet (PLAN §5.7): the floors
/// and doors of each staircase ([staircases], `A` first) and how the doors
/// are labelled. [generate] lays the building out.
///
/// Every floor of a staircase gets the same number of doors; the floors are
/// then adjusted one by one (a door more or less). The simple case, every
/// staircase alike (« Même chose pour chaque escalier »), is [create]; a
/// smaller staircase B is [perStaircase].
final class BuildingPlan {
  BuildingPlan._(List<StaircasePlan> staircases, this.style)
    : staircases = List.unmodifiable(staircases);

  /// The highest top floor: 50 floors is above the tallest residential
  /// towers of France, and keeps a slip of the « + » button harmless.
  static const maxTopFloor = 50;

  /// The most dwellings in one building. A building lives inside its street
  /// document, which Firestore caps at 1 MB (PLAN §6.2): 500 dwellings is
  /// about 50 KB, more than a large tower block needs.
  static const maxDwellings = 500;

  /// [staircaseCount] staircases alike: floors from the RdC up to
  /// [topFloor] (null: unknown floors, each staircase one row of
  /// [doorsPerFloor] doors, « Logements »). Checked as [perStaircase] does.
  static Result<BuildingPlan, BuildingPlanFailure> create({
    required int staircaseCount,
    required int? topFloor,
    required int doorsPerFloor,
    required DoorLabelStyle style,
  }) {
    // Checked before the list is made: a negative count cannot make one,
    // and a huge one is not worth making.
    if (staircaseCount < 1) return const Err(BuildingPlanFailure.noStaircase);
    if (staircaseCount > StaircaseName.maxCount) {
      return const Err(BuildingPlanFailure.tooManyStaircases);
    }
    return perStaircase(
      staircases: List.filled(
        staircaseCount,
        StaircasePlan(topFloor: topFloor, doorsPerFloor: doorsPerFloor),
      ),
      style: style,
    );
  }

  /// Checks the answers of each staircase, `A` first, or fails with the
  /// first [BuildingPlanFailure]. The limits on floors and doors hold for
  /// each staircase; the limit on dwellings for the whole building.
  static Result<BuildingPlan, BuildingPlanFailure> perStaircase({
    required List<StaircasePlan> staircases,
    required DoorLabelStyle style,
  }) {
    if (staircases.isEmpty) return const Err(BuildingPlanFailure.noStaircase);
    if (staircases.length > StaircaseName.maxCount) {
      return const Err(BuildingPlanFailure.tooManyStaircases);
    }
    for (final staircase in staircases) {
      final failure = _staircaseFailure(staircase, style);
      if (failure != null) return Err(failure);
    }
    final plan = BuildingPlan._(staircases, style);
    if (plan.dwellingCount > maxDwellings) {
      return const Err(BuildingPlanFailure.tooManyDwellings);
    }
    return Ok(plan);
  }

  /// The floors and doors of each staircase, `A` first. The list cannot be
  /// modified.
  final List<StaircasePlan> staircases;

  final DoorLabelStyle style;

  int get staircaseCount => staircases.length;

  /// Whether every staircase has the same floors and doors: the sheet's
  /// « Même chose pour chaque escalier ».
  bool get isUniform => staircases.every((s) => s == staircases.first);

  /// How many dwellings [generate] makes: the sheet's « Aperçu · 48
  /// logements ».
  int get dwellingCount =>
      staircases.fold(0, (sum, staircase) => sum + staircase.dwellingCount);

  /// The staircases `A`, `B`… with their floors from the top down, each
  /// door new (to do, unmarked).
  List<Staircase> generate() => [
    for (var index = 0; index < staircases.length; index++)
      Staircase(
        name: StaircaseName.at(index),
        floors: _floors(staircases[index]),
      ),
  ];

  List<Floor> _floors(StaircasePlan staircase) {
    final doors = staircase.doorsPerFloor;
    // Padded to the doors of this staircase: a staircase of 10 doors reads
    // `101…110`, its neighbour of 4 doors keeps `11…14`.
    final width = '$doors'.length;
    // A field cannot be promoted from `int?` to `int` by a null check (a
    // getter could return something else the second time); a local can.
    final top = staircase.topFloor;
    // A `for` loop counting down inside a list literal (a « collection
    // for »): the top floor comes first, as in the grid. `levels` is
    // `[null]` when the floors are unknown.
    final levels = top == null
        ? const <int?>[null]
        : [for (var level = top; level >= 0; level--) level];
    return [
      for (final level in levels)
        Floor(
          level: level,
          dwellings: [
            for (var door = 1; door <= doors; door++)
              Dwelling(
                // `!`: [perStaircase] refused the plans for which a style
                // runs out of labels, so every door here has one.
                label: DwellingLabel(
                  style.label(level: level, door: door, width: width)!,
                ),
              ),
          ],
        ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is BuildingPlan &&
      other.style == style &&
      sameItems(other.staircases, staircases);

  @override
  int get hashCode => Object.hash(style, Object.hashAll(staircases));

  @override
  String toString() => 'BuildingPlan($staircases, $style)';
}

/// Why [staircase] cannot be laid out with [style], or null when it can.
BuildingPlanFailure? _staircaseFailure(
  StaircasePlan staircase,
  DoorLabelStyle style,
) {
  final top = staircase.topFloor;
  if (top != null && top < 0) return BuildingPlanFailure.belowGroundFloor;
  if (top != null && top > BuildingPlan.maxTopFloor) {
    return BuildingPlanFailure.tooManyFloors;
  }
  if (staircase.doorsPerFloor < 1) return BuildingPlanFailure.noDoor;
  if (style == DoorLabelStyle.floorAndLetter &&
      staircase.doorsPerFloor > DoorLabelStyle.letterCount) {
    return BuildingPlanFailure.tooManyDoorsForLetters;
  }
  return null;
}
