import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// How far a street (or any group of doors) has got: how many doors are
/// [done], [nobodyHome], [comeBack] (« repasser ») or still [toDo]. The
/// street header shows it as « 31/42 · ✗ 3 · ↻ 1 » (PLAN §5.6).
///
/// Every door has exactly one status, so [total] is the sum of the four
/// door counts. A building's own « repasser » (« Repasser » under its grid)
/// is not a door: it is counted apart, in [buildingComeBacks], and joins
/// the doors in the header's ↻ ([toComeBack]).
///
/// Progress is always computed from the doors, never stored (PLAN §6.2).
/// A group's progress is the sum (`+`) of its doors' progress: a building
/// adds up its dwellings, a street its houses.
final class Progress {
  const Progress._({
    required this.done,
    required this.nobodyHome,
    required this.comeBack,
    required this.toDo,
    required this.buildingComeBacks,
  });

  /// No door at all; the starting point of a sum.
  static const empty = Progress._(
    done: 0,
    nobodyHome: 0,
    comeBack: 0,
    toDo: 0,
    buildingComeBacks: 0,
  );

  /// A building's own « repasser » (PLAN §5.7): one more place to come back
  /// to in the street's ↻, but no door added to [total].
  static const buildingComeBack = Progress._(
    done: 0,
    nobodyHome: 0,
    comeBack: 0,
    toDo: 0,
    buildingComeBacks: 1,
  );

  /// The progress of one door with [status].
  factory Progress.of(VisitStatus status) => Progress._(
    done: status == VisitStatus.done ? 1 : 0,
    nobodyHome: status == VisitStatus.nobodyHome ? 1 : 0,
    comeBack: status == VisitStatus.comeBack ? 1 : 0,
    toDo: status == VisitStatus.toDo ? 1 : 0,
    buildingComeBacks: 0,
  );

  final int done;
  final int nobodyHome;

  /// The doors « repasser ».
  final int comeBack;
  final int toDo;

  /// The buildings with their own « repasser »; not doors.
  final int buildingComeBacks;

  /// Every door counted, whatever its status.
  int get total => done + nobodyHome + comeBack + toDo;

  /// The header's ↻: every place to come back to, doors « repasser » and
  /// buildings with their own « repasser ».
  int get toComeBack => comeBack + buildingComeBacks;

  /// The progress of both groups together.
  Progress operator +(Progress other) => Progress._(
    done: done + other.done,
    nobodyHome: nobodyHome + other.nobodyHome,
    comeBack: comeBack + other.comeBack,
    toDo: toDo + other.toDo,
    buildingComeBacks: buildingComeBacks + other.buildingComeBacks,
  );

  @override
  bool operator ==(Object other) =>
      other is Progress &&
      other.done == done &&
      other.nobodyHome == nobodyHome &&
      other.comeBack == comeBack &&
      other.toDo == toDo &&
      other.buildingComeBacks == buildingComeBacks;

  @override
  int get hashCode =>
      Object.hash(done, nobodyHome, comeBack, toDo, buildingComeBacks);

  @override
  String toString() =>
      'Progress(done: $done, nobodyHome: $nobodyHome, comeBack: $comeBack, '
      'toDo: $toDo, buildingComeBacks: $buildingComeBacks, total: $total)';
}
