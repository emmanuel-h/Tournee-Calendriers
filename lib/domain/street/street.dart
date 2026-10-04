import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/building_status.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// Why a list of houses cannot make a [Street].
enum NewStreetFailure {
  /// Two houses have the same number (`12bis` and `12 BIS` included).
  duplicateHouseNumber,
}

/// Why a command on one house of a [Street] was refused.
enum HouseChangeFailure {
  /// The street has no house with that number.
  unknownHouse,

  /// A « repasser » was asked on a house that is already done.
  comeBackOnDoneHouse,

  /// A building was to be marked as a whole: its doors are marked one by
  /// one, and its status follows from them.
  houseIsBuilding,
}

/// Why a command on one door of a building was refused.
enum DwellingChangeFailure {
  /// The street has no house with that number.
  unknownHouse,

  /// The house is a single house, not a building.
  notABuilding,

  /// The building has no door with that staircase, floor and label.
  unknownDwelling,

  /// A « repasser » was asked on a door that is already done.
  comeBackOnDoneDwelling,
}

/// A street of the tournée and its houses: the aggregate root that guards
/// every change to them (PLAN §6.1).
///
/// Invariants, true of every `Street`:
/// - each house number appears once;
/// - [houses] is sorted by [HouseNumber] (`3 < 3bis < 3A < 4`);
/// - a done house or door has no « repasser » (see [House], [Dwelling]);
/// - a building is to do itself, its doors carry the statuses (see [House]);
/// - the invariants of each [Building].
///
/// A `Street` is immutable. Each command returns a new street together with
/// the [StreetChange] it made, as a Dart record `(Street, Change)`; storage
/// writes only that change (PLAN §6.2). A command that can be refused
/// returns a [Result] instead of throwing.
final class Street {
  const Street._({
    required this.id,
    required this.name,
    required this.commune,
    required this.banId,
    required this.houses,
    required this.deletion,
  });

  /// Builds a street from its identity and its [houses], given in any order.
  ///
  /// Fails with [NewStreetFailure.duplicateHouseNumber] when two houses share
  /// a number. A street created with a [deletion] is in the Corbeille.
  static Result<Street, NewStreetFailure> create({
    required StreetId id,
    required String name,
    required Commune commune,
    BanStreetId? banId,
    Iterable<House> houses = const [],
    ChangeStamp? deletion,
  }) {
    // `..sort(…)` is a cascade: it sorts the new list and the expression
    // still evaluates to the list, not to the `void` that `sort` returns.
    final sorted = houses.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    // Once sorted, equal numbers sit next to each other.
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].number == sorted[i - 1].number) {
        return const Err(NewStreetFailure.duplicateHouseNumber);
      }
    }
    return Ok(
      Street._(
        id: id,
        name: name,
        commune: commune,
        banId: banId,
        houses: List.unmodifiable(sorted),
        deletion: deletion,
      ),
    );
  }

  final StreetId id;

  /// The name as the BAN writes it (« Rue des Lilas »).
  final String name;

  final Commune commune;

  /// The street in the BAN; null for a street typed in by hand.
  final BanStreetId? banId;

  /// Every house, sorted by number. The list cannot be modified (it throws
  /// an `UnsupportedError`): houses change only through the commands below.
  final List<House> houses;

  /// Who sent the street to the Corbeille and when; null when it is not
  /// deleted.
  final ChangeStamp? deletion;

  /// Whether the street is in the Corbeille.
  bool get isDeleted => deletion != null;

  /// The odd side of the street (left column of PLAN §5.6), in order.
  List<House> get oddHouses =>
      List.unmodifiable(houses.where((house) => house.number.isOdd));

  /// The even side of the street (right column), 0 included, in order.
  List<House> get evenHouses =>
      List.unmodifiable(houses.where((house) => house.number.isEven));

  /// The progress of the whole street: the sum of its houses' progress (a
  /// building counts its doors).
  Progress get progress =>
      houses.fold(Progress.empty, (sum, house) => sum + house.progress);

  /// Gives the house at [number] the [status], as [by] at [at].
  ///
  /// Marking a house done also removes its « repasser »: the residents have
  /// been seen, there is nothing left to come back for (the tap logic of the
  /// approved Main mockup). Any other status keeps it.
  ///
  /// Refused with [HouseChangeFailure.houseIsBuilding] on a building: mark
  /// its doors with [markDwelling].
  Result<(Street, HouseMarked), HouseChangeFailure> markHouse(
    HouseNumber number,
    VisitStatus status, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(HouseChangeFailure.unknownHouse);
    final before = houses[index];
    if (before.isBuilding) return const Err(HouseChangeFailure.houseIsBuilding);
    final stamp = ChangeStamp(by: by, at: at);
    // The House factory drops the come-back when the status is done.
    final after = House(
      number: number,
      status: status,
      comeBack: before.comeBack,
      note: before.note,
      lastChange: stamp,
    );
    return Ok((
      _withHouseAt(index, after),
      HouseMarked(streetId: id, before: before, stamp: stamp, status: status),
    ));
  }

  /// Sets the « repasser » of the house at [number] to [comeBack], or
  /// removes it when [comeBack] is null, as [by] at [at]. On a building, it
  /// is the building's own « repasser » (its doors keep theirs).
  ///
  /// Refused with [HouseChangeFailure.comeBackOnDoneHouse] on a done house:
  /// it would be dropped at once (see [House]), and silently ignoring the
  /// request would hide that from the user. Move the house out of done first.
  Result<(Street, ComeBackSet), HouseChangeFailure> setComeBack(
    HouseNumber number,
    ComeBack? comeBack, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(HouseChangeFailure.unknownHouse);
    final before = houses[index];
    if (comeBack != null && before.status == VisitStatus.done) {
      return const Err(HouseChangeFailure.comeBackOnDoneHouse);
    }
    final stamp = ChangeStamp(by: by, at: at);
    final after = House(
      number: number,
      status: before.status,
      comeBack: comeBack,
      note: before.note,
      lastChange: stamp,
      building: before.building,
    );
    return Ok((
      _withHouseAt(index, after),
      ComeBackSet(
        streetId: id,
        before: before,
        stamp: stamp,
        comeBack: comeBack,
      ),
    ));
  }

  /// Replaces the note of the house at [number] with [note] (erase it with
  /// [Note.empty]), as [by] at [at]. On a building, it is the building's own
  /// note (« digicode »).
  Result<(Street, NoteSet), HouseChangeFailure> setNote(
    HouseNumber number,
    Note note, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(HouseChangeFailure.unknownHouse);
    final before = houses[index];
    final stamp = ChangeStamp(by: by, at: at);
    final after = House(
      number: number,
      status: before.status,
      comeBack: before.comeBack,
      note: note,
      lastChange: stamp,
      building: before.building,
    );
    return Ok((
      _withHouseAt(index, after),
      NoteSet(streetId: id, before: before, stamp: stamp, note: note),
    ));
  }

  /// Makes the house at [number] the building [plan] lays out, as [by] at
  /// [at] (« Transformer en immeuble… », PLAN §5.7).
  ///
  /// On a house that is already a building (« Modifier les étages »), the
  /// doors whose label still exists on the same floor of the same staircase
  /// keep their
  /// marks; the others are dropped (the screen asks first). Either way the
  /// house keeps its own note and « repasser », and its own status becomes
  /// to do: its doors carry the statuses now.
  Result<(Street, BuildingLaidOut), HouseChangeFailure> describeBuilding(
    HouseNumber number,
    BuildingPlan plan, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(HouseChangeFailure.unknownHouse);
    final building = Building.laidOut(plan, keeping: houses[index].building);
    return Ok(_laidOut(index, building, ChangeStamp(by: by, at: at)));
  }

  /// Adds a door at the end of the floor at [level] (null for the
  /// « Logements » row of unknown floors) of [staircase] in the building at
  /// [number], as [by] at [at]. See `Building.withDoorAdded` for its label.
  Result<(Street, BuildingLaidOut), BuildingChangeFailure> addDoor(
    HouseNumber number,
    StaircaseName staircase,
    int? level, {
    required MemberId by,
    required DateTime at,
  }) => _changeLayout(
    number,
    (building) => building.withDoorAdded(staircase, level),
    ChangeStamp(by: by, at: at),
  );

  /// Removes the door at [key] of the building at [number], as [by] at
  /// [at]. The last door of a building cannot be removed.
  Result<(Street, BuildingLaidOut), BuildingChangeFailure> removeDoor(
    HouseNumber number,
    DwellingKey key, {
    required MemberId by,
    required DateTime at,
  }) => _changeLayout(
    number,
    (building) => building.withoutDoor(key),
    ChangeStamp(by: by, at: at),
  );

  /// Gives the door at [key] of the building at [number] the [label], its
  /// marks kept, as [by] at [at]. Refused when another door of the
  /// floor has that label.
  Result<(Street, BuildingLaidOut), BuildingChangeFailure> renameDoor(
    HouseNumber number,
    DwellingKey key,
    DwellingLabel label, {
    required MemberId by,
    required DateTime at,
  }) => _changeLayout(
    number,
    (building) => building.withDoorRenamed(key, label),
    ChangeStamp(by: by, at: at),
  );

  /// Turns the building at [number] back into a single house, as [by] at
  /// [at] (« or back to a single house », PLAN §5.5). Its doors are
  /// dropped (the screen asks first); the house is done when every door
  /// was done, to do otherwise, and keeps its note and « repasser » (which
  /// a done house drops).
  Result<(Street, BuildingRemoved), BuildingChangeFailure> removeBuilding(
    HouseNumber number, {
    required MemberId by,
    required DateTime at,
  }) {
    switch (_buildingAt(number)) {
      case Err(:final failure):
        return Err(failure);
      // A record pattern inside an object pattern: it takes the (position,
      // building) pair out of the `Ok` in one step.
      case Ok(value: (final index, final building)):
        final before = houses[index];
        final status = switch (building.status) {
          BuildingStatus.done => VisitStatus.done,
          BuildingStatus.partial || BuildingStatus.toDo => VisitStatus.toDo,
        };
        final stamp = ChangeStamp(by: by, at: at);
        final after = House(
          number: number,
          status: status,
          comeBack: before.comeBack,
          note: before.note,
          lastChange: stamp,
        );
        return Ok((
          _withHouseAt(index, after),
          BuildingRemoved(
            streetId: id,
            before: before,
            stamp: stamp,
            status: status,
          ),
        ));
    }
  }

  /// Gives the door at [key] of the building at [number] the [status], as
  /// [by] at [at] (a tap on the door). Marking a door done removes its
  /// « repasser », like a house's.
  ///
  /// The house itself is untouched (its last change included): the door
  /// keeps its own.
  Result<(Street, DwellingMarked), DwellingChangeFailure> markDwelling(
    HouseNumber number,
    DwellingKey key,
    VisitStatus status, {
    required MemberId by,
    required DateTime at,
  }) {
    switch (_dwellingAt(number, key)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: (final index, final before)):
        final stamp = ChangeStamp(by: by, at: at);
        final after = Dwelling(
          label: before.label,
          status: status,
          comeBack: before.comeBack,
          note: before.note,
          lastChange: stamp,
        );
        return Ok((
          _withDwellingAt(index, key, after),
          DwellingMarked(
            streetId: id,
            number: number,
            staircase: key.staircase,
            level: key.level,
            before: before,
            stamp: stamp,
            status: status,
          ),
        ));
    }
  }

  /// Sets the « repasser » of the door at [key] of the building at [number]
  /// to [comeBack], or removes it when [comeBack] is null, as [by] at [at].
  /// Refused on a done door, for the reason given in [setComeBack].
  Result<(Street, DwellingComeBackSet), DwellingChangeFailure>
  setDwellingComeBack(
    HouseNumber number,
    DwellingKey key,
    ComeBack? comeBack, {
    required MemberId by,
    required DateTime at,
  }) {
    switch (_dwellingAt(number, key)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: (final index, final before)):
        if (comeBack != null && before.status == VisitStatus.done) {
          return const Err(DwellingChangeFailure.comeBackOnDoneDwelling);
        }
        final stamp = ChangeStamp(by: by, at: at);
        final after = Dwelling(
          label: before.label,
          status: before.status,
          comeBack: comeBack,
          note: before.note,
          lastChange: stamp,
        );
        return Ok((
          _withDwellingAt(index, key, after),
          DwellingComeBackSet(
            streetId: id,
            number: number,
            staircase: key.staircase,
            level: key.level,
            before: before,
            stamp: stamp,
            comeBack: comeBack,
          ),
        ));
    }
  }

  /// Replaces the note of the door at [key] of the building at [number]
  /// with [note] (erase it with [Note.empty]), as [by] at [at].
  Result<(Street, DwellingNoteSet), DwellingChangeFailure> setDwellingNote(
    HouseNumber number,
    DwellingKey key,
    Note note, {
    required MemberId by,
    required DateTime at,
  }) {
    switch (_dwellingAt(number, key)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: (final index, final before)):
        final stamp = ChangeStamp(by: by, at: at);
        final after = Dwelling(
          label: before.label,
          status: before.status,
          comeBack: before.comeBack,
          note: note,
          lastChange: stamp,
        );
        return Ok((
          _withDwellingAt(index, key, after),
          DwellingNoteSet(
            streetId: id,
            number: number,
            staircase: key.staircase,
            level: key.level,
            before: before,
            stamp: stamp,
            note: note,
          ),
        ));
    }
  }

  /// Sends the street to the Corbeille, as [by] at [at]: it is hidden but
  /// keeps its houses, statuses and notes (PLAN §5.11). Deleting a street
  /// already in the Corbeille records the latest deletion.
  (Street, StreetDeleted) delete({required MemberId by, required DateTime at}) {
    final deletion = ChangeStamp(by: by, at: at);
    return (
      _copy(houses: houses, deletion: deletion),
      StreetDeleted(streetId: id, deletion: deletion),
    );
  }

  /// Brings the street back from the Corbeille, houses untouched.
  (Street, StreetRestored) restore() =>
      (_copy(houses: houses, deletion: null), StreetRestored(streetId: id));

  /// The position of [number] in [houses], or -1 when the street has none.
  int _indexOf(HouseNumber number) =>
      houses.indexWhere((house) => house.number == number);

  /// The position of the building at [number] and the building, or why
  /// there is none.
  Result<(int, Building), BuildingChangeFailure> _buildingAt(
    HouseNumber number,
  ) {
    final index = _indexOf(number);
    if (index < 0) return const Err(BuildingChangeFailure.unknownHouse);
    final building = houses[index].building;
    if (building == null) return const Err(BuildingChangeFailure.notABuilding);
    return Ok((index, building));
  }

  /// The position of the building at [number] and its door at [key], or why
  /// there is none.
  Result<(int, Dwelling), DwellingChangeFailure> _dwellingAt(
    HouseNumber number,
    DwellingKey key,
  ) {
    final index = _indexOf(number);
    if (index < 0) return const Err(DwellingChangeFailure.unknownHouse);
    final building = houses[index].building;
    if (building == null) return const Err(DwellingChangeFailure.notABuilding);
    final dwelling = building.dwellingAt(key);
    if (dwelling == null) {
      return const Err(DwellingChangeFailure.unknownDwelling);
    }
    return Ok((index, dwelling));
  }

  /// Runs [change] on the building at [number] and, when the building
  /// accepts it, stores the new layout stamped with [stamp].
  ///
  /// [change] is a function given by the caller (`addDoor` passes one that
  /// adds a door): the lookup and the storing are written once for the
  /// three per-floor adjustments.
  Result<(Street, BuildingLaidOut), BuildingChangeFailure> _changeLayout(
    HouseNumber number,
    Result<Building, BuildingChangeFailure> Function(Building) change,
    ChangeStamp stamp,
  ) {
    switch (_buildingAt(number)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: (final index, final building)):
        switch (change(building)) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: final changed):
            return Ok(_laidOut(index, changed, stamp));
        }
    }
  }

  /// This street with the house at [index] holding [building], stamped
  /// with [stamp], and the change saying so. The house keeps its note and
  /// « repasser »; the `House` factory makes it to do.
  (Street, BuildingLaidOut) _laidOut(
    int index,
    Building building,
    ChangeStamp stamp,
  ) {
    final before = houses[index];
    final after = House(
      number: before.number,
      comeBack: before.comeBack,
      note: before.note,
      lastChange: stamp,
      building: building,
    );
    return (
      _withHouseAt(index, after),
      BuildingLaidOut(
        streetId: id,
        before: before,
        stamp: stamp,
        building: building,
      ),
    );
  }

  /// This street with [dwelling] in place of the door at [key] of the
  /// building at [index]. The house is otherwise untouched, its last change
  /// included.
  Street _withDwellingAt(int index, DwellingKey key, Dwelling dwelling) {
    final house = houses[index];
    return _withHouseAt(
      index,
      House(
        number: house.number,
        comeBack: house.comeBack,
        note: house.note,
        lastChange: house.lastChange,
        // `!`: only called once `_dwellingAt` found the door in a building.
        building: house.building!.withDwelling(
          key.staircase,
          key.level,
          dwelling,
        ),
      ),
    );
  }

  /// This street with [house] in place of the house at [index]. The number
  /// does not change, so the order still holds.
  Street _withHouseAt(int index, House house) {
    final changed = houses.toList()..[index] = house;
    return _copy(houses: List.unmodifiable(changed), deletion: deletion);
  }

  /// This street, same identity, with [houses] and [deletion]. Both are
  /// required so no call can forget one (null is a real value of
  /// [deletion]: not in the Corbeille).
  Street _copy({required List<House> houses, required ChangeStamp? deletion}) =>
      Street._(
        id: id,
        name: name,
        commune: commune,
        banId: banId,
        houses: houses,
        deletion: deletion,
      );
}
