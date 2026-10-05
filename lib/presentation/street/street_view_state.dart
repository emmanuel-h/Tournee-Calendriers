import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_status.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

// The view state of the street screen (PLAN §5.6, mockup Main). The rules
// of what a tile shows live here, as plain data, so they are tested without
// widgets; the screen only picks the colours and glyphs of each case.

/// What a tile shows: one look per case of the mockup. `sealed`, so the
/// screen's `switch` must give each one a look, and a new case breaks the
/// build there.
sealed class TileMark {
  const TileMark();

  /// The mark of [house]:
  /// - a single house shows its status;
  /// - a building shows its derived status: done when every door is,
  ///   `◐ done/total` when some are, and to do (or ↻ with its own
  ///   « repasser ») when none is. Doors « repasser » are not done: a
  ///   building whose doors all are shows ○, its grid shows them ↻.
  static TileMark of(House house) => switch (house.building) {
    null => _ofStatus(house.status),
    final Building building => switch (building.status) {
      BuildingStatus.done => const DoneMark(),
      BuildingStatus.partial => PartialBuildingMark(
        done: building.progress.done,
        total: building.progress.total,
      ),
      BuildingStatus.toDo =>
        house.comeBack == null ? const ToDoMark() : const ComeBackMark(),
    },
  };

  /// The mark of a door of the Immeuble grid: its status, as a single
  /// house.
  static TileMark ofDwelling(Dwelling dwelling) => _ofStatus(dwelling.status);

  static TileMark _ofStatus(VisitStatus status) => switch (status) {
    VisitStatus.toDo => const ToDoMark(),
    VisitStatus.done => const DoneMark(),
    VisitStatus.nobodyHome => const NobodyHomeMark(),
    VisitStatus.comeBack => const ComeBackMark(),
  };
}

/// ○ Not visited yet.
final class ToDoMark extends TileMark {
  const ToDoMark();
}

/// ✓ Calendar handed over (a building: every door).
final class DoneMark extends TileMark {
  const DoneMark();
}

/// ✗ Nobody answered.
final class NobodyHomeMark extends TileMark {
  const NobodyHomeMark();
}

/// ↻ « Repasser »: asked to come back later (a building: its own).
final class ComeBackMark extends TileMark {
  const ComeBackMark();
}

/// ◐ A building where [done] of its [total] doors are done.
final class PartialBuildingMark extends TileMark {
  const PartialBuildingMark({required this.done, required this.total});

  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is PartialBuildingMark &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => 'PartialBuildingMark($done/$total)';
}

/// One tile of the street screen.
final class HouseTile {
  const HouseTile({
    required this.number,
    required this.mark,
    required this.hasNote,
    required this.isBuilding,
  });

  /// The tile of [house].
  factory HouseTile.of(House house) => HouseTile(
    number: house.number,
    mark: TileMark.of(house),
    hasNote: house.note != Note.empty,
    isBuilding: house.isBuilding,
  );

  /// Which house; its `label` is what the tile shows (`3bis`).
  final HouseNumber number;
  final TileMark mark;

  /// A note was written on the house (or on the building itself): the tile
  /// shows a small dot.
  final bool hasNote;

  /// A tap opens the building's grid instead of cycling a status.
  final bool isBuilding;

  @override
  bool operator ==(Object other) =>
      other is HouseTile &&
      other.number == number &&
      other.mark == mark &&
      other.hasNote == hasNote &&
      other.isBuilding == isBuilding;

  @override
  int get hashCode => Object.hash(number, mark, hasNote, isBuilding);

  @override
  String toString() =>
      'HouseTile(${number.label}, $mark, note: $hasNote, '
      'building: $isBuilding)';
}

/// Which columns the screen shows. Decided on every house of the street,
/// not on the ones « Masquer faits » leaves, so the layout does not jump
/// when a side is all done.
enum StreetColumns {
  /// Odd on the left, even on the right (also a street without numbers).
  both,

  /// The street only has odd numbers: one column.
  oddOnly,

  /// The street only has even numbers: one column.
  evenOnly;

  /// The columns of a street whose sides hold [odd] and [even] numbers:
  /// one column when one side is empty and the other is not.
  static StreetColumns of({required int odd, required int even}) =>
      switch ((odd == 0, even == 0)) {
        (false, true) => StreetColumns.oddOnly,
        (true, false) => StreetColumns.evenOnly,
        _ => StreetColumns.both,
      };
}

/// Everything the street screen shows. `sealed`: the screen handles each
/// case.
sealed class StreetViewState {
  const StreetViewState();
}

/// The street is being read from the phone (a moment, at most).
final class StreetLoading extends StreetViewState {
  const StreetLoading();
}

/// No such street on the phone, or it went to the Corbeille: the screen
/// says so and offers the way back.
final class StreetGone extends StreetViewState {
  const StreetGone();
}

/// The street, ready to mark.
final class StreetShown extends StreetViewState {
  StreetShown({
    required this.name,
    required this.done,
    required this.total,
    required this.nobodyHome,
    required this.comeBack,
    required this.hideDone,
    required this.columns,
    required List<HouseTile> odd,
    required List<HouseTile> even,
  }) : odd = List.unmodifiable(odd),
       even = List.unmodifiable(even);

  final String name;

  /// Header counts « 31/42 · ✗ 3 · ↻ 1 »: doors done, doors (a building
  /// counts its doors), nobody home, places to come back to (doors
  /// « repasser » and buildings with their own). Whatever is hidden.
  final int done;
  final int total;
  final int nobodyHome;
  final int comeBack;

  /// « Masquer faits » is on: [odd] and [even] leave out the done tiles.
  final bool hideDone;
  final StreetColumns columns;

  /// The tiles of each side, in street order (`3 < 3bis < 3A < 4`).
  final List<HouseTile> odd;
  final List<HouseTile> even;

  /// How much of the progress bar is filled, 0 to 1.
  double get fraction => total == 0 ? 0 : done / total;
}

/// What a tap changed, for the snackbar « 7 → Personne » and the
/// screen-reader announcement.
final class MarkedHouse {
  const MarkedHouse({required this.number, required this.status});

  final HouseNumber number;

  /// The status the house now has.
  final VisitStatus status;

  @override
  bool operator ==(Object other) =>
      other is MarkedHouse && other.number == number && other.status == status;

  @override
  int get hashCode => Object.hash(number, status);

  @override
  String toString() => 'MarkedHouse(${number.label}, $status)';
}
