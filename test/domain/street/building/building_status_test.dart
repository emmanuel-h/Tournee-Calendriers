import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building_status.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// The progress of doors with these [statuses].
Progress _doors(List<VisitStatus> statuses) =>
    statuses.fold(Progress.empty, (sum, status) => sum + Progress.of(status));

const _done = VisitStatus.done;
const _toDo = VisitStatus.toDo;
const _nobody = VisitStatus.nobodyHome;
const _comeBack = VisitStatus.comeBack;

void main() {
  final cases = <String, (List<VisitStatus>, BuildingStatus)>{
    'every door is done': ([_done, _done, _done], BuildingStatus.done),
    'its only door is done': ([_done], BuildingStatus.done),
    'all doors but one are done': (
      [_done, _done, _toDo],
      BuildingStatus.partial,
    ),
    'one door is done': ([_done, _toDo, _toDo], BuildingStatus.partial),
    'one is done and the others nobody home': (
      [_nobody, _done, _nobody],
      BuildingStatus.partial,
    ),
    'no door is done': ([_toDo, _toDo, _toDo], BuildingStatus.toDo),
    'nobody was home anywhere': ([_nobody, _nobody], BuildingStatus.toDo),
    'every door is to come back to': (
      [_comeBack, _comeBack],
      BuildingStatus.toDo,
    ),
    'one is done and the others to come back to': (
      [_comeBack, _done, _comeBack],
      BuildingStatus.partial,
    ),
    'it has no door': (<VisitStatus>[], BuildingStatus.toDo),
  };
  cases.forEach((when, expected) {
    test('should be ${expected.$2.name} when $when', () {
      expect(BuildingStatus.of(_doors(expected.$1)), expected.$2);
    });
  });
}
