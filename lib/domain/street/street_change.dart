import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
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

  /// Whether the change also removed the house's « repasser »: a done house
  /// never keeps one (see `House`). Storage must then write the come-back as
  /// absent too; otherwise it must leave the come-back field alone, because
  /// a teammate may be changing it at the same moment.
  bool get clearsComeBack => status == VisitStatus.done;

  @override
  bool operator ==(Object other) =>
      other is HouseMarked && _sameHouseChange(other) && other.status == status;

  @override
  int get hashCode => Object.hash(streetId, before, stamp, status);

  @override
  String toString() =>
      'HouseMarked(${streetId.value}, ${number.label}, $status, $stamp)';
}

/// The « repasser » of the house at [number] was set to [comeBack], or
/// removed when [comeBack] is null.
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

/// The note of the house at [number] was replaced by [note] ([Note.empty]
/// when it was erased).
final class NoteSet extends HouseChange {
  const NoteSet({
    required super.streetId,
    required super.before,
    required super.stamp,
    required this.note,
  });

  final Note note;

  @override
  bool operator ==(Object other) =>
      other is NoteSet && _sameHouseChange(other) && other.note == note;

  @override
  int get hashCode => Object.hash(streetId, before, stamp, note);

  @override
  String toString() =>
      'NoteSet(${streetId.value}, ${number.label}, $note, $stamp)';
}

/// The house at [number] got the layout [building]: it was described as a
/// building, described again, or one of its doors was added, removed or
/// renamed (PLAN §5.7). The house is to do itself and keeps its note and
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
/// done when every door was done, to do otherwise. Its doors are dropped;
/// undo puts [before] back with them.
///
/// Storage removes the dwellings and writes the house's `status`, `by` and
/// `at` (and the come-back as absent when [clearsComeBack]).
final class BuildingRemoved extends HouseChange {
  const BuildingRemoved({
    required super.streetId,
    required super.before,
    required super.stamp,
    required this.status,
  });

  final VisitStatus status;

  /// Whether the building's « repasser » went away: a done house never
  /// keeps one (see `House`).
  bool get clearsComeBack => status == VisitStatus.done;

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

  /// Whether the change also removed the door's « repasser »: a done door
  /// never keeps one (see `Dwelling`), so storage then writes it as absent.
  bool get clearsComeBack => status == VisitStatus.done;

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

/// The « repasser » of the door at [key] was set to [comeBack], or removed
/// when [comeBack] is null.
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

/// The note of the door at [key] was replaced by [note] ([Note.empty] when
/// it was erased).
final class DwellingNoteSet extends DwellingChange {
  const DwellingNoteSet({
    required super.streetId,
    required super.number,
    required super.staircase,
    required super.level,
    required super.before,
    required super.stamp,
    required this.note,
  });

  final Note note;

  @override
  bool operator ==(Object other) =>
      other is DwellingNoteSet &&
      _sameDwellingChange(other) &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(streetId, number, staircase, level, before, stamp, note);

  @override
  String toString() => 'DwellingNoteSet($_where, $note, $stamp)';
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
