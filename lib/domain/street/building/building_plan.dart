import 'package:tournee_calendriers/domain/shared/result.dart';
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

  /// Fewer than one door per floor.
  noDoor,

  /// More doors per floor than letters, with [DoorLabelStyle.floorAndLetter].
  tooManyDoorsForLetters,

  /// More than [BuildingPlan.maxDwellings] dwellings in all.
  tooManyDwellings,
}

/// The answers of the « Décrire l'immeuble » sheet (PLAN §5.7): how many
/// staircases, floors from the RdC up to [topFloor], doors per floor, and
/// how the doors are labelled. [generate] lays the building out.
///
/// Every staircase gets the same floors and every floor the same number of
/// doors; the floors are then adjusted one by one (a door more or less).
final class BuildingPlan {
  const BuildingPlan._(
    this.staircaseCount,
    this.topFloor,
    this.doorsPerFloor,
    this.style,
  );

  /// The highest top floor: 50 floors is above the tallest residential
  /// towers of France, and keeps a slip of the « + » button harmless.
  static const maxTopFloor = 50;

  /// The most dwellings in one building. A building lives inside its street
  /// document, which Firestore caps at 1 MB (PLAN §6.2): 500 dwellings is
  /// about 50 KB, more than a large tower block needs.
  static const maxDwellings = 500;

  /// Checks the answers, or fails with the first [BuildingPlanFailure]. A
  /// null [topFloor] means the floors are unknown: each staircase is then
  /// one row of [doorsPerFloor] doors, « Logements ».
  static Result<BuildingPlan, BuildingPlanFailure> create({
    required int staircaseCount,
    required int? topFloor,
    required int doorsPerFloor,
    required DoorLabelStyle style,
  }) {
    if (staircaseCount < 1) return const Err(BuildingPlanFailure.noStaircase);
    if (staircaseCount > StaircaseName.maxCount) {
      return const Err(BuildingPlanFailure.tooManyStaircases);
    }
    if (topFloor != null && topFloor < 0) {
      return const Err(BuildingPlanFailure.belowGroundFloor);
    }
    if (topFloor != null && topFloor > maxTopFloor) {
      return const Err(BuildingPlanFailure.tooManyFloors);
    }
    if (doorsPerFloor < 1) return const Err(BuildingPlanFailure.noDoor);
    if (style == DoorLabelStyle.floorAndLetter &&
        doorsPerFloor > DoorLabelStyle.letterCount) {
      return const Err(BuildingPlanFailure.tooManyDoorsForLetters);
    }
    final plan = BuildingPlan._(staircaseCount, topFloor, doorsPerFloor, style);
    if (plan.dwellingCount > maxDwellings) {
      return const Err(BuildingPlanFailure.tooManyDwellings);
    }
    return Ok(plan);
  }

  final int staircaseCount;

  /// The highest floor (0 is the RdC alone); null when the floors are
  /// unknown.
  final int? topFloor;

  final int doorsPerFloor;
  final DoorLabelStyle style;

  /// How many dwellings [generate] makes: the sheet's « Aperçu · 48
  /// logements ».
  int get dwellingCount => staircaseCount * _floorCount * doorsPerFloor;

  /// The floors of each staircase: one row when the floors are unknown.
  int get _floorCount => (topFloor ?? 0) + 1;

  /// The staircases `A`, `B`… with their floors from the top down, each
  /// door new (to do, no note).
  List<Staircase> generate() => [
    for (var index = 0; index < staircaseCount; index++)
      Staircase(name: StaircaseName.at(index), floors: _floors()),
  ];

  List<Floor> _floors() {
    final width = '$doorsPerFloor'.length;
    // A field cannot be promoted from `int?` to `int` by a null check (a
    // getter could return something else the second time); a local can.
    final top = topFloor;
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
            for (var door = 1; door <= doorsPerFloor; door++)
              Dwelling(
                // `!`: [create] refused the plans for which a style runs out
                // of labels, so every door here has one.
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
      other.staircaseCount == staircaseCount &&
      other.topFloor == topFloor &&
      other.doorsPerFloor == doorsPerFloor &&
      other.style == style;

  @override
  int get hashCode =>
      Object.hash(staircaseCount, topFloor, doorsPerFloor, style);

  @override
  String toString() =>
      'BuildingPlan($staircaseCount staircase(s), top floor $topFloor, '
      '$doorsPerFloor door(s) per floor, $style)';
}
