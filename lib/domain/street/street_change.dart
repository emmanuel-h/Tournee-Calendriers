import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
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
