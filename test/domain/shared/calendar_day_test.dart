import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the year, month and day when the date exists', () {
      final day = valueOf(CalendarDay.create(2026, 10, 24));

      expect(day.year, 2026);
      expect(day.month, 10);
      expect(day.day, 24);
    });

    test('should accept the 29 February of a leap year', () {
      expect(valueOf(CalendarDay.create(2028, 2, 29)).day, 29);
    });

    test('should refuse the 29 February of another year', () {
      expect(
        failureOf(CalendarDay.create(2026, 2, 29)),
        CalendarDayFailure.noSuchDay,
      );
    });

    test('should accept the 31st of a month of 31 days', () {
      expect(valueOf(CalendarDay.create(2026, 12, 31)).day, 31);
    });

    test('should refuse the 31st of a month of 30 days', () {
      expect(
        failureOf(CalendarDay.create(2026, 11, 31)),
        CalendarDayFailure.noSuchDay,
      );
    });

    for (final (month, day) in [(0, 1), (13, 1), (1, 0), (1, 32)]) {
      test('should refuse month $month, day $day', () {
        expect(
          failureOf(CalendarDay.create(2026, month, day)),
          CalendarDayFailure.noSuchDay,
        );
      });
    }

    test('should accept the years 2000 and 2999, the edges', () {
      expect(valueOf(CalendarDay.create(2000, 1, 1)).year, 2000);
      expect(valueOf(CalendarDay.create(2999, 12, 31)).year, 2999);
    });

    test('should refuse the years 1999 and 3000, just outside', () {
      expect(
        failureOf(CalendarDay.create(1999, 12, 31)),
        CalendarDayFailure.noSuchDay,
      );
      expect(
        failureOf(CalendarDay.create(3000, 1, 1)),
        CalendarDayFailure.noSuchDay,
      );
    });
  });

  group('of', () {
    test('should take the calendar day of the time as it is given', () {
      final day = CalendarDay.of(DateTime(2026, 10, 24, 23, 59));

      expect(day, valueOf(CalendarDay.create(2026, 10, 24)));
    });

    test('should take the day of a UTC time in UTC', () {
      final day = CalendarDay.of(DateTime.utc(2026, 10, 24, 0, 1));

      expect(day, valueOf(CalendarDay.create(2026, 10, 24)));
    });
  });

  group('plusDays', () {
    final saturday = valueOf(CalendarDay.create(2026, 10, 24));

    test('should give the next day when one is added', () {
      expect(saturday.plusDays(1), valueOf(CalendarDay.create(2026, 10, 25)));
    });

    test('should give the day before when one is taken', () {
      expect(saturday.plusDays(-1), valueOf(CalendarDay.create(2026, 10, 23)));
    });

    test('should cross into the next month and year', () {
      final lastDay = valueOf(CalendarDay.create(2026, 12, 31));

      expect(lastDay.plusDays(1), valueOf(CalendarDay.create(2027, 1, 1)));
    });

    test('should count calendar days across the change to winter time', () {
      // Clocks go back in France on 25 October 2026: a day of 25 hours.
      expect(saturday.plusDays(2), valueOf(CalendarDay.create(2026, 10, 26)));
    });
  });

  group('daysSince', () {
    final saturday = valueOf(CalendarDay.create(2026, 10, 24));

    test('should count the days from an earlier day', () {
      final monday = valueOf(CalendarDay.create(2026, 10, 26));

      expect(monday.daysSince(saturday), 2);
    });

    test('should be negative from a later day', () {
      final thursday = valueOf(CalendarDay.create(2026, 10, 22));

      expect(thursday.daysSince(saturday), -2);
    });

    test('should be 0 from the same day', () {
      expect(saturday.daysSince(saturday), 0);
    });
  });

  test('should name its day of the week, Monday 1 to Sunday 7', () {
    expect(valueOf(CalendarDay.create(2026, 10, 24)).weekday, 6);
    expect(valueOf(CalendarDay.create(2026, 10, 26)).weekday, 1);
  });

  test('should be midnight of its day as a local time', () {
    final time = valueOf(CalendarDay.create(2026, 10, 24)).toDateTime();

    expect(time, DateTime(2026, 10, 24));
    expect(time.isUtc, isFalse);
  });

  group('equality', () {
    test('should be equal when the dates are equal', () {
      final a = valueOf(CalendarDay.create(2026, 10, 24));
      final b = CalendarDay.of(DateTime(2026, 10, 24, 18));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the day differs', () {
      expect(
        valueOf(CalendarDay.create(2026, 10, 24)),
        isNot(valueOf(CalendarDay.create(2026, 10, 25))),
      );
    });

    test('should differ when the month differs', () {
      expect(
        valueOf(CalendarDay.create(2026, 10, 24)),
        isNot(valueOf(CalendarDay.create(2026, 11, 24))),
      );
    });

    test('should differ when the year differs', () {
      expect(
        valueOf(CalendarDay.create(2026, 10, 24)),
        isNot(valueOf(CalendarDay.create(2027, 10, 24))),
      );
    });

    test('should differ from a value of another type', () {
      expect(valueOf(CalendarDay.create(2026, 10, 24)), isNot('2026-10-24'));
    });
  });

  test('should print as an ISO date, with zeros', () {
    expect(valueOf(CalendarDay.create(2026, 3, 7)).toString(), '2026-03-07');
  });
}
