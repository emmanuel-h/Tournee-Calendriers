import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';

import '../../support/street_fixtures.dart';
import 'come_back_fixtures.dart';

/// Saturday 24 October 2026 at [hour]:[minute] on the phone's clock.
DateTime _saturdayAt(int hour, [int minute = 0]) =>
    DateTime(2026, 10, 24, hour, minute);

void main() {
  final nationaleAt19 = entry(
    nationaleId,
    '12',
    comeBack('2026-10-24', hour: 19),
  );

  group('ReminderPlan.of', () {
    test('should ring 15 min before the hour of my « repasser »', () {
      final plan = ReminderPlan.of(
        [nationaleAt19],
        member: lea,
        now: _saturdayAt(14),
      );

      expect(plan.reminders, [
        HourReminder(_saturdayAt(18, 45), nationaleAt19),
      ]);
    });

    test('should ring for nobody else\'s « repasser »', () {
      final plan = ReminderPlan.of(
        [
          entry(
            nationaleId,
            '12',
            comeBack('2026-10-24', hour: 19),
            setBy: paulAtThree,
          ),
          entry(lilasId, '12', comeBack('2026-10-24'), nobody: true),
        ],
        member: lea,
        now: _saturdayAt(8),
      );

      expect(plan.reminders, isEmpty);
    });

    test('should ring until the minute before its time, not at it', () {
      List<Reminder> at(DateTime now) =>
          ReminderPlan.of([nationaleAt19], member: lea, now: now).reminders;

      expect(at(_saturdayAt(18, 44)), hasLength(1));
      expect(at(_saturdayAt(18, 45)), isEmpty);
      expect(at(_saturdayAt(18, 46)), isEmpty);
    });

    test(
      'should ring once at 9 h for the day\'s « repasser » without hour',
      () {
        final lilas = entry(lilasId, '12', comeBack('2026-10-24'));
        final pins = entry(pinsId, '3', comeBack('2026-10-24'));

        final plan = ReminderPlan.of(
          [lilas, pins],
          member: lea,
          now: _saturdayAt(7),
        );

        expect(plan.reminders, [
          DayReminder(_saturdayAt(9), saturday, [pins, lilas]),
        ]);
      },
    );

    test('should not ring at 9 h once 9 h is gone', () {
      final lilas = entry(lilasId, '12', comeBack('2026-10-24'));

      List<Reminder> at(DateTime now) =>
          ReminderPlan.of([lilas], member: lea, now: now).reminders;

      expect(at(_saturdayAt(8, 59)), hasLength(1));
      expect(at(_saturdayAt(9)), isEmpty);
    });

    test('should ring one reminder per day without hour', () {
      final sunday = entry(lilasId, '12', comeBack('2026-10-25'));
      final monday = entry(pinsId, '3', comeBack('2026-10-26'));

      final plan = ReminderPlan.of(
        [monday, sunday],
        member: lea,
        now: _saturdayAt(20),
      );

      expect(plan.reminders, [
        DayReminder(DateTime(2026, 10, 25, 9), day('2026-10-25'), [sunday]),
        DayReminder(DateTime(2026, 10, 26, 9), day('2026-10-26'), [monday]),
      ]);
    });

    test('should never ring for a « repasser » without a day', () {
      final plan = ReminderPlan.of(
        [entry(pinsId, '9', ComeBack.withoutTime)],
        member: lea,
        now: _saturdayAt(7),
      );

      expect(plan.reminders, isEmpty);
    });

    test('should never ring for a day gone', () {
      final plan = ReminderPlan.of(
        [
          entry(pasteurId, '5', comeBack('2026-10-23', hour: 18)),
          entry(pasteurId, '7', comeBack('2026-10-23')),
        ],
        member: lea,
        now: _saturdayAt(7),
      );

      expect(plan.reminders, isEmpty);
    });

    test('should list the reminders in the order they ring', () {
      final lilas = entry(lilasId, '12', comeBack('2026-10-24'));
      final pins = entry(pinsId, '3', comeBack('2026-10-24', hour: 8));
      final nationale = entry(
        nationaleId,
        '1',
        comeBack('2026-10-24', hour: 8),
      );

      final plan = ReminderPlan.of(
        [nationaleAt19, lilas, nationale, pins],
        member: lea,
        now: _saturdayAt(7),
      );

      expect(plan.reminders, [
        HourReminder(_saturdayAt(7, 45), pins),
        HourReminder(_saturdayAt(7, 45), nationale),
        DayReminder(_saturdayAt(9), saturday, [lilas]),
        HourReminder(_saturdayAt(18, 45), nationaleAt19),
      ]);
    });
  });

  group('ReminderPlan.rings', () {
    final lilas = entry(lilasId, '12', comeBack('2026-10-24'));
    final plan = ReminderPlan.of(
      [nationaleAt19, lilas, entry(pinsId, '9', ComeBack.withoutTime)],
      member: lea,
      now: _saturdayAt(7),
    );

    test('should ring for a house with an hour or a day', () {
      expect(plan.rings(nationaleAt19.place), isTrue);
      expect(plan.rings(lilas.place), isTrue);
    });

    test('should not ring for a house without a reminder', () {
      expect(
        plan.rings(ComeBackPlace(street: pinsId, number: n('9'))),
        isFalse,
      );
      expect(ReminderPlan.none.rings(lilas.place), isFalse);
    });
  });

  group('HourReminder.hour', () {
    test('should be the hour of its « repasser »', () {
      expect(HourReminder(_saturdayAt(18, 45), nationaleAt19).hour, 19);
    });
  });

  group('Reminder.target', () {
    test('should open the house of an hour reminder', () {
      expect(
        HourReminder(_saturdayAt(18, 45), nationaleAt19).target,
        OpenComeBackPlace(nationaleAt19.place),
      );
    });

    test('should open the only house of a day reminder', () {
      final door = entry(
        pasteurId,
        '8',
        comeBack('2026-10-24'),
        door: DwellingKey(escA, 5, d('51')),
      );

      expect(
        DayReminder(_saturdayAt(9), saturday, [door]).target,
        OpenComeBackPlace(door.place),
      );
    });

    test('should open the list for a day reminder of several houses', () {
      expect(
        DayReminder(_saturdayAt(9), saturday, [
          entry(lilasId, '12', comeBack('2026-10-24')),
          entry(pinsId, '3', comeBack('2026-10-24')),
        ]).target,
        const OpenComeBackList(),
      );
    });
  });

  group('equality', () {
    test('should compare reminders by value', () {
      final other = entry(pinsId, '3', comeBack('2026-10-24', hour: 19));

      expect(
        HourReminder(_saturdayAt(18, 45), nationaleAt19),
        HourReminder(_saturdayAt(18, 45), nationaleAt19),
      );
      expect(
        HourReminder(_saturdayAt(18, 45), nationaleAt19).hashCode,
        HourReminder(_saturdayAt(18, 45), nationaleAt19).hashCode,
      );
      expect(
        HourReminder(_saturdayAt(18, 45), nationaleAt19),
        isNot(HourReminder(_saturdayAt(18, 46), nationaleAt19)),
      );
      expect(
        HourReminder(_saturdayAt(18, 45), nationaleAt19),
        isNot(HourReminder(_saturdayAt(18, 45), other)),
      );
    });

    test('should compare day reminders by value', () {
      DayReminder of(DateTime at, List<ComeBackEntry> entries) =>
          DayReminder(at, saturday, entries);

      expect(
        of(_saturdayAt(9), [nationaleAt19]),
        of(_saturdayAt(9), [nationaleAt19]),
      );
      expect(
        of(_saturdayAt(9), [nationaleAt19]).hashCode,
        of(_saturdayAt(9), [nationaleAt19]).hashCode,
      );
      expect(
        of(_saturdayAt(9), [nationaleAt19]),
        isNot(of(_saturdayAt(10), [nationaleAt19])),
      );
      expect(
        of(_saturdayAt(9), [nationaleAt19]),
        isNot(DayReminder(_saturdayAt(9), day('2026-10-25'), [nationaleAt19])),
      );
      expect(
        of(_saturdayAt(9), [nationaleAt19]),
        isNot(of(_saturdayAt(9), [])),
      );
    });

    test('should compare targets and plans by value', () {
      expect(
        OpenComeBackPlace(nationaleAt19.place),
        OpenComeBackPlace(nationaleAt19.place),
      );
      expect(
        OpenComeBackPlace(nationaleAt19.place).hashCode,
        OpenComeBackPlace(nationaleAt19.place).hashCode,
      );
      expect(
        OpenComeBackPlace(nationaleAt19.place),
        isNot(const OpenComeBackList()),
      );
      expect(
        const OpenComeBackList().hashCode,
        const OpenComeBackList().hashCode,
      );
      ReminderPlan plan(DateTime now) =>
          ReminderPlan.of([nationaleAt19], member: lea, now: now);
      expect(plan(_saturdayAt(7)), plan(_saturdayAt(8)));
      expect(plan(_saturdayAt(7)).hashCode, plan(_saturdayAt(8)).hashCode);
      expect(plan(_saturdayAt(7)), isNot(ReminderPlan.none));
    });

    test('should print what it holds', () {
      final lilas = entry(lilasId, '12', comeBack('2026-10-24'), nobody: true);

      expect(
        ReminderPlan.of([], member: lea, now: _saturdayAt(7)).toString(),
        'ReminderPlan([])',
      );
      expect(
        DayReminder(DateTime(2026, 10, 24, 9), saturday, [lilas]).toString(),
        'DayReminder(2026-10-24 09:00:00.000, 2026-10-24, [$lilas])',
      );
      expect(
        HourReminder(DateTime(2026, 10, 24, 18, 45), lilas).toString(),
        'HourReminder(2026-10-24 18:45:00.000, $lilas)',
      );
      expect(
        OpenComeBackPlace(lilas.place).toString(),
        'OpenComeBackPlace(ComeBackPlace(lilas, 12))',
      );
      expect(const OpenComeBackList().toString(), 'OpenComeBackList');
    });
  });
}
