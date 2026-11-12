import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/reminders/reminders_notifier.dart';

import '../../support/fakes/fake_reminders.dart';

void main() {
  late FakeReminderScheduler scheduler;
  late FakeReminderPreferences preferences;
  late ProviderContainer container;

  setUp(() {
    scheduler = FakeReminderScheduler();
    preferences = FakeReminderPreferences();
    container = ProviderContainer(
      overrides: [
        reminderSchedulerProvider.overrideWithValue(scheduler),
        reminderPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
  });

  RemindersNotifier notifier() => container.read(remindersProvider.notifier);

  test('should show the switch as kept, allowed until Android answers', () {
    preferences.on = false;

    expect(
      container.read(remindersProvider),
      const RemindersState(on: false, allowed: true),
    );
  });

  test('should say blocked once Android answers it refuses', () async {
    scheduler.allowed = false;
    container.read(remindersProvider);

    await pumpEventQueue();

    final state = container.read(remindersProvider);
    expect(state, const RemindersState(on: true, allowed: false));
    expect(state.blocked, isTrue);
  });

  test('should not say blocked while the switch is off', () {
    expect(const RemindersState(on: false, allowed: false).blocked, isFalse);
    expect(const RemindersState(on: true, allowed: true).blocked, isFalse);
  });

  test('should check Android again when asked', () async {
    container.read(remindersProvider);
    await pumpEventQueue();
    scheduler.allowed = false;

    await notifier().checkAllowed();

    expect(container.read(remindersProvider).allowed, isFalse);
  });

  test('should turn the reminders off at once and keep it', () async {
    container.read(remindersProvider);
    await pumpEventQueue();

    final turning = notifier().turn(on: false);
    expect(container.read(remindersProvider).on, isFalse);
    await turning;

    expect(preferences.switched, [false]);
    expect(scheduler.asked, 0);
  });

  test('should ask Android when the reminders are turned on', () async {
    preferences.on = false;
    container.read(remindersProvider);
    await pumpEventQueue();
    scheduler.grant = false;

    await notifier().turn(on: true);

    expect(scheduler.asked, 1);
    expect(
      container.read(remindersProvider),
      const RemindersState(on: true, allowed: false),
    );
  });

  test('should open Android\'s settings', () async {
    await notifier().openSettings();

    expect(scheduler.settingsOpened, 1);
  });

  test('should compare and print by value', () {
    const state = RemindersState(on: true, allowed: false);

    expect(state, const RemindersState(on: true, allowed: false));
    expect(
      state.hashCode,
      const RemindersState(on: true, allowed: false).hashCode,
    );
    expect(state, isNot(const RemindersState(on: false, allowed: false)));
    expect(state, isNot(const RemindersState(on: true, allowed: true)));
    expect(state.toString(), 'RemindersState(on: true, allowed: false)');
  });
}
