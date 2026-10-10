import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// One address of a street (`12`, `12bis`): an entity inside the `Street`
/// aggregate, identified in its street by its [number].
///
/// A house is either a single house, marked as a whole, or a [building]
/// whose dwellings are marked one by one (PLAN §5.7).
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
    this.lastChange,
    this.building,
    this.position,
  );

  /// A house with [number]; by default a single house not visited yet, with
  /// no change recorded.
  ///
  /// Two rules run here, so that whatever builds a house (a command of the
  /// street, an adapter reading stored data) never breaks them. A `factory`
  /// constructor can run them before choosing the field values, which a
  /// plain constructor cannot:
  /// - a house that is a [building] is always [VisitStatus.toDo] itself:
  ///   its doors carry the statuses, and its own status is derived from them
  ///   (see `Building.status`); it keeps the [comeBack] it is given, its own;
  /// - a single house has a [comeBack] exactly when it is
  ///   [VisitStatus.comeBack] (see [ComeBack.keptBy]): « repasser » without
  ///   hint when none is given, and none at all with another status.
  factory House({
    required HouseNumber number,
    VisitStatus status = VisitStatus.toDo,
    ComeBack? comeBack,
    ChangeStamp? lastChange,
    Building? building,
    GeoPoint? position,
  }) {
    final isSingle = building == null;
    return House._(
      number,
      isSingle ? status : VisitStatus.toDo,
      isSingle ? ComeBack.keptBy(status, comeBack) : comeBack,
      lastChange,
      building,
      position,
    );
  }

  final HouseNumber number;

  /// The status of a single house; always [VisitStatus.toDo] on a building,
  /// whose status is `building.status`.
  final VisitStatus status;

  /// What goes with the « repasser » status (its hint); null with any other
  /// status. A building, always to do itself, keeps its own here
  /// (« Repasser » under the grid) apart from its doors'.
  final ComeBack? comeBack;

  /// Who changed the house last and when; null when nobody has yet. On a
  /// building, the last change of its layout or « repasser »: each
  /// door keeps its own.
  final ChangeStamp? lastChange;

  /// The dwellings of the house when it is a building; null for a single
  /// house.
  final Building? building;

  /// Where its entrance is (its dot on the map), as the BAN gives it; null
  /// for a number typed in by hand or one the BAN gives no position. Every
  /// command keeps it: a mark or a new number does not move the door.
  final GeoPoint? position;

  /// Whether the house is a building.
  bool get isBuilding => building != null;

  /// Whether someone marked the house: a status other than to do, a
  /// « repasser », or a mark on a door of its building. Its
  /// [lastChange] alone is not a mark, nor is a building's layout.
  ///
  /// The edit mode asks before removing a number that has marks
  /// (PLAN §5.5); the house still goes to the Corbeille with them.
  bool get hasMarks =>
      status != VisitStatus.toDo ||
      comeBack != null ||
      (building?.hasMarks ?? false);

  /// What this house adds to its street's progress: one door for a single
  /// house; the doors of a building, plus the building's own « repasser »
  /// when it has one (counted in the street's ↻, not as a door).
  Progress get progress => switch (building) {
    null => Progress.of(status),
    // A typed pattern: matches a non-null building and names it, so the
    // line below uses it without `!`.
    final Building building =>
      building.progress +
          (comeBack == null ? Progress.empty : Progress.buildingComeBack),
  };

  /// This house with its last change, and each door's, made by [member],
  /// at the same time (see `Street.restampedBy`).
  House restampedBy(MemberId member) => House._(
    number,
    status,
    comeBack,
    lastChange?.restampedBy(member),
    building?.restampedBy(member),
    position,
  );

  @override
  bool operator ==(Object other) =>
      other is House &&
      other.number == number &&
      other.status == status &&
      other.comeBack == comeBack &&
      other.lastChange == lastChange &&
      other.building == building &&
      other.position == position;

  @override
  int get hashCode =>
      Object.hash(number, status, comeBack, lastChange, building, position);

  /// A single house prints as before buildings existed; a building adds
  /// itself at the end. The position is left out: it never changes after
  /// the import, and the line stays readable in a failing test.
  @override
  String toString() {
    final fields = '${number.label}, $status, $comeBack, $lastChange';
    return building == null ? 'House($fields)' : 'House($fields, $building)';
  }
}
