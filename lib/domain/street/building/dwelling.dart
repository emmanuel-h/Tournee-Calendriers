import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// One door of a building (« Logement », PLAN §2): an entity of the `Street`
/// aggregate, identified on its floor by its [label].
///
/// A dwelling carries the same marks as a single house (status, « repasser »,
/// note, last change) and follows the same rule: a done dwelling never keeps
/// a « repasser ». It is immutable; the street replaces it to change it.
final class Dwelling {
  const Dwelling._(
    this.label,
    this.status,
    this.comeBack,
    this.note,
    this.lastChange,
  );

  /// A dwelling labelled [label]; by default not visited yet, with no
  /// « repasser », no note and no change recorded. The [comeBack] of a done
  /// dwelling is dropped (see `House` for why a factory does it).
  factory Dwelling({
    required DwellingLabel label,
    VisitStatus status = VisitStatus.toDo,
    ComeBack? comeBack,
    Note note = Note.empty,
    ChangeStamp? lastChange,
  }) => Dwelling._(
    label,
    status,
    status == VisitStatus.done ? null : comeBack,
    note,
    lastChange,
  );

  final DwellingLabel label;
  final VisitStatus status;

  /// The « repasser » flag and its hint; always null on a done dwelling.
  final ComeBack? comeBack;

  /// The free note (« digicode »…); [Note.empty] when nobody wrote one.
  final Note note;

  /// Who changed the dwelling last and when; null when nobody has yet.
  final ChangeStamp? lastChange;

  /// Whether someone marked the door: a status other than to do, a
  /// « repasser » or a note. Its [lastChange] alone is not a mark.
  bool get hasMarks =>
      status != VisitStatus.toDo || comeBack != null || note != Note.empty;

  /// What this dwelling adds to its building's progress: one door.
  Progress get progress => Progress.of(status, comeBack: comeBack != null);

  @override
  bool operator ==(Object other) =>
      other is Dwelling &&
      other.label == label &&
      other.status == status &&
      other.comeBack == comeBack &&
      other.note == note &&
      other.lastChange == lastChange;

  @override
  int get hashCode => Object.hash(label, status, comeBack, note, lastChange);

  @override
  String toString() =>
      'Dwelling(${label.text}, $status, $comeBack, $note, $lastChange)';
}

/// Where a dwelling is in its building: its [staircase], the [level] of its
/// floor (null for the « Logements » row of unknown floors) and its [label].
/// Labels are unique within a floor, so « Gauche » can be on every floor.
/// Commands on a dwelling name it with a key.
final class DwellingKey {
  const DwellingKey(this.staircase, this.level, this.label);

  final StaircaseName staircase;
  final int? level;
  final DwellingLabel label;

  /// The dwelling's key in storage, `houses.8.dwellings.A5-51` (PLAN §6.2):
  /// the staircase letter, the floor level, a dash, the label (`A5-51`,
  /// `A0-Gauche`); `A-Gauche` when the floors are unknown. Unambiguous: the
  /// letter is one character, the level only digits, and the first dash
  /// ends it (a label may hold dashes of its own).
  String get id => '${staircase.letter}${level ?? ''}-${label.text}';

  @override
  bool operator ==(Object other) =>
      other is DwellingKey &&
      other.staircase == staircase &&
      other.level == level &&
      other.label == label;

  @override
  int get hashCode => Object.hash(staircase, level, label);

  @override
  String toString() => 'DwellingKey($id)';
}
