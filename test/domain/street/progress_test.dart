import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

void main() {
  group('empty', () {
    test('should count nothing when nothing is counted', () {
      const progress = Progress.empty;

      expect(progress.done, 0);
      expect(progress.nobodyHome, 0);
      expect(progress.comeBack, 0);
      expect(progress.toDo, 0);
      expect(progress.buildingComeBacks, 0);
      expect(progress.total, 0);
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
      expect(progress.nobodyHome, 0);
      expect(progress.comeBack, 0);
      expect(progress.toDo, 0);
      expect(progress.total, 1);
      expect(progress.toComeBack, 0);
    });

    test('should count one nobody home when nobody answered', () {
      final progress = Progress.of(VisitStatus.nobodyHome);

      expect(progress.done, 0);
      expect(progress.nobodyHome, 1);
      expect(progress.comeBack, 0);
      expect(progress.toDo, 0);
      expect(progress.total, 1);
      expect(progress.toComeBack, 0);
    });

    test('should count one come-back when asked to come back', () {
      final progress = Progress.of(VisitStatus.comeBack);

      expect(progress.done, 0);
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
    expect(sum.nobodyHome, 1);
    expect(sum.comeBack, 3);
    expect(sum.toDo, 4);
    expect(sum.buildingComeBacks, 1);
    expect(sum.total, 10);
    expect(sum.toComeBack, 4);
  });

  test('should leave a progress unchanged when empty is added', () {
    final one = Progress.of(VisitStatus.comeBack) + Progress.buildingComeBack;

    expect(one + Progress.empty, one);
  });

  group('equality', () {
    final base =
        Progress.of(VisitStatus.done) +
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
          Progress.of(VisitStatus.done);

      expect(base, same);
      expect(base.hashCode, same.hashCode);
    });

    final others = <String, Progress>{
      'done': base + Progress.of(VisitStatus.done),
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
        Progress.of(VisitStatus.comeBack) +
        Progress.buildingComeBack;

    expect(
      progress.toString(),
      'Progress(done: 1, nobodyHome: 0, comeBack: 1, toDo: 0, '
      'buildingComeBacks: 1, total: 2)',
    );
  });
}
