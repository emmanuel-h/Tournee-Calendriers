import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// The progress of doors with these [statuses], one door each.
Progress _doors(List<VisitStatus> statuses) =>
    statuses.fold(Progress.empty, (sum, status) => sum + Progress.of(status));

const _toDo = VisitStatus.toDo;
const _done = VisitStatus.done;
const _nobody = VisitStatus.nobodyHome;
const _comeBack = VisitStatus.comeBack;

void main() {
  // Each row: what it shows, the doors, whether someone took the street,
  // the level on the map.
  final table = <(String, Progress, bool, ProgressLevel)>[
    ('no door, taken', Progress.empty, true, ProgressLevel.toDo),
    ('no door, nobody on it', Progress.empty, false, ProgressLevel.free),
    (
      'every door to do',
      _doors([_toDo, _toDo, _toDo]),
      true,
      ProgressLevel.toDo,
    ),
    (
      'one door visited, nobody home',
      _doors([_toDo, _toDo, _nobody]),
      true,
      ProgressLevel.partial,
    ),
    (
      'one door to come back to',
      _doors([_comeBack, _toDo]),
      true,
      ProgressLevel.partial,
    ),
    (
      'one door done of three',
      _doors([_done, _toDo, _toDo]),
      true,
      ProgressLevel.partial,
    ),
    (
      'every door visited, one nobody home',
      _doors([_done, _done, _nobody]),
      true,
      ProgressLevel.partial,
    ),
    (
      'every door visited, one to come back to',
      _doors([_done, _comeBack]),
      true,
      ProgressLevel.partial,
    ),
    (
      'every door done',
      _doors([_done, _done, _done]),
      true,
      ProgressLevel.done,
    ),
    ('a single door done', _doors([_done]), true, ProgressLevel.done),
    (
      'every door done but a building to come back to',
      _doors([_done, _done]) + Progress.buildingComeBack,
      true,
      ProgressLevel.partial,
    ),
    (
      'every door done, nobody on it any more',
      _doors([_done, _done]),
      false,
      ProgressLevel.done,
    ),
    (
      'started, nobody on it any more',
      _doors([_done, _toDo]),
      false,
      ProgressLevel.free,
    ),
    (
      'not started, nobody on it',
      _doors([_toDo, _toDo]),
      false,
      ProgressLevel.free,
    ),
  ];
  for (final (what, progress, taken, level) in table) {
    test('should be ${level.name} when $what', () {
      expect(ProgressLevel.of(progress, taken: taken), level);
    });
  }
}
