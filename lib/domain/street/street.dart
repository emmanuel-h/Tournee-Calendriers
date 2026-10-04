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
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// Why a list of houses cannot make a [Street].
enum NewStreetFailure {
  /// Two houses have the same number (`12bis` and `12 BIS` included),
  /// whether shown or removed.
  duplicateHouseNumber,

  /// The name is not a valid [StreetName] (blank or too long).
  invalidName,
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

/// Why a change to the numbers of a [Street] (edit mode, PLAN §5.5) was
/// refused.
enum NumberChangeFailure {
  /// The street shows no house with that number.
  unknownHouse,

  /// No house with that number is in the Corbeille.
  notRemoved,

  /// The new number is the number the house already has.
  sameNumber,

  /// Another house of the street shows the new number.
  numberTaken,

  /// A house in the Corbeille has the new number: restore it, or choose
  /// another number.
  numberRemoved,

  /// Every number to add is already shown (or none was given): nothing
  /// would change.
  nothingNew,
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
/// - its name is a valid [StreetName];
/// - each house number appears once, among the [houses] and the
///   [removedHouses] together (the number is the key in storage);
/// - [houses] and [removedHouses] are sorted by [HouseNumber]
///   (`3 < 3bis < 3A < 4`);
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
    required this.removedHouses,
    required this.deletion,
  });

  /// Builds a street from its identity and its [houses], given in any order
  /// (from the BAN, or from storage with its [removedHouses]).
  ///
  /// The [name] is cleaned like a typed [StreetName]. Fails with
  /// [NewStreetFailure.invalidName] when it is not one, and with
  /// [NewStreetFailure.duplicateHouseNumber] when two houses, shown or
  /// removed, share a number. A street created with a [deletion] is in the
  /// Corbeille.
  static Result<Street, NewStreetFailure> create({
    required StreetId id,
    required String name,
    required Commune commune,
    BanStreetId? banId,
    Iterable<House> houses = const [],
    Iterable<RemovedHouse> removedHouses = const [],
    ChangeStamp? deletion,
  }) {
    final StreetName streetName;
    switch (StreetName.create(name)) {
      case Ok(:final value):
        streetName = value;
      case Err():
        return const Err(NewStreetFailure.invalidName);
    }
    // `..sort()` is a cascade: it sorts the new list and the expression
    // still evaluates to the list, not to the `void` that `sort` returns.
    final numbers = [
      for (final house in houses) house.number,
      for (final removed in removedHouses) removed.number,
    ]..sort();
    // Once sorted, equal numbers sit next to each other.
    for (var i = 1; i < numbers.length; i++) {
      if (numbers[i] == numbers[i - 1]) {
        return const Err(NewStreetFailure.duplicateHouseNumber);
      }
    }
    return Ok(
      Street._(
        id: id,
        name: streetName.text,
        commune: commune,
        banId: banId,
        houses: _sortedHouses(houses),
        removedHouses: _sortedRemoved(removedHouses),
        deletion: deletion,
      ),
    );
  }

  /// A street typed in by hand (« Rue à la main », PLAN §5.5): no BAN id,
  /// and a new house, to do, for each of the [numbers] (each once, whatever
  /// the order; usually from `manualStreetNumbers`). It cannot fail: the
  /// [name] is already valid and repeated numbers are merged.
  factory Street.manual({
    required StreetId id,
    required StreetName name,
    required Commune commune,
    required Iterable<HouseNumber> numbers,
  }) => Street._(
    id: id,
    name: name.text,
    commune: commune,
    banId: null,
    houses: _sortedHouses([
      for (final number in numbers.toSet()) House(number: number),
    ]),
    removedHouses: const [],
    deletion: null,
  );

  final StreetId id;

  /// The name as the BAN writes it (« Rue des Lilas ») or as typed, cleaned
  /// (see [StreetName]).
  final String name;

  final Commune commune;

  /// The street in the BAN; null for a street typed in by hand.
  final BanStreetId? banId;

  /// Every house, sorted by number. The list cannot be modified (it throws
  /// an `UnsupportedError`): houses change only through the commands below.
  final List<House> houses;

  /// The houses whose number was removed in edit mode, sorted by number:
  /// in the Corbeille with their marks, out of the sides and the progress,
  /// until restored (PLAN §5.11). The list cannot be modified.
  final List<RemovedHouse> removedHouses;

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

  /// Adds [numbers] to the street (« Ajouter des numéros », PLAN §5.5;
  /// usually from `parseHouseNumbers`). Each lands in its place and on its
  /// side by its number.
  ///
  /// A number the street already shows is left as it is; one in the
  /// Corbeille comes back with its marks, as « Restaurer » would bring it
  /// (re-adding a number removed by mistake must not lose its status). The
  /// change lists the three groups. Fails with
  /// [NumberChangeFailure.nothingNew] when nothing would change.
  Result<(Street, NumbersAdded), NumberChangeFailure> addNumbers(
    Iterable<HouseNumber> numbers,
  ) {
    final added = <House>[];
    final restored = <RemovedHouse>[];
    final alreadyThere = <HouseNumber>[];
    for (final number in numbers.toSet().toList()..sort()) {
      final removed = _removedAt(number);
      if (_indexOf(number) >= 0) {
        alreadyThere.add(number);
      } else if (removed != null) {
        restored.add(removed);
      } else {
        added.add(House(number: number));
      }
    }
    if (added.isEmpty && restored.isEmpty) {
      return const Err(NumberChangeFailure.nothingNew);
    }
    return Ok((
      _copy(
        name: name,
        houses: _sortedHouses([
          ...houses,
          ...added,
          for (final removed in restored) removed.house,
        ]),
        removedHouses: List.unmodifiable(
          removedHouses.where((removed) => !restored.contains(removed)),
        ),
        deletion: deletion,
      ),
      NumbersAdded(
        streetId: id,
        added: added,
        restored: restored,
        alreadyThere: alreadyThere,
      ),
    ));
  }

  /// Removes the number [number] from the street (✕ in edit mode), as [by]
  /// at [at]: the house goes to the Corbeille with its status, « repasser »,
  /// note and building, hidden from the sides and the progress, until
  /// [restoreNumber] (PLAN §5.11).
  ///
  /// It is allowed even when the house has marks; the screen asks first
  /// (check `House.hasMarks` before calling) and the change says
  /// [NumberRemoved.hadMarks].
  Result<(Street, NumberRemoved), NumberChangeFailure> removeNumber(
    HouseNumber number, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(NumberChangeFailure.unknownHouse);
    final removed = RemovedHouse(
      house: houses[index],
      removal: ChangeStamp(by: by, at: at),
    );
    return Ok((
      _copy(
        name: name,
        houses: List.unmodifiable(houses.toList()..removeAt(index)),
        removedHouses: _sortedRemoved([...removedHouses, removed]),
        deletion: deletion,
      ),
      NumberRemoved(streetId: id, removed: removed),
    ));
  }

  /// Brings the house at [number] back from the Corbeille, exactly as it
  /// was removed (« Restaurer », or the undo of ✕).
  Result<(Street, NumberRestored), NumberChangeFailure> restoreNumber(
    HouseNumber number,
  ) {
    final removed = _removedAt(number);
    if (removed == null) return const Err(NumberChangeFailure.notRemoved);
    return Ok((
      _copy(
        name: name,
        houses: _sortedHouses([...houses, removed.house]),
        removedHouses: List.unmodifiable(
          removedHouses.where((other) => other != removed),
        ),
        deletion: deletion,
      ),
      NumberRestored(streetId: id, removed: removed),
    ));
  }

  /// Gives the house at [number] the number [newNumber] (`3` → `3bis`, a tap
  /// on a tile in edit mode), as [by] at [at]. It keeps its status,
  /// « repasser », note and building, and moves to its new place and side.
  ///
  /// Refused when [newNumber] is the same, is shown by another house
  /// ([NumberChangeFailure.numberTaken]) or belongs to a house in the
  /// Corbeille ([NumberChangeFailure.numberRemoved]): numbers stay unique,
  /// and merging two houses' marks has no right answer.
  Result<(Street, NumberRenamed), NumberChangeFailure> renameNumber(
    HouseNumber number,
    HouseNumber newNumber, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(NumberChangeFailure.unknownHouse);
    if (newNumber == number) return const Err(NumberChangeFailure.sameNumber);
    if (_indexOf(newNumber) >= 0) {
      return const Err(NumberChangeFailure.numberTaken);
    }
    if (_removedAt(newNumber) != null) {
      return const Err(NumberChangeFailure.numberRemoved);
    }
    final change = NumberRenamed(
      streetId: id,
      before: houses[index],
      stamp: ChangeStamp(by: by, at: at),
      newNumber: newNumber,
    );
    return Ok((
      _copy(
        name: name,
        houses: _sortedHouses(houses.toList()..[index] = change.after),
        removedHouses: removedHouses,
        deletion: deletion,
      ),
      change,
    ));
  }

  /// Gives the street the [name] typed in the name field of the edit mode,
  /// for the whole team (PLAN §5.5).
  (Street, StreetRenamed) renameStreet(StreetName name) => (
    _copy(
      name: name.text,
      houses: houses,
      removedHouses: removedHouses,
      deletion: deletion,
    ),
    StreetRenamed(streetId: id, before: this.name, name: name.text),
  );

  /// Sends the street to the Corbeille, as [by] at [at]: it is hidden but
  /// keeps its houses, statuses and notes (PLAN §5.11). Deleting a street
  /// already in the Corbeille records the latest deletion.
  (Street, StreetDeleted) delete({required MemberId by, required DateTime at}) {
    final deletion = ChangeStamp(by: by, at: at);
    return (
      _copy(
        name: name,
        houses: houses,
        removedHouses: removedHouses,
        deletion: deletion,
      ),
      StreetDeleted(streetId: id, deletion: deletion),
    );
  }

  /// Brings the street back from the Corbeille, houses untouched.
  (Street, StreetRestored) restore() => (
    _copy(
      name: name,
      houses: houses,
      removedHouses: removedHouses,
      deletion: null,
    ),
    StreetRestored(streetId: id),
  );

  /// The position of [number] in [houses], or -1 when the street has none.
  int _indexOf(HouseNumber number) =>
      houses.indexWhere((house) => house.number == number);

  /// The house at [number] in the Corbeille, or null when there is none.
  RemovedHouse? _removedAt(HouseNumber number) {
    for (final removed in removedHouses) {
      if (removed.number == number) return removed;
    }
    return null;
  }

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
    return _copy(
      name: name,
      houses: List.unmodifiable(changed),
      removedHouses: removedHouses,
      deletion: deletion,
    );
  }

  /// This street, same id, commune and BAN id, with the other fields given.
  /// They are all required so no call can forget one (null is a real value
  /// of [deletion]: not in the Corbeille). The lists must already be sorted
  /// and unmodifiable.
  Street _copy({
    required String name,
    required List<House> houses,
    required List<RemovedHouse> removedHouses,
    required ChangeStamp? deletion,
  }) => Street._(
    id: id,
    name: name,
    commune: commune,
    banId: banId,
    houses: houses,
    removedHouses: removedHouses,
    deletion: deletion,
  );

  /// [houses] sorted by number, in a list nobody can modify.
  static List<House> _sortedHouses(Iterable<House> houses) => List.unmodifiable(
    houses.toList()..sort((a, b) => a.number.compareTo(b.number)),
  );

  /// [removed] sorted by number, in a list nobody can modify.
  static List<RemovedHouse> _sortedRemoved(Iterable<RemovedHouse> removed) =>
      List.unmodifiable(
        removed.toList()..sort((a, b) => a.number.compareTo(b.number)),
      );
}
