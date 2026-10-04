import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// One address of a street (`12`, `12bis`): an entity inside the `Street`
/// aggregate, identified in its street by its [number].
///
/// A `House` is immutable: the street changes a house by replacing it with
/// a new one (`Street.markHouse`…), so only the street root decides what
/// changes. Two houses are equal when every field is equal; that lets a
/// change keep the house as it was before (for undo) and tests compare
/// whole houses.
final class House {
  const House._(
    this.number,
    this.status,
    this.comeBack,
    this.note,
    this.lastChange,
  );

  /// A house with [number]; by default not visited yet, with no
  /// « repasser », no note and no change recorded.
  ///
  /// A house that is [VisitStatus.done] has no reason to be visited again,
  /// so its [comeBack] is always dropped: whatever builds it (a command of
  /// the street, an adapter reading stored data) never ends with a stale
  /// « repasser » on a done house. A `factory` constructor can run this rule
  /// before choosing the field values, which a plain constructor cannot.
  factory House({
    required HouseNumber number,
    VisitStatus status = VisitStatus.toDo,
    ComeBack? comeBack,
    Note note = Note.empty,
    ChangeStamp? lastChange,
  }) => House._(
    number,
    status,
    status == VisitStatus.done ? null : comeBack,
    note,
    lastChange,
  );

  final HouseNumber number;
  final VisitStatus status;

  /// The « repasser » flag and its hint; null when nobody asked to come
  /// back, and always null on a done house.
  final ComeBack? comeBack;

  /// The free note; [Note.empty] when nobody wrote one.
  final Note note;

  /// Who changed the house last and when; null when nobody has yet.
  final ChangeStamp? lastChange;

  /// What this house adds to its street's progress: one door. A building
  /// (T1.3) will count its dwellings instead.
  Progress get progress => Progress.of(status, comeBack: comeBack != null);

  @override
  bool operator ==(Object other) =>
      other is House &&
      other.number == number &&
      other.status == status &&
      other.comeBack == comeBack &&
      other.note == note &&
      other.lastChange == lastChange;

  @override
  int get hashCode => Object.hash(number, status, comeBack, note, lastChange);

  @override
  String toString() =>
      'House(${number.label}, $status, $comeBack, $note, $lastChange)';
}
