import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/calendars.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';

Calendars _calendars(int count) => valueOf(Calendars.create(count));

void main() {
  group('create', () {
    test('should hold the count when it is between 0 and the limit', () {
      expect(_calendars(3).count, 3);
    });

    test('should be none when the count is 0', () {
      expect(_calendars(0), Calendars.none);
      expect(Calendars.none.count, 0);
    });

    test('should be one when the count is 1', () {
      expect(_calendars(1), Calendars.one);
      expect(Calendars.one.count, 1);
    });

    test('should refuse the count when it is negative', () {
      expect(failureOf(Calendars.create(-1)), CalendarsFailure.outOfRange);
    });

    test('should accept the count when it is the limit', () {
      expect(_calendars(Calendars.max).count, 99);
    });

    test('should refuse the count when it is one past the limit', () {
      expect(failureOf(Calendars.create(100)), CalendarsFailure.outOfRange);
    });
  });

  group('keptBy', () {
    test('should make it one when the status is done and it had none', () {
      expect(Calendars.keptBy(VisitStatus.done, Calendars.none), Calendars.one);
    });

    test('should keep the count when the status is done', () {
      expect(Calendars.keptBy(VisitStatus.done, _calendars(3)), _calendars(3));
    });

    for (final status in [
      VisitStatus.toDo,
      VisitStatus.refused,
      VisitStatus.nobodyHome,
      VisitStatus.comeBack,
    ]) {
      test('should reset the count when the status is $status', () {
        expect(Calendars.keptBy(status, _calendars(3)), Calendars.none);
      });
    }
  });

  group('more', () {
    test('should add one calendar when below the limit', () {
      expect(_calendars(2).more, _calendars(3));
    });

    test('should reach the limit when one below it', () {
      expect(_calendars(98).more, _calendars(99));
    });

    test('should be null at the limit', () {
      expect(_calendars(99).more, isNull);
    });
  });

  group('fewer', () {
    test('should take one calendar away when above one', () {
      expect(_calendars(3).fewer, _calendars(2));
    });

    test('should be one when there were two', () {
      expect(_calendars(2).fewer, Calendars.one);
    });

    test('should be null at one', () {
      expect(Calendars.one.fewer, isNull);
    });

    test('should be null at none', () {
      expect(Calendars.none.fewer, isNull);
    });
  });

  group('equality', () {
    test('should be equal when the counts are', () {
      expect(_calendars(2), _calendars(2));
      expect(_calendars(2).hashCode, _calendars(2).hashCode);
    });

    test('should differ when the counts do', () {
      expect(_calendars(2), isNot(_calendars(3)));
    });

    test('should print its count', () {
      expect(_calendars(4).toString(), 'Calendars(4)');
    });
  });
}
