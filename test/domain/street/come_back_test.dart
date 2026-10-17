import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';

void main() {
  final saturday = valueOf(CalendarDay.create(2026, 10, 24));
  final sunday = valueOf(CalendarDay.create(2026, 10, 25));

  group('create', () {
    test('should keep the day and the hour when both are given', () {
      final comeBack = valueOf(ComeBack.create(day: saturday, hour: 18));

      expect(comeBack.day, saturday);
      expect(comeBack.hour, 18);
    });

    test('should keep the day without hour when no hour is given', () {
      final comeBack = valueOf(ComeBack.create(day: saturday));

      expect(comeBack.day, saturday);
      expect(comeBack.hour, isNull);
    });

    test('should have no time when neither is given', () {
      final comeBack = valueOf(ComeBack.create());

      expect(comeBack, ComeBack.withoutTime);
      expect(comeBack.day, isNull);
      expect(comeBack.hour, isNull);
    });

    test('should refuse an hour without a day', () {
      expect(
        failureOf(ComeBack.create(hour: 18)),
        ComeBackFailure.hourWithoutDay,
      );
    });

    test('should accept 8 h and 21 h, the first and last hours', () {
      expect(valueOf(ComeBack.create(day: saturday, hour: 8)).hour, 8);
      expect(valueOf(ComeBack.create(day: saturday, hour: 21)).hour, 21);
    });

    test('should refuse 7 h and 22 h, just outside', () {
      expect(
        failureOf(ComeBack.create(day: saturday, hour: 7)),
        ComeBackFailure.hourOutOfRange,
      );
      expect(
        failureOf(ComeBack.create(day: saturday, hour: 22)),
        ComeBackFailure.hourOutOfRange,
      );
    });
  });

  test('should offer the hours 8 to 21', () {
    expect(ComeBack.hours, [
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
    ]);
    expect(ComeBack.firstHour, 8);
    expect(ComeBack.lastHour, 21);
  });

  group('keptBy', () {
    final evening = valueOf(ComeBack.create(day: saturday, hour: 19));

    test('should keep the time of a « repasser »', () {
      expect(ComeBack.keptBy(VisitStatus.comeBack, evening), evening);
    });

    test('should come back without time when « repasser » has none', () {
      expect(ComeBack.keptBy(VisitStatus.comeBack, null), ComeBack.withoutTime);
    });

    for (final status in [
      VisitStatus.toDo,
      VisitStatus.done,
      VisitStatus.nobodyHome,
    ]) {
      test('should keep nothing when the door is $status', () {
        expect(ComeBack.keptBy(status, evening), isNull);
      });
    }
  });

  group('equality', () {
    test('should be equal when the day and hour are equal', () {
      final a = valueOf(ComeBack.create(day: saturday, hour: 18));
      final b = valueOf(
        ComeBack.create(day: CalendarDay.of(DateTime(2026, 10, 24)), hour: 18),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the days differ', () {
      expect(
        valueOf(ComeBack.create(day: saturday, hour: 18)),
        isNot(valueOf(ComeBack.create(day: sunday, hour: 18))),
      );
    });

    test('should differ when the hours differ', () {
      expect(
        valueOf(ComeBack.create(day: saturday, hour: 18)),
        isNot(valueOf(ComeBack.create(day: saturday, hour: 19))),
      );
    });

    test('should differ when only one has an hour', () {
      expect(
        valueOf(ComeBack.create(day: saturday)),
        isNot(valueOf(ComeBack.create(day: saturday, hour: 18))),
      );
    });

    test('should differ from a value of another type', () {
      expect(ComeBack.withoutTime, isNot(''));
    });
  });

  group('toString', () {
    test('should show the day and the hour', () {
      expect(
        valueOf(ComeBack.create(day: saturday, hour: 18)).toString(),
        'ComeBack(2026-10-24 18h)',
      );
    });

    test('should show the day alone without hour', () {
      expect(
        valueOf(ComeBack.create(day: saturday)).toString(),
        'ComeBack(2026-10-24)',
      );
    });

    test('should show nothing without time', () {
      expect(ComeBack.withoutTime.toString(), 'ComeBack()');
    });
  });
}
