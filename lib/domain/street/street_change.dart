import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// What one command of a `Street` changed, returned next to the new street.
///
/// Storage writes only what a change names: from M2 the Firestore adapter
/// turns a [HouseMarked] on house `12` into a write of the field paths
/// `houses.12.status`, `houses.12.by` and `houses.12.at` (PLAN §6.2), so two
/// people marking different houses of the same street never overwrite each
/// other. The phone storage of M1 (T1.6) can simply save the new street.
///
/// `sealed`: these classes are the only changes, so a `switch` over a
/// `StreetChange` in an adapter must handle each one, and a new change
/// breaks the build there until it is handled.
sealed class StreetChange {
  const StreetChange({required this.streetId});

  /// The street that changed, so a change can be stored or undone on its
  /// own (the undo use case keeps only the last change).
  final StreetId streetId;
}

/// A change to one house of the street.
///
/// It carries the house as it was ([before]) so undo can put that exact
/// house back (PLAN §7: undo is a normal write of the previous value).
/// The new values are the fields of each subclass, plus [stamp]: who made
/// the change and when, which becomes the house's `lastChange`.
sealed class HouseChange extends StreetChange {
  const HouseChange({
    required super.streetId,
    required this.before,
    required this.stamp,
  });

  /// The house before the change, untouched.
  final House before;

  /// Who made the change and when: the house's new last change.
  final ChangeStamp stamp;

  /// The number of the house that changed, which is its key in storage.
  HouseNumber get number => before.number;

  /// Whether [other] names the same street, house before and stamp; each
  /// subclass compares its own new value on top of that.
  bool _sameHouseChange(HouseChange other) =>
      other.streetId == streetId &&
      other.before == before &&
      other.stamp == stamp;
}

/// The house at [number] was given a new [status] (a tap on its tile, or
/// the status control of its sheet).
final class HouseMarked extends HouseChange {
  const HouseMarked({
    required super.streetId,
    required super.before,
    required super.stamp,
    required this.status,
  });

  final VisitStatus status;

  /// The come-back the house has after the change, which storage writes
  /// with the status: the hint it already had when it stays « repasser »,
  /// none when it becomes « repasser », null with any other status (see
  /// `ComeBack.keptBy`).
  ComeBack? get comeBack => ComeBack.keptBy(status, before.comeBack);

  @override
  bool operator ==(Object other) =>
      other is HouseMarked && _sameHouseChange(other) && other.status == status;

  @override
  int get hashCode => Object.hash(streetId, before, stamp, status);

  @override
  String toString() =>
      'HouseMarked(${streetId.value}, ${number.label}, $status, $stamp)';
}

/// The « repasser » hint of the house at [number] was set to [comeBack];
/// on a building, its own « repasser » was set, or removed when
/// [comeBack] is null.
final class ComeBackSet extends HouseChange {
  const ComeBackSet({
    required super.streetId,
    required super.before,
    required super.stamp,
    required this.comeBack,
  });

  final ComeBack? comeBack;

  @override
  bool operator ==(Object other) =>
      other is ComeBackSet &&
      _sameHouseChange(other) &&
      other.comeBack == comeBack;

  @override
  int get hashCode => Object.hash(streetId, before, stamp, comeBack);

  @override
  String toString() =>
      'ComeBackSet(${streetId.value}, ${number.label}, $comeBack, $stamp)';
}

/// The house at [number] got the layout [building]: it was described as a
/// building, described again, or one of its doors was added, removed or
/// renamed (PLAN §5.7). The house is to do itself and keeps its own
/// « repasser »; the doors whose label survived keep theirs.
///
/// Storage writes the whole building (its label style and the
/// `houses.8.dwellings` map) with the house's `status`, `by` and `at`. A
/// layout change is rare and made in edit mode, so writing the whole map is
/// simpler than one write per door; the cost is that a teammate marking a
/// door of that building at the very same moment can be overwritten. Undo
/// puts [before] back, old layout and statuses included.
final class BuildingLaidOut extends HouseChange {
  const BuildingLaidOut({
    required super.streetId,
    required super.before,
    required super.stamp,
    required this.building,
  });

  final Building building;

  @override
  bool operator ==(Object other) =>
      other is BuildingLaidOut &&
      _sameHouseChange(other) &&
      other.building == building;

  @override
  int get hashCode => Object.hash(streetId, before, stamp, building);

  @override
  String toString() =>
      'BuildingLaidOut(${streetId.value}, ${number.label}, $building, $stamp)';
}

/// The building at [number] became a single house again, with [status]:
/// done when every door was done, otherwise « repasser » when the building
/// had its own, to do when not. Its doors are dropped; undo puts [before]
/// back with them.
///
/// Storage removes the dwellings and writes the house's `status`,
/// [comeBack], `by` and `at`.
final class BuildingRemoved extends HouseChange {
  const BuildingRemoved({
    required super.streetId,
    required super.before,
    required super.stamp,
    required this.status,
  });

  final VisitStatus status;

  /// The come-back the single house keeps: the building's own when it is
  /// « repasser », none otherwise.
  ComeBack? get comeBack => ComeBack.keptBy(status, before.comeBack);

  @override
  bool operator ==(Object other) =>
      other is BuildingRemoved &&
      _sameHouseChange(other) &&
      other.status == status;

  @override
  int get hashCode => Object.hash(streetId, before, stamp, status);

  @override
  String toString() =>
      'BuildingRemoved(${streetId.value}, ${number.label}, $status, $stamp)';
}

/// The house at [number] now has the number [newNumber] (« 3 » → « 3bis »
/// in edit mode, PLAN §5.5), with its status, « repasser » and
/// building.
///
/// The number is the house's key in storage (`houses.3`), so storage
/// deletes the entry under the old number and writes [after] under the new
/// one. Undo renames it back by putting [before] in place of [after].
final class NumberRenamed extends HouseChange {
  const NumberRenamed({
    required super.streetId,
    required super.before,
    required super.stamp,
    required this.newNumber,
  });

  final HouseNumber newNumber;

  /// The house under its new number, stamped with [stamp]; nothing else
  /// changes.
  House get after => House(
    number: newNumber,
    status: before.status,
    comeBack: before.comeBack,
    lastChange: stamp,
    building: before.building,
    position: before.position,
  );

  @override
  bool operator ==(Object other) =>
      other is NumberRenamed &&
      _sameHouseChange(other) &&
      other.newNumber == newNumber;

  @override
  int get hashCode => Object.hash(streetId, before, stamp, newNumber);

  @override
  String toString() =>
      'NumberRenamed(${streetId.value}, ${number.label} → ${newNumber.label}, '
      '$stamp)';
}

/// A change to one door of the building at [number] (a tap on the door, or
/// its sheet on a long press).
///
/// Like a [HouseChange] it carries the door as it was ([before]), so undo
/// can put that exact dwelling back, and storage writes only the named
/// fields of that door: a [DwellingMarked] on door `51` of the 5e of
/// staircase `A` of house `8` writes `houses.8.dwellings.A5-51.status`,
/// `.by` and `.at`
/// (PLAN §6.2). Two people marking different doors never overwrite each
/// other.
sealed class DwellingChange extends StreetChange {
  const DwellingChange({
    required super.streetId,
    required this.number,
    required this.staircase,
    required this.level,
    required this.before,
    required this.stamp,
  });

  /// The number of the building, its key in storage.
  final HouseNumber number;

  /// The staircase of the door.
  final StaircaseName staircase;

  /// The level of the door's floor; null for the « Logements » row.
  final int? level;

  /// The door before the change, untouched.
  final Dwelling before;

  /// Who made the change and when: the door's new last change.
  final ChangeStamp stamp;

  /// Where the door is in its building; `key.id` (`A5-51`) is its key in
  /// storage.
  DwellingKey get key => DwellingKey(staircase, level, before.label);

  bool _sameDwellingChange(DwellingChange other) =>
      other.streetId == streetId &&
      other.number == number &&
      other.staircase == staircase &&
      other.level == level &&
      other.before == before &&
      other.stamp == stamp;

  /// The street, house and door, as every dwelling change prints them.
  String get _where => '${streetId.value}, ${number.label}, ${key.id}';
}

/// The door at [key] of the building [number] was given a new [status].
final class DwellingMarked extends DwellingChange {
  const DwellingMarked({
    required super.streetId,
    required super.number,
    required super.staircase,
    required super.level,
    required super.before,
    required super.stamp,
    required this.status,
  });

  final VisitStatus status;

  /// The come-back the door has after the change, which storage writes
  /// with the status (see [HouseMarked.comeBack]).
  ComeBack? get comeBack => ComeBack.keptBy(status, before.comeBack);

  @override
  bool operator ==(Object other) =>
      other is DwellingMarked &&
      _sameDwellingChange(other) &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(streetId, number, staircase, level, before, stamp, status);

  @override
  String toString() => 'DwellingMarked($_where, $status, $stamp)';
}

/// The « repasser » hint of the door at [key] was set to [comeBack].
final class DwellingComeBackSet extends DwellingChange {
  const DwellingComeBackSet({
    required super.streetId,
    required super.number,
    required super.staircase,
    required super.level,
    required super.before,
    required super.stamp,
    required this.comeBack,
  });

  final ComeBack? comeBack;

  @override
  bool operator ==(Object other) =>
      other is DwellingComeBackSet &&
      _sameDwellingChange(other) &&
      other.comeBack == comeBack;

  @override
  int get hashCode =>
      Object.hash(streetId, number, staircase, level, before, stamp, comeBack);

  @override
  String toString() => 'DwellingComeBackSet($_where, $comeBack, $stamp)';
}

/// The street went to the Corbeille: hidden, but kept with its houses so
/// any member can restore it (PLAN §5.11). Storage writes `deletedAt` and
/// `deletedBy` from [deletion].
final class StreetDeleted extends StreetChange {
  const StreetDeleted({required super.streetId, required this.deletion});

  final ChangeStamp deletion;

  @override
  bool operator ==(Object other) =>
      other is StreetDeleted &&
      other.streetId == streetId &&
      other.deletion == deletion;

  @override
  int get hashCode => Object.hash(streetId, deletion);

  @override
  String toString() => 'StreetDeleted(${streetId.value}, $deletion)';
}

/// The street came back from the Corbeille. Storage clears `deletedAt` and
/// `deletedBy`.
final class StreetRestored extends StreetChange {
  const StreetRestored({required super.streetId});

  @override
  bool operator ==(Object other) =>
      other is StreetRestored && other.streetId == streetId;

  @override
  int get hashCode => streetId.hashCode;

  @override
  String toString() => 'StreetRestored(${streetId.value})';
}

/// Numbers were added to the street from the « Ajouter des numéros » sheet
/// (PLAN §5.5).
///
/// - [added]: the new houses, to do and unmarked; storage writes one entry
///   per house (`houses.21`…), never the whole map.
/// - [restored]: numbers that were in the Corbeille, as they were there;
///   they come back with their marks, and storage clears their `deletedAt`
///   and `deletedBy`.
/// - [alreadyThere]: numbers the street shows already, left untouched; the
///   screen can say they were skipped.
///
/// Undo drops the [added] houses and sends the [restored] ones back to the
/// Corbeille with their removal.
final class NumbersAdded extends StreetChange {
  NumbersAdded({
    required super.streetId,
    required Iterable<House> added,
    required Iterable<RemovedHouse> restored,
    required Iterable<HouseNumber> alreadyThere,
  }) : added = List.unmodifiable(added),
       restored = List.unmodifiable(restored),
       alreadyThere = List.unmodifiable(alreadyThere);

  /// The new houses, in street order.
  final List<House> added;

  /// The houses brought back from the Corbeille, in street order, each with
  /// the removal it had.
  final List<RemovedHouse> restored;

  /// The numbers given that the street already showed, in street order.
  final List<HouseNumber> alreadyThere;

  @override
  bool operator ==(Object other) =>
      other is NumbersAdded &&
      other.streetId == streetId &&
      sameItems(other.added, added) &&
      sameItems(other.restored, restored) &&
      sameItems(other.alreadyThere, alreadyThere);

  @override
  int get hashCode => Object.hash(
    streetId,
    Object.hashAll(added),
    Object.hashAll(restored),
    Object.hashAll(alreadyThere),
  );

  @override
  String toString() {
    String labels(Iterable<HouseNumber> numbers) =>
        '[${numbers.map((number) => number.label).join(', ')}]';
    return 'NumbersAdded(${streetId.value}, '
        'added: ${labels(added.map((house) => house.number))}, '
        'restored: ${labels(restored.map((house) => house.number))}, '
        'alreadyThere: ${labels(alreadyThere)})';
  }
}

/// A number was removed in edit mode (✕): the house went to the Corbeille
/// with its marks ([removed]), and can be restored (PLAN §5.11).
///
/// Storage writes `houses.14ter.deletedAt` and `deletedBy`; the house's
/// other fields stay as they are. Undo restores it.
final class NumberRemoved extends StreetChange {
  const NumberRemoved({required super.streetId, required this.removed});

  /// The house as it was, and who removed it when.
  final RemovedHouse removed;

  HouseNumber get number => removed.number;

  /// Whether the removed house had marks (see `House.hasMarks`): the
  /// screen asked for confirmation first, and the undo snackbar matters.
  bool get hadMarks => removed.house.hasMarks;

  @override
  bool operator ==(Object other) =>
      other is NumberRemoved &&
      other.streetId == streetId &&
      other.removed == removed;

  @override
  int get hashCode => Object.hash(streetId, removed);

  @override
  String toString() =>
      'NumberRemoved(${streetId.value}, ${number.label}, ${removed.removal})';
}

/// A number came back from the Corbeille with its marks. [removed] is the
/// house as it was there, removal included, so undo can send it back as it
/// was. Storage clears `houses.14ter.deletedAt` and `deletedBy`.
final class NumberRestored extends StreetChange {
  const NumberRestored({required super.streetId, required this.removed});

  final RemovedHouse removed;

  HouseNumber get number => removed.number;

  @override
  bool operator ==(Object other) =>
      other is NumberRestored &&
      other.streetId == streetId &&
      other.removed == removed;

  @override
  int get hashCode => Object.hash(streetId, removed);

  @override
  String toString() => 'NumberRestored(${streetId.value}, ${number.label})';
}

/// The street was renamed from [before] to [name] (the name field of the
/// edit mode, PLAN §5.5), for the whole team. Storage writes `name`; undo
/// writes [before] back.
final class StreetRenamed extends StreetChange {
  const StreetRenamed({
    required super.streetId,
    required this.before,
    required this.name,
  });

  /// The name before the change.
  final StreetName before;

  final StreetName name;

  @override
  bool operator ==(Object other) =>
      other is StreetRenamed &&
      other.streetId == streetId &&
      other.before == before &&
      other.name == name;

  @override
  int get hashCode => Object.hash(streetId, before, name);

  @override
  String toString() =>
      'StreetRenamed(${streetId.value}, ${before.text} → ${name.text})';
}

/// An undo put back [house], the house exactly as it was before the change
/// being undone, in place of [replaced], the house as it was just before
/// the undo (PLAN §7: undo is a normal write of the previous value, with
/// its old status, « repasser », building and last change).
///
/// Storage writes the whole house entry under [number]; when the undo
/// renumbers it back (« 3bis » → « 3 »), it first deletes the entry under
/// the number of [replaced]. Undoing this change puts [replaced] back.
final class HouseReverted extends StreetChange {
  const HouseReverted({
    required super.streetId,
    required this.replaced,
    required this.house,
  });

  /// The house before the undo.
  final House replaced;

  /// The house put back.
  final House house;

  /// The number the house is stored under after the undo.
  HouseNumber get number => house.number;

  /// Whether the undo gives the house its old number back, so storage must
  /// move it from one key to another.
  bool get renumbers => replaced.number != house.number;

  @override
  bool operator ==(Object other) =>
      other is HouseReverted &&
      other.streetId == streetId &&
      other.replaced == replaced &&
      other.house == house;

  @override
  int get hashCode => Object.hash(streetId, replaced, house);

  @override
  String toString() =>
      'HouseReverted(${streetId.value}, '
      '${replaced.number.label} → ${house.number.label})';
}

/// An undo put back [dwelling], one door of the building [number] exactly as
/// it was before the change being undone, in place of [replaced], the door
/// as it was just before the undo.
///
/// Storage writes the whole door entry `houses.8.dwellings.A5-51`; the rest
/// of the building is left alone, so a teammate marking another door at the
/// same moment is not overwritten. Undoing this change puts [replaced] back.
final class DwellingReverted extends StreetChange {
  const DwellingReverted({
    required super.streetId,
    required this.number,
    required this.staircase,
    required this.level,
    required this.replaced,
    required this.dwelling,
  });

  /// The number of the building.
  final HouseNumber number;

  /// The staircase of the door.
  final StaircaseName staircase;

  /// The level of the door's floor; null for the « Logements » row.
  final int? level;

  /// The door before the undo.
  final Dwelling replaced;

  /// The door put back; it has the same label as [replaced].
  final Dwelling dwelling;

  /// Where the door is in its building; `key.id` is its key in storage.
  DwellingKey get key => DwellingKey(staircase, level, dwelling.label);

  @override
  bool operator ==(Object other) =>
      other is DwellingReverted &&
      other.streetId == streetId &&
      other.number == number &&
      other.staircase == staircase &&
      other.level == level &&
      other.replaced == replaced &&
      other.dwelling == dwelling;

  @override
  int get hashCode =>
      Object.hash(streetId, number, staircase, level, replaced, dwelling);

  @override
  String toString() =>
      'DwellingReverted(${streetId.value}, ${number.label}, ${key.id})';
}
