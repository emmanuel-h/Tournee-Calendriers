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
const _refused = VisitStatus.refused;

void main() {
  // Each row: what it shows, the doors, the level on the map.
  final table = <(String, Progress, ProgressLevel)>[
    ('no door', Progress.empty, ProgressLevel.toDo),
    ('every door to do', _doors([_toDo, _toDo, _toDo]), ProgressLevel.toDo),
    (
      'one door visited, nobody home',
      _doors([_toDo, _toDo, _nobody]),
      ProgressLevel.partial,
    ),
    (
      'one door to come back to',
      _doors([_comeBack, _toDo]),
      ProgressLevel.partial,
    ),
    (
      'one door done of three',
      _doors([_done, _toDo, _toDo]),
      ProgressLevel.partial,
    ),
    (
      'every door visited, one nobody home',
      _doors([_done, _done, _nobody]),
      ProgressLevel.partial,
    ),
    (
      'every door visited, one to come back to',
      _doors([_done, _comeBack]),
      ProgressLevel.partial,
    ),
    ('every door done', _doors([_done, _done, _done]), ProgressLevel.done),
    ('a single door done', _doors([_done]), ProgressLevel.done),
    (
      'every door done or refused',
      _doors([_done, _refused, _done]),
      ProgressLevel.done,
    ),
    ('every door refused', _doors([_refused]), ProgressLevel.done),
    (
      'one door refused, the others to do',
      _doors([_refused, _toDo]),
      ProgressLevel.partial,
    ),
    (
      'refused, but one door nobody home',
      _doors([_refused, _nobody]),
      ProgressLevel.partial,
    ),
    (
      'refused, but a building to come back to',
      _doors([_refused]) + Progress.buildingComeBack,
      ProgressLevel.partial,
    ),
    (
      'every door done but a building to come back to',
      _doors([_done, _done]) + Progress.buildingComeBack,
      ProgressLevel.partial,
    ),
  ];
  for (final (what, progress, level) in table) {
    test('should be ${level.name} when $what', () {
      expect(ProgressLevel.of(progress), level);
    });
  }
}
