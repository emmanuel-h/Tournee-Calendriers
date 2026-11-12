import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';

import '../../support/street_fixtures.dart';

void main() {
  // Thursday 22 October 2026.
  final today = day('2026-10-22');

  group('DayFromToday.of', () {
    final cases = {
      '2026-10-20': DayFromToday.earlier,
      '2026-10-21': DayFromToday.yesterday,
      '2026-10-22': DayFromToday.today,
      '2026-10-23': DayFromToday.tomorrow,
      '2026-10-24': DayFromToday.later,
      '2026-12-31': DayFromToday.later,
    };
    cases.forEach((iso, expected) {
      test('should be $expected for $iso when today is 2026-10-22', () {
        expect(DayFromToday.of(day(iso), today: today), expected);
      });
    });
  });

  test('should call only yesterday and earlier past', () {
    expect(DayFromToday.earlier.isPast, isTrue);
    expect(DayFromToday.yesterday.isPast, isTrue);
    expect(DayFromToday.today.isPast, isFalse);
    expect(DayFromToday.tomorrow.isPast, isFalse);
    expect(DayFromToday.later.isPast, isFalse);
  });

  group('ComeBackTime.of', () {
    test('should offer today and tomorrow as chips', () {
      final time = ComeBackTime.of(ComeBack.withoutTime, today: today);

      expect(time.today, today);
      expect(time.tomorrow, day('2026-10-23'));
    });

    test('should choose nothing without time', () {
      final time = ComeBackTime.of(ComeBack.withoutTime, today: today);

      expect(time.chosen, isNull);
      expect(time.hour, isNull);
      expect(time.otherDay, isNull);
    });

    test('should choose nothing when the house is not « repasser »', () {
      final time = ComeBackTime.of(null, today: today);

      expect(time.chosen, isNull);
      expect(time.hour, isNull);
      expect(time.otherDay, isNull);
      expect(time.today, today);
    });

    test('should give the chosen day and its hour', () {
      final time = ComeBackTime.of(
        comeBack('2026-10-24', hour: 18),
        today: today,
      );

      expect(time.chosen, ComeBackDay(day('2026-10-24'), DayFromToday.later));
      expect(time.hour, 18);
    });

    test('should give the chosen day without hour', () {
      final time = ComeBackTime.of(comeBack('2026-10-22'), today: today);

      expect(time.chosen, ComeBackDay(today, DayFromToday.today));
      expect(time.hour, isNull);
    });

    group('the other day', () {
      final cases = {
        '2026-10-20': DayFromToday.earlier,
        '2026-10-21': DayFromToday.yesterday,
        '2026-10-24': DayFromToday.later,
        '2027-01-15': DayFromToday.later,
      };
      cases.forEach((iso, standing) {
        test('should be the chosen day when it is $iso', () {
          final time = ComeBackTime.of(comeBack(iso), today: today);

          expect(time.otherDay, ComeBackDay(day(iso), standing));
        });
      });

      for (final iso in ['2026-10-22', '2026-10-23']) {
        test('should be none when the chosen day is $iso, a chip', () {
          expect(ComeBackTime.of(comeBack(iso), today: today).otherDay, isNull);
        });
      }
    });

    test('should let the calendar go from today to 60 days ahead', () {
      final time = ComeBackTime.of(null, today: today);

      expect(ComeBackTime.calendarDays, 60);
      expect(time.today, today);
      expect(time.lastCalendarDay, day('2026-12-21'));
    });

    group('the day the calendar opens on', () {
      final cases = {
        // In range, the edges included: the chosen day.
        '2026-10-22': '2026-10-22',
        '2026-10-23': '2026-10-23',
        '2026-11-15': '2026-11-15',
        '2026-12-21': '2026-12-21',
        // Out of range: the day after tomorrow.
        '2026-10-21': '2026-10-24',
        '2026-12-22': '2026-10-24',
      };
      cases.forEach((chosen, expected) {
        test('should be $expected when $chosen is chosen', () {
          final time = ComeBackTime.of(comeBack(chosen), today: today);

          expect(time.calendarStart, day(expected));
        });
      });

      test('should be the day after tomorrow without a day', () {
        final time = ComeBackTime.of(ComeBack.withoutTime, today: today);

        expect(time.calendarStart, day('2026-10-24'));
      });
    });

    test('should offer the hours 8 to 21', () {
      expect(ComeBackTime.of(null, today: today).hours, ComeBack.hours);
    });
  });

  group('ComeBackDay', () {
    test('should be equal to another of the same day and standing', () {
      final a = ComeBackDay(today, DayFromToday.today);
      final b = ComeBackDay(day('2026-10-22'), DayFromToday.today);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the day differs', () {
      expect(
        ComeBackDay(today, DayFromToday.later),
        isNot(ComeBackDay(day('2026-10-23'), DayFromToday.later)),
      );
    });

    test('should differ when the standing differs', () {
      expect(
        ComeBackDay(today, DayFromToday.today),
        isNot(ComeBackDay(today, DayFromToday.later)),
      );
    });

    test('should differ from a value of another type', () {
      expect(ComeBackDay(today, DayFromToday.today), isNot(today));
    });

    test('should show its day and standing when printed', () {
      expect(
        ComeBackDay(today, DayFromToday.today).toString(),
        'ComeBackDay(2026-10-22, today)',
      );
    });
  });
}
