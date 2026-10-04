import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';

/// One floor of a staircase: a row of the building grid (PLAN §5.7), its
/// doors left to right.
///
/// Immutable; the building replaces a floor to change it.
final class Floor {
  /// The [dwellings] are copied into a list nobody can modify.
  Floor({required this.level, required Iterable<Dwelling> dwellings})
    : dwellings = List.unmodifiable(dwellings);

  /// 0 for the « RdC », 1 for the « 1er »…; null when the floors of the
  /// building are unknown: the staircase is then this one row, shown as
  /// « Logements ».
  final int? level;

  /// The doors, left to right, each label once. A floor may be empty once
  /// its doors were removed one by one (shops on the ground floor).
  final List<Dwelling> dwellings;

  /// The door labelled [label], or null when the floor has none.
  Dwelling? dwelling(DwellingLabel label) {
    for (final dwelling in dwellings) {
      if (dwelling.label == label) return dwelling;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Floor &&
      other.level == level &&
      sameItems(other.dwellings, dwellings);

  @override
  int get hashCode => Object.hash(level, Object.hashAll(dwellings));

  @override
  String toString() => 'Floor($level, $dwellings)';
}

/// One staircase of a building (« Esc. A »): its floors from the top down,
/// the order of the grid and of the stairs (PLAN §5.7).
///
/// Its building guarantees what the type alone cannot: its floors are
/// either distinct levels in descending order, or one floor with an
/// unknown level, and the labels of each floor are unique.
final class Staircase {
  /// The [floors] are copied into a list nobody can modify.
  Staircase({required this.name, required Iterable<Floor> floors})
    : floors = List.unmodifiable(floors);

  final StaircaseName name;

  /// The floors, top floor first, RdC last.
  final List<Floor> floors;

  /// Every door of the staircase, floor after floor from the top.
  Iterable<Dwelling> get dwellings => floors.expand((floor) => floor.dwellings);

  /// The floor at [level] (null: the « Logements » row), or null when the
  /// staircase has none.
  Floor? floor(int? level) {
    for (final floor in floors) {
      if (floor.level == level) return floor;
    }
    return null;
  }

  /// The progress of its doors: « Esc. A · 15/24 » (Building mockup).
  Progress get progress => dwellings.fold(
    Progress.empty,
    (sum, dwelling) => sum + dwelling.progress,
  );

  @override
  bool operator ==(Object other) =>
      other is Staircase &&
      other.name == name &&
      sameItems(other.floors, floors);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(floors));

  @override
  String toString() => 'Staircase(${name.letter}, $floors)';
}
