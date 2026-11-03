import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

void main() {
  group('empty', () {
    test('should count nothing when nothing is counted', () {
      const progress = Progress.empty;

      expect(progress.done, 0);
      expect(progress.refused, 0);
      expect(progress.nobodyHome, 0);
      expect(progress.comeBack, 0);
      expect(progress.toDo, 0);
      expect(progress.buildingComeBacks, 0);
      expect(progress.total, 0);
      expect(progress.visited, 0);
      expect(progress.toComeBack, 0);
    });
  });

  group('buildingComeBack', () {
    test('should count one place to come back to and no door', () {
      const progress = Progress.buildingComeBack;

      expect(progress.buildingComeBacks, 1);
      expect(progress.toComeBack, 1);
      expect(progress.comeBack, 0);
      expect(progress.done, 0);
      expect(progress.nobodyHome, 0);
      expect(progress.toDo, 0);
      expect(progress.total, 0);
    });
  });

  group('of one door', () {
    test('should count one done when the door is done', () {
      final progress = Progress.of(VisitStatus.done);

      expect(progress.done, 1);
      expect(progress.refused, 0);
      expect(progress.nobodyHome, 0);
      expect(progress.comeBack, 0);
      expect(progress.toDo, 0);
      expect(progress.total, 1);
      expect(progress.visited, 1);
      expect(progress.toComeBack, 0);
    });

    test(
      'should count one refused, visited, when the calendar was refused',
      () {
        final progress = Progress.of(VisitStatus.refused);

        expect(progress.done, 0);
        expect(progress.refused, 1);
        expect(progress.nobodyHome, 0);
        expect(progress.comeBack, 0);
        expect(progress.toDo, 0);
        expect(progress.total, 1);
        expect(progress.visited, 1);
        expect(progress.toComeBack, 0);
      },
    );

    test('should count one nobody home when nobody answered', () {
      final progress = Progress.of(VisitStatus.nobodyHome);

      expect(progress.done, 0);
      expect(progress.refused, 0);
      expect(progress.visited, 0);
      expect(progress.nobodyHome, 1);
      expect(progress.comeBack, 0);
      expect(progress.toDo, 0);
      expect(progress.total, 1);
      expect(progress.toComeBack, 0);
    });

    test('should count one come-back when asked to come back', () {
      final progress = Progress.of(VisitStatus.comeBack);

      expect(progress.done, 0);
      expect(progress.refused, 0);
      expect(progress.visited, 0);
      expect(progress.nobodyHome, 0);
      expect(progress.comeBack, 1);
      expect(progress.toDo, 0);
      expect(progress.buildingComeBacks, 0);
      expect(progress.total, 1);
      expect(progress.toComeBack, 1);
    });

    test('should count one to do when the door is not visited yet', () {
      final progress = Progress.of(VisitStatus.toDo);

      expect(progress.done, 0);
      expect(progress.refused, 0);
      expect(progress.visited, 0);
      expect(progress.nobodyHome, 0);
      expect(progress.comeBack, 0);
      expect(progress.toDo, 1);
      expect(progress.total, 1);
      expect(progress.toComeBack, 0);
    });
  });

  test('should add each count when two progresses are added', () {
    final sum =
        Progress.of(VisitStatus.done) +
        Progress.of(VisitStatus.done) +
        Progress.of(VisitStatus.refused) +
        Progress.of(VisitStatus.refused) +
        Progress.of(VisitStatus.refused) +
        Progress.of(VisitStatus.refused) +
        Progress.of(VisitStatus.refused) +
        Progress.of(VisitStatus.nobodyHome) +
        Progress.of(VisitStatus.comeBack) +
        Progress.of(VisitStatus.comeBack) +
        Progress.of(VisitStatus.comeBack) +
        Progress.of(VisitStatus.toDo) +
        Progress.of(VisitStatus.toDo) +
        Progress.of(VisitStatus.toDo) +
        Progress.of(VisitStatus.toDo) +
        Progress.buildingComeBack;

    expect(sum.done, 2);
    expect(sum.refused, 5);
    expect(sum.visited, 7);
    expect(sum.nobodyHome, 1);
    expect(sum.comeBack, 3);
    expect(sum.toDo, 4);
    expect(sum.buildingComeBacks, 1);
    expect(sum.total, 15);
    expect(sum.toComeBack, 4);
  });

  test('should leave a progress unchanged when empty is added', () {
    final one = Progress.of(VisitStatus.comeBack) + Progress.buildingComeBack;

    expect(one + Progress.empty, one);
  });

  group('equality', () {
    final base =
        Progress.of(VisitStatus.done) +
        Progress.of(VisitStatus.refused) +
        Progress.of(VisitStatus.nobodyHome) +
        Progress.of(VisitStatus.comeBack) +
        Progress.of(VisitStatus.toDo) +
        Progress.buildingComeBack;

    test('should be equal when every count is equal', () {
      final same =
          Progress.buildingComeBack +
          Progress.of(VisitStatus.toDo) +
          Progress.of(VisitStatus.comeBack) +
          Progress.of(VisitStatus.nobodyHome) +
          Progress.of(VisitStatus.refused) +
          Progress.of(VisitStatus.done);

      expect(base, same);
      expect(base.hashCode, same.hashCode);
    });

    final others = <String, Progress>{
      'done': base + Progress.of(VisitStatus.done),
      'refused': base + Progress.of(VisitStatus.refused),
      'nobody home': base + Progress.of(VisitStatus.nobodyHome),
      'come back': base + Progress.of(VisitStatus.comeBack),
      'to do': base + Progress.of(VisitStatus.toDo),
      'building come-back': base + Progress.buildingComeBack,
    };
    others.forEach((count, other) {
      test('should differ when the $count counts differ', () {
        expect(base, isNot(other));
      });
    });

    test('should differ from a value of another type', () {
      expect(Progress.empty, isNot(0));
    });
  });

  test('should show each count when printed', () {
    final progress =
        Progress.of(VisitStatus.done) +
        Progress.of(VisitStatus.refused) +
        Progress.of(VisitStatus.refused) +
        Progress.of(VisitStatus.comeBack) +
        Progress.buildingComeBack;

    expect(
      progress.toString(),
      'Progress(done: 1, refused: 2, nobodyHome: 0, comeBack: 1, toDo: 0, '
      'buildingComeBacks: 1, total: 4)',
    );
  });

  group('visitedPercent', () {
    Progress doors({required int done, required int toDo}) => [
      for (var i = 0; i < done; i++) Progress.of(VisitStatus.done),
      for (var i = 0; i < toDo; i++) Progress.of(VisitStatus.toDo),
    ].fold(Progress.empty, (sum, door) => sum + door);

    test('should be 0 when there is no door', () {
      expect(Progress.empty.visitedPercent, 0);
    });

    test('should round down, so 100 % means every door done', () {
      // 199 of 200: 99.5 %, which rounding would make 100.
      expect(doors(done: 199, toDo: 1).visitedPercent, 99);
    });

    test('should be 100 when every door is visited', () {
      expect(doors(done: 3, toDo: 0).visitedPercent, 100);
    });

    test('should leave out doors nobody home or to come back to', () {
      final progress =
          doors(done: 2, toDo: 1) +
          Progress.of(VisitStatus.nobodyHome) +
          Progress.of(VisitStatus.comeBack) +
          Progress.buildingComeBack;

      // 2 of 5 doors.
      expect(progress.visitedPercent, 40);
    });

    test('should count refused doors with the done ones', () {
      final progress =
          doors(done: 1, toDo: 2) +
          Progress.of(VisitStatus.refused) +
          Progress.of(VisitStatus.refused);

      // 3 of 5 doors.
      expect(progress.visitedPercent, 60);
    });

    test('should be 41 for 41 doors done of 100', () {
      expect(doors(done: 41, toDo: 59).visitedPercent, 41);
    });
  });
}
