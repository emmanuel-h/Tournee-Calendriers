import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// One door of a building (« Logement », PLAN §2): an entity of the `Street`
/// aggregate, identified on its floor by its [label].
///
/// A dwelling carries the same marks as a single house (status, the hint of
/// its « repasser », last change) and follows the same rule: it has a
/// [comeBack] exactly when it is « repasser ». It is immutable; the street
/// replaces it to change it.
final class Dwelling {
  const Dwelling._(this.label, this.status, this.comeBack, this.lastChange);

  /// A dwelling labelled [label]; by default not visited yet, with no
  /// change recorded. Its [comeBack] follows its status
  /// ([ComeBack.keptBy]; see `House` for why a factory does it).
  factory Dwelling({
    required DwellingLabel label,
    VisitStatus status = VisitStatus.toDo,
    ComeBack? comeBack,
    ChangeStamp? lastChange,
  }) =>
      Dwelling._(label, status, ComeBack.keptBy(status, comeBack), lastChange);

  final DwellingLabel label;
  final VisitStatus status;

  /// The hint of its « repasser »; null unless it is « repasser ».
  final ComeBack? comeBack;

  /// Who changed the dwelling last and when; null when nobody has yet.
  final ChangeStamp? lastChange;

  /// Whether someone marked the door: a status other than to do
  /// (« repasser » included). Its [lastChange] alone is not a mark.
  bool get hasMarks => status != VisitStatus.toDo;

  /// What this dwelling adds to its building's progress: one door.
  Progress get progress => Progress.of(status);

  @override
  bool operator ==(Object other) =>
      other is Dwelling &&
      other.label == label &&
      other.status == status &&
      other.comeBack == comeBack &&
      other.lastChange == lastChange;

  @override
  int get hashCode => Object.hash(label, status, comeBack, lastChange);

  @override
  String toString() =>
      'Dwelling(${label.text}, $status, $comeBack, $lastChange)';
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
