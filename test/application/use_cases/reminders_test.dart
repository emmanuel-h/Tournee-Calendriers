import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/reminders.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../domain/come_back/come_back_fixtures.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_reminders.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// Saturday 24 October 2026 at 14 h on the phone's clock.
final _saturday2pm = DateTime(2026, 10, 24, 14);

/// 12 Rue Nationale « repasser » today at 19 h, set by Léa.
final _nationaleAt19 = entry(
  nationaleId,
  '12',
  comeBack('2026-10-24', hour: 19),
);

void main() {
  late FakeReminderPreferences preferences;
  late FakeReminderScheduler scheduler;

  setUp(() {
    preferences = FakeReminderPreferences();
    scheduler = FakeReminderScheduler();
  });

  PlanReminders plan() =>
      PlanReminders(preferences, FakeIdentity(lea), FakeClock(_saturday2pm));

  group('ObserveComeBacks', () {
    test(
      'should give the « repasser » of the streets as they change',
      () async {
        final street = valueOf(
          Street.create(
            id: nationaleId,
            name: 'Rue Nationale',
            commune: villefranche,
            houses: [
              House(
                number: n('12'),
                status: VisitStatus.comeBack,
                comeBack: comeBack('2026-10-24', hour: 19),
                lastChange: leaAtTwo,
              ),
            ],
          ),
        );

        final entries = await ObserveComeBacks(
          FakeStreetRepository([street]),
        )().first;

        expect(entries, [_nationaleAt19]);
      },
    );
  });

  group('PlanReminders', () {
    test('should plan the member\'s reminders from the clock', () {
      expect(plan()([_nationaleAt19]).reminders, [
        HourReminder(DateTime(2026, 10, 24, 18, 45), _nationaleAt19),
      ]);
    });

    test('should plan none while the switch is off', () {
      preferences.on = false;

      expect(plan()([_nationaleAt19]), ReminderPlan.none);
    });
  });

  group('ScheduleReminders', () {
    test('should replace the reminders with those planned', () async {
      await ScheduleReminders(plan(), scheduler)([_nationaleAt19]);

      expect(scheduler.replaced, [
        [HourReminder(DateTime(2026, 10, 24, 18, 45), _nationaleAt19)],
      ]);
    });

    test('should cancel them all while the switch is off', () async {
      preferences.on = false;

      await ScheduleReminders(plan(), scheduler)([_nationaleAt19]);

      expect(scheduler.replaced, [<Reminder>[]]);
    });
  });

  group('ReadRemindersOn', () {
    test('should tell whether the switch is on', () {
      expect(ReadRemindersOn(preferences)(), isTrue);
      preferences.on = false;
      expect(ReadRemindersOn(preferences)(), isFalse);
    });
  });

  group('ReadRemindersAllowed', () {
    test('should tell whether Android lets them ring', () async {
      expect(await ReadRemindersAllowed(scheduler)(), isTrue);
      scheduler.allowed = false;
      expect(await ReadRemindersAllowed(scheduler)(), isFalse);
    });
  });

  group('SwitchReminders', () {
    test('should keep the switch on and ask for the permission', () async {
      preferences.on = false;
      scheduler
        ..allowed = false
        ..grant = true;

      final allowed = await SwitchReminders(preferences, scheduler)(on: true);

      expect(allowed, isTrue);
      expect(preferences.switched, [true]);
      expect(preferences.permissionAsked, isTrue);
      expect(scheduler.asked, 1);
    });

    test('should say when Android still refuses', () async {
      scheduler.grant = false;

      expect(await SwitchReminders(preferences, scheduler)(on: true), isFalse);
    });

    test('should keep the switch off without asking anything', () async {
      scheduler.allowed = false;

      final allowed = await SwitchReminders(preferences, scheduler)(on: false);

      expect(allowed, isFalse);
      expect(preferences.switched, [false]);
      expect(preferences.permissionAsked, isFalse);
      expect(scheduler.asked, 0);
    });
  });

  group('AskForRemindersOnce', () {
    test('should ask the first time', () async {
      await AskForRemindersOnce(preferences, scheduler)();

      expect(scheduler.asked, 1);
      expect(preferences.permissionAsked, isTrue);
    });

    test('should not ask again', () async {
      final ask = AskForRemindersOnce(preferences, scheduler);

      await ask();
      await ask();

      expect(scheduler.asked, 1);
    });

    test('should not ask while the switch is off', () async {
      preferences.on = false;

      await AskForRemindersOnce(preferences, scheduler)();

      expect(scheduler.asked, 0);
      expect(preferences.permissionAsked, isFalse);
    });
  });

  group('OpenReminderSettings', () {
    test('should open Android\'s settings', () async {
      await OpenReminderSettings(scheduler)();

      expect(scheduler.settingsOpened, 1);
    });
  });

  group('FollowReminderTaps', () {
    final place = OpenComeBackPlace(_nationaleAt19.place);

    test('should lead first where the launch reminder leads', () async {
      scheduler.launch = place;
      final targets = <ReminderTarget>[];

      final subscription = FollowReminderTaps(scheduler)().listen(targets.add);
      await pumpEventQueue();
      scheduler.tap(const OpenComeBackList());
      await pumpEventQueue();

      expect(targets, [place, const OpenComeBackList()]);
      await subscription.cancel();
    });

    test(
      'should follow the taps alone when no reminder launched the app',
      () async {
        final targets = <ReminderTarget>[];

        final subscription = FollowReminderTaps(
          scheduler,
        )().listen(targets.add);
        await pumpEventQueue();
        scheduler.tap(place);
        await pumpEventQueue();

        expect(targets, [place]);
        await subscription.cancel();
      },
    );
  });
}
