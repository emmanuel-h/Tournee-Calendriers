import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/reminders.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/reminders/reminder_sync.dart';
import 'package:tournee_calendriers/presentation/reminders/reminders_notifier.dart';

import '../../domain/come_back/come_back_fixtures.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_reminders.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// Saturday 24 October 2026 at 14 h on the phone's clock.
final _saturday2pm = DateTime(2026, 10, 24, 14);

/// 12 Rue Nationale « repasser » at [hour] today, set by Léa.
Street _nationale({int hour = 19}) => valueOf(
  Street.create(
    id: nationaleId,
    name: 'Rue Nationale',
    commune: villefranche,
    houses: [
      House(
        number: n('12'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-10-24', hour: hour),
        lastChange: leaAtTwo,
      ),
    ],
  ),
);

final _at1845 = DateTime(2026, 10, 24, 18, 45);

void main() {
  late FakeStreetRepository streets;
  late FakeReminderScheduler scheduler;
  late FakeReminderPreferences preferences;
  late ProviderContainer container;

  setUp(() {
    streets = FakeStreetRepository([_nationale()]);
    scheduler = FakeReminderScheduler();
    preferences = FakeReminderPreferences();
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        reminderPreferencesProvider.overrideWithValue(preferences),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
        clockProvider.overrideWithValue(FakeClock(_saturday2pm)),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Keeps the sync alive, as the app's root does.
  Future<void> start() async {
    container.listen(reminderSyncProvider, (_, _) {});
    await pumpEventQueue();
  }

  ComeBackEntry nationaleEntry({int hour = 19}) =>
      entry(nationaleId, '12', comeBack('2026-10-24', hour: hour));

  test('should schedule the reminders of the open secteur', () async {
    await start();

    expect(scheduler.scheduled, [HourReminder(_at1845, nationaleEntry())]);
  });

  test('should schedule them again when the streets change', () async {
    await start();

    await streets.save(
      _nationale(hour: 20),
      // Any change: the fake keeps the street and tells the listeners.
      ComeBackSet(
        streetId: nationaleId,
        before: _nationale().houses.single,
        stamp: leaAtTwo,
        comeBack: comeBack('2026-10-24', hour: 20),
      ),
    );
    await pumpEventQueue();

    expect(scheduler.scheduled, [
      HourReminder(DateTime(2026, 10, 24, 19, 45), nationaleEntry(hour: 20)),
    ]);
  });

  test('should cancel them all when the switch is turned off', () async {
    await start();

    await container.read(remindersProvider.notifier).turn(on: false);
    await pumpEventQueue();

    expect(scheduler.scheduled, isEmpty);
  });

  test('should cancel them all when the streets cannot be read', () async {
    streets.watchError = StateError('removed from the secteur');

    await start();

    expect(scheduler.replaced, [<Reminder>[]]);
  });

  test('should try again at the next change when Android refused', () async {
    scheduler.failNextReplace = Exception('refused');
    await start();

    await streets.save(
      _nationale(hour: 20),
      ComeBackSet(
        streetId: nationaleId,
        before: _nationale().houses.single,
        stamp: leaAtTwo,
        comeBack: comeBack('2026-10-24', hour: 20),
      ),
    );
    await pumpEventQueue();

    expect(scheduler.replaced, hasLength(2));
    expect(scheduler.scheduled, [
      HourReminder(DateTime(2026, 10, 24, 19, 45), nationaleEntry(hour: 20)),
    ]);
  });

  group('ReminderSync', () {
    test('should schedule one at a time, then only the latest', () async {
      final holding = Completer<void>();
      scheduler.holdReplaces = holding;
      final sync = ReminderSync(
        ScheduleReminders(
          PlanReminders(
            preferences,
            FakeIdentity(lea),
            FakeClock(_saturday2pm),
          ),
          scheduler,
        ),
      );
      final first = [nationaleEntry()];
      final second = [nationaleEntry(hour: 20)];
      final third = [nationaleEntry(hour: 21)];

      final running = sync.update(first);
      unawaited(sync.update(second));
      final last = sync.update(third);
      holding.complete();
      await running;

      expect(identical(running, last), isTrue);
      expect(scheduler.replaced, [
        [HourReminder(_at1845, nationaleEntry())],
        [
          HourReminder(
            DateTime(2026, 10, 24, 20, 45),
            nationaleEntry(hour: 21),
          ),
        ],
      ]);
    });
  });
}
