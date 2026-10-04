import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// How far a street (or any group of doors) has got: how many doors are
/// [done], [nobodyHome] or still [toDo], and how many carry a « repasser »
/// ([comeBack]). The street header shows it as « 31/42 · ✗3 · ↻1 »
/// (PLAN §5.6).
///
/// Every door has exactly one status, so [total] is the sum of the three
/// status counts. [comeBack] overlaps them: a house can be « personne » and
/// « repasser » at once.
///
/// Progress is always computed from the doors, never stored (PLAN §6.2).
/// A group's progress is the sum (`+`) of its doors' progress, so a building
/// (T1.3) only has to add up its dwellings to fit in.
final class Progress {
  const Progress._({
    required this.done,
    required this.nobodyHome,
    required this.toDo,
    required this.comeBack,
  });

  /// No door at all; the starting point of a sum.
  static const empty = Progress._(done: 0, nobodyHome: 0, toDo: 0, comeBack: 0);

  /// The progress of one door with [status], counted once more in
  /// [Progress.comeBack] when it carries a « repasser ».
  factory Progress.of(VisitStatus status, {required bool comeBack}) =>
      Progress._(
        done: status == VisitStatus.done ? 1 : 0,
        nobodyHome: status == VisitStatus.nobodyHome ? 1 : 0,
        toDo: status == VisitStatus.toDo ? 1 : 0,
        comeBack: comeBack ? 1 : 0,
      );

  final int done;
  final int nobodyHome;
  final int toDo;
  final int comeBack;

  /// Every door counted, whatever its status.
  int get total => done + nobodyHome + toDo;

  /// The progress of both groups together.
  Progress operator +(Progress other) => Progress._(
    done: done + other.done,
    nobodyHome: nobodyHome + other.nobodyHome,
    toDo: toDo + other.toDo,
    comeBack: comeBack + other.comeBack,
  );

  @override
  bool operator ==(Object other) =>
      other is Progress &&
      other.done == done &&
      other.nobodyHome == nobodyHome &&
      other.toDo == toDo &&
      other.comeBack == comeBack;

  @override
  int get hashCode => Object.hash(done, nobodyHome, toDo, comeBack);

  @override
  String toString() =>
      'Progress(done: $done, nobodyHome: $nobodyHome, toDo: $toDo, '
      'comeBack: $comeBack, total: $total)';
}
