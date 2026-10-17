import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/nobody_home_tries.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';

NobodyHomeTries _tries(int count) => valueOf(NobodyHomeTries.create(count));

void main() {
  group('create', () {
    test('should hold the count when it is between 0 and the limit', () {
      expect(_tries(3).count, 3);
    });

    test('should be no try when the count is 0', () {
      expect(_tries(0), NobodyHomeTries.none);
      expect(NobodyHomeTries.none.count, 0);
    });

    test('should refuse the count when it is negative', () {
      expect(
        failureOf(NobodyHomeTries.create(-1)),
        NobodyHomeTriesFailure.outOfRange,
      );
    });

    test('should accept the count when it is the limit', () {
      expect(_tries(NobodyHomeTries.max).count, 99);
    });

    test('should refuse the count when it is one past the limit', () {
      expect(
        failureOf(NobodyHomeTries.create(100)),
        NobodyHomeTriesFailure.outOfRange,
      );
    });
  });

  group('next', () {
    test('should add one try when below the limit', () {
      expect(_tries(2).next, _tries(3));
    });

    test('should be the first try when there was none', () {
      expect(NobodyHomeTries.none.next.count, 1);
    });

    test('should add the last try when one below the limit', () {
      expect(_tries(98).next.count, 99);
    });

    test('should stay at the limit when it is reached', () {
      expect(_tries(99).next.count, 99);
    });
  });

  group('keptBy', () {
    test('should reset the tries when the status is to do', () {
      expect(
        NobodyHomeTries.keptBy(VisitStatus.toDo, _tries(3)),
        NobodyHomeTries.none,
      );
    });

    test('should keep the tries when the status is done', () {
      expect(NobodyHomeTries.keptBy(VisitStatus.done, _tries(3)), _tries(3));
    });

    test('should keep the tries when the status is come back', () {
      expect(
        NobodyHomeTries.keptBy(VisitStatus.comeBack, _tries(2)),
        _tries(2),
      );
    });

    test('should keep no try when done without one', () {
      expect(
        NobodyHomeTries.keptBy(VisitStatus.done, NobodyHomeTries.none),
        NobodyHomeTries.none,
      );
    });

    test('should count the first try when nobody is home without one', () {
      expect(
        NobodyHomeTries.keptBy(VisitStatus.nobodyHome, NobodyHomeTries.none),
        _tries(1),
      );
    });

    test('should keep the tries when nobody is home after some', () {
      expect(
        NobodyHomeTries.keptBy(VisitStatus.nobodyHome, _tries(3)),
        _tries(3),
      );
    });
  });

  group('equality', () {
    test('should be equal when the counts are equal', () {
      expect(_tries(2), _tries(2));
      expect(_tries(2).hashCode, _tries(2).hashCode);
    });

    test('should differ when the counts differ', () {
      expect(_tries(2), isNot(_tries(3)));
    });

    test('should print its count', () {
      expect(_tries(2).toString(), 'NobodyHomeTries(2)');
    });
  });
}
