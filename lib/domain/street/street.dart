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

  /// A « repasser » hint was given to (or taken from) a single house that
  /// is not « repasser »: its « repasser » is its status, set with
  /// `markHouse`.
  notComeBack,

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

  /// A « repasser » hint was given to (or taken from) a door that is not
  /// « repasser »: its « repasser » is its status, set with `markDwelling`.
  notComeBack,
}

/// Why a change could not be undone (« Annuler » of the snackbar).
enum UndoFailure {
  /// The change was made on another street.
  otherStreet,

  /// The house, number or door the change touched is no longer there (it
  /// was removed, renumbered or laid out again since).
  gone,

  /// Undoing would give a house a number another house, shown or in the
  /// Corbeille, has taken since.
  numberTaken,

  /// The screens offer no undo for this change: added numbers are removed
  /// with ✕, a street brought back from the Corbeille is deleted again.
  notUndoable,
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
/// - a single house or a door has a « repasser » hint exactly when its
///   status is « repasser » (see [House], [Dwelling]);
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
  /// The hint of a « repasser » goes with that status: leaving « repasser »
  /// drops it, coming to « repasser » starts without one (the sheet's field
  /// then gives it), see [HouseMarked.comeBack].
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
    // The House factory keeps the come-back only for « repasser ».
    final after = House(
      number: number,
      status: status,
      comeBack: before.comeBack,
      lastChange: stamp,
      position: before.position,
    );
    return Ok((
      _withHouseAt(index, after),
      HouseMarked(streetId: id, before: before, stamp: stamp, status: status),
    ));
  }

  /// Sets the « repasser » of the house at [number] to [comeBack], as [by]
  /// at [at] (the hint field of its sheet).
  ///
  /// On a building, it is the building's own « repasser » (its doors keep
  /// theirs), removed when [comeBack] is null. On a single house only the
  /// hint changes: « repasser » is its status, given with [markHouse] and
  /// left by giving another. So it is refused with
  /// [HouseChangeFailure.notComeBack] when the single house is not
  /// « repasser », or when [comeBack] is null: dropping the request
  /// silently would hide that from the user.
  Result<(Street, ComeBackSet), HouseChangeFailure> setComeBack(
    HouseNumber number,
    ComeBack? comeBack, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(HouseChangeFailure.unknownHouse);
    final before = houses[index];
    if (!before.isBuilding &&
        (comeBack == null || before.status != VisitStatus.comeBack)) {
      return const Err(HouseChangeFailure.notComeBack);
    }
    final stamp = ChangeStamp(by: by, at: at);
    final after = House(
      number: number,
      status: before.status,
      comeBack: comeBack,
      lastChange: stamp,
      building: before.building,
      position: before.position,
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

  /// Makes the house at [number] the building [plan] lays out, as [by] at
  /// [at] (« Transformer en immeuble… », PLAN §5.7).
  ///
  /// On a house that is already a building (« Modifier les étages »), the
  /// doors whose label still exists on the same floor of the same staircase
  /// keep their
  /// marks; the others are dropped (the screen asks first). Either way the
  /// house keeps its own « repasser », and its own status becomes
  /// to do: its doors carry the statuses now.
  ///
  /// Fails with [BuildingChangeFailure.unknownHouse], like the other layout
  /// commands, so the « Modifier les étages » sheet handles one failure type.
  Result<(Street, BuildingLaidOut), BuildingChangeFailure> describeBuilding(
    HouseNumber number,
    BuildingPlan plan, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(BuildingChangeFailure.unknownHouse);
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
  /// was done; otherwise it is « repasser », with its hint, when the
  /// building had its own « repasser », and to do when not.
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
          BuildingStatus.partial || BuildingStatus.toDo =>
            before.comeBack == null ? VisitStatus.toDo : VisitStatus.comeBack,
        };
        final stamp = ChangeStamp(by: by, at: at);
        final after = House(
          number: number,
          status: status,
          comeBack: before.comeBack,
          lastChange: stamp,
          position: before.position,
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
  /// [by] at [at] (a tap on the door). The hint of a « repasser » goes with
  /// that status, as a house's.
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

  /// Sets the hint of the « repasser » of the door at [key] of the building
  /// at [number] to [comeBack], as [by] at [at]. Refused with
  /// [DwellingChangeFailure.notComeBack] when the door is not « repasser »
  /// or [comeBack] is null, for the reason given in [setComeBack].
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
        if (comeBack == null || before.status != VisitStatus.comeBack) {
          return const Err(DwellingChangeFailure.notComeBack);
        }
        final stamp = ChangeStamp(by: by, at: at);
        final after = Dwelling(
          label: before.label,
          status: before.status,
          comeBack: comeBack,
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
  /// at [at]: the house goes to the Corbeille with its status, « repasser »
  /// and building, hidden from the sides and the progress, until
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
  /// « repasser » and building, and moves to its new place and side.
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
  /// keeps its houses and their marks (PLAN §5.11). Deleting a street
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

  /// Undoes [change], made on this street a moment ago: puts back exactly
  /// what was there before it (PLAN §7: undo is a normal write of the
  /// previous value, not a rollback), and returns the change the undo
  /// makes, which can itself be undone.
  ///
  /// - A house change puts the whole house back as it was, status,
  ///   « repasser », building, last change and number included
  ///   ([HouseReverted]); a door change puts that door back
  ///   ([DwellingReverted]). Whatever changed on that house or door since
  ///   is overwritten, as a teammate's later write would be.
  /// - A removed number comes back from the Corbeille, a restored one goes
  ///   back there with its old removal, a renamed street gets its old name,
  ///   a deleted street comes back.
  ///
  /// Refused with an [UndoFailure] when the change is not this street's,
  /// when what it touched is gone, when the old number is taken again, or
  /// for changes the screens never undo.
  Result<(Street, StreetChange), UndoFailure> undo(StreetChange change) {
    if (change.streetId != id) return const Err(UndoFailure.otherStreet);
    return switch (change) {
      // Before the general house case: a renamed house is now under its
      // new number. A `switch` takes the first case that matches.
      NumberRenamed(:final newNumber, :final before) => _revertHouse(
        newNumber,
        before,
      ),
      HouseChange(:final number, :final before) => _revertHouse(number, before),
      HouseReverted(:final house, :final replaced) => _revertHouse(
        house.number,
        replaced,
      ),
      DwellingChange(:final number, :final key, :final before) =>
        _revertDwelling(number, key, before),
      DwellingReverted(:final number, :final key, :final replaced) =>
        _revertDwelling(number, key, replaced),
      NumberRemoved(:final number) => switch (restoreNumber(number)) {
        Ok(:final value) => Ok(value),
        Err() => const Err(UndoFailure.gone),
      },
      NumberRestored(:final removed) => switch (removeNumber(
        removed.number,
        by: removed.removal.by,
        at: removed.removal.at,
      )) {
        Ok(:final value) => Ok(value),
        Err() => const Err(UndoFailure.gone),
      },
      StreetRenamed(:final before) => Ok((
        _copy(
          name: before,
          houses: houses,
          removedHouses: removedHouses,
          deletion: deletion,
        ),
        StreetRenamed(streetId: id, before: name, name: before),
      )),
      StreetDeleted() => Ok(restore()),
      NumbersAdded() || StreetRestored() => const Err(UndoFailure.notUndoable),
    };
  }

  /// This street with [back] in place of the house now numbered [now], and
  /// the [HouseReverted] saying so. When [back] has another number (a
  /// renumbering undone), that number must be free again.
  Result<(Street, StreetChange), UndoFailure> _revertHouse(
    HouseNumber now,
    House back,
  ) {
    final index = _indexOf(now);
    if (index < 0) return const Err(UndoFailure.gone);
    if (back.number != now &&
        (_indexOf(back.number) >= 0 || _removedAt(back.number) != null)) {
      return const Err(UndoFailure.numberTaken);
    }
    return Ok((
      _copy(
        name: name,
        houses: _sortedHouses(houses.toList()..[index] = back),
        removedHouses: removedHouses,
        deletion: deletion,
      ),
      HouseReverted(streetId: id, replaced: houses[index], house: back),
    ));
  }

  /// This street with [back] in place of the door at [key] of the building
  /// at [number], and the [DwellingReverted] saying so.
  Result<(Street, StreetChange), UndoFailure> _revertDwelling(
    HouseNumber number,
    DwellingKey key,
    Dwelling back,
  ) => switch (_dwellingAt(number, key)) {
    Err() => const Err(UndoFailure.gone),
    Ok(value: (final index, final now)) => Ok((
      _withDwellingAt(index, key, back),
      DwellingReverted(
        streetId: id,
        number: number,
        staircase: key.staircase,
        level: key.level,
        replaced: now,
        dwelling: back,
      ),
    )),
  };

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
  /// with [stamp], and the change saying so. The house keeps its own
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
      lastChange: stamp,
      building: building,
      position: before.position,
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
        lastChange: house.lastChange,
        // `!`: only called once `_dwellingAt` found the door in a building.
        building: house.building!.withDwelling(
          key.staircase,
          key.level,
          dwelling,
        ),
        position: house.position,
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
