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
    test('should offer a week from today, in order', () {
      final time = ComeBackTime.of(ComeBack.withoutTime, today: today);

      expect(time.days, [
        ComeBackDay(today, DayFromToday.today),
        ComeBackDay(day('2026-10-23'), DayFromToday.tomorrow),
        ComeBackDay(day('2026-10-24'), DayFromToday.later),
        ComeBackDay(day('2026-10-25'), DayFromToday.later),
        ComeBackDay(day('2026-10-26'), DayFromToday.later),
        ComeBackDay(day('2026-10-27'), DayFromToday.later),
        ComeBackDay(day('2026-10-28'), DayFromToday.later),
      ]);
      expect(ComeBackTime.dayCount, 7);
    });

    test('should choose nothing without time', () {
      final time = ComeBackTime.of(ComeBack.withoutTime, today: today);

      expect(time.chosen, isNull);
      expect(time.hour, isNull);
    });

    test('should choose nothing when the house is not « repasser »', () {
      final time = ComeBackTime.of(null, today: today);

      expect(time.chosen, isNull);
      expect(time.hour, isNull);
      expect(time.days, hasLength(7));
    });

    test('should give the chosen day and its hour', () {
      final time = ComeBackTime.of(
        comeBack('2026-10-24', hour: 18),
        today: today,
      );

      expect(time.chosen, ComeBackDay(day('2026-10-24'), DayFromToday.later));
      expect(time.hour, 18);
      expect(time.days, hasLength(7));
    });

    test('should give the chosen day without hour', () {
      final time = ComeBackTime.of(comeBack('2026-10-22'), today: today);

      expect(time.chosen, ComeBackDay(today, DayFromToday.today));
      expect(time.hour, isNull);
    });

    test('should keep the last day of the week among the chips', () {
      final time = ComeBackTime.of(comeBack('2026-10-28'), today: today);

      expect(time.days, hasLength(7));
      expect(time.days.last.day, day('2026-10-28'));
    });

    test('should add a chip after the week for a later day', () {
      final time = ComeBackTime.of(comeBack('2026-10-29'), today: today);

      expect(time.days, hasLength(8));
      expect(
        time.days.last,
        ComeBackDay(day('2026-10-29'), DayFromToday.later),
      );
    });

    test('should add a chip before today for a past day', () {
      final time = ComeBackTime.of(
        comeBack('2026-10-21', hour: 19),
        today: today,
      );

      expect(time.days, hasLength(8));
      expect(
        time.days.first,
        ComeBackDay(day('2026-10-21'), DayFromToday.yesterday),
      );
      expect(time.days[1], ComeBackDay(today, DayFromToday.today));
      expect(
        time.chosen,
        ComeBackDay(day('2026-10-21'), DayFromToday.yesterday),
      );
    });

    test('should not let its days be changed', () {
      final time = ComeBackTime.of(null, today: today);

      expect(() => time.days.add(time.days.first), throwsUnsupportedError);
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
