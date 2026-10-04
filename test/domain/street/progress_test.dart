import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

void main() {
  group('empty', () {
    test('should count nothing when nothing is counted', () {
      const progress = Progress.empty;

      expect(progress.done, 0);
      expect(progress.nobodyHome, 0);
      expect(progress.toDo, 0);
      expect(progress.comeBack, 0);
      expect(progress.total, 0);
    });
  });

  group('of one door', () {
    test('should count one done when the door is done', () {
      final progress = Progress.of(VisitStatus.done, comeBack: false);

      expect(progress.done, 1);
      expect(progress.nobodyHome, 0);
      expect(progress.toDo, 0);
      expect(progress.comeBack, 0);
      expect(progress.total, 1);
    });

    test('should count one nobody home when nobody answered', () {
      final progress = Progress.of(VisitStatus.nobodyHome, comeBack: false);

      expect(progress.done, 0);
      expect(progress.nobodyHome, 1);
      expect(progress.toDo, 0);
      expect(progress.comeBack, 0);
      expect(progress.total, 1);
    });

    test('should count one to do when the door is not visited yet', () {
      final progress = Progress.of(VisitStatus.toDo, comeBack: false);

      expect(progress.done, 0);
      expect(progress.nobodyHome, 0);
      expect(progress.toDo, 1);
      expect(progress.comeBack, 0);
      expect(progress.total, 1);
    });

    test('should count a come-back on top of the status when asked to', () {
      final progress = Progress.of(VisitStatus.nobodyHome, comeBack: true);

      expect(progress.nobodyHome, 1);
      expect(progress.comeBack, 1);
      expect(progress.total, 1);
    });
  });

  test('should add each count when two progresses are added', () {
    final sum =
        Progress.of(VisitStatus.done, comeBack: false) +
        Progress.of(VisitStatus.done, comeBack: false) +
        Progress.of(VisitStatus.nobodyHome, comeBack: true) +
        Progress.of(VisitStatus.toDo, comeBack: true) +
        Progress.of(VisitStatus.toDo, comeBack: false) +
        Progress.of(VisitStatus.toDo, comeBack: false);

    expect(sum.done, 2);
    expect(sum.nobodyHome, 1);
    expect(sum.toDo, 3);
    expect(sum.comeBack, 2);
    expect(sum.total, 6);
  });

  test('should leave a progress unchanged when empty is added', () {
    final one = Progress.of(VisitStatus.nobodyHome, comeBack: true);

    expect(one + Progress.empty, one);
  });

  group('equality', () {
    final base =
        Progress.of(VisitStatus.done, comeBack: false) +
        Progress.of(VisitStatus.nobodyHome, comeBack: false) +
        Progress.of(VisitStatus.toDo, comeBack: true);

    test('should be equal when every count is equal', () {
      final same =
          Progress.of(VisitStatus.toDo, comeBack: true) +
          Progress.of(VisitStatus.nobodyHome, comeBack: false) +
          Progress.of(VisitStatus.done, comeBack: false);

      expect(base, same);
      expect(base.hashCode, same.hashCode);
    });

    final others = <String, Progress>{
      'done': base + Progress.of(VisitStatus.done, comeBack: false),
      'nobody home':
          base + Progress.of(VisitStatus.nobodyHome, comeBack: false),
      'to do': base + Progress.of(VisitStatus.toDo, comeBack: false),
      'come back':
          Progress.of(VisitStatus.done, comeBack: false) +
          Progress.of(VisitStatus.nobodyHome, comeBack: false) +
          Progress.of(VisitStatus.toDo, comeBack: false),
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
        Progress.of(VisitStatus.done, comeBack: false) +
        Progress.of(VisitStatus.nobodyHome, comeBack: true);

    expect(
      progress.toString(),
      'Progress(done: 1, nobodyHome: 1, toDo: 0, comeBack: 1, total: 2)',
    );
  });
}
