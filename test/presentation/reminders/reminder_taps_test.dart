import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/reminders/reminder_taps.dart';

import '../../domain/come_back/come_back_fixtures.dart';
import '../../support/fakes/fake_reminders.dart';
import '../../support/street_fixtures.dart';

void main() {
  late FakeReminderScheduler scheduler;
  late ProviderContainer container;
  final house = OpenComeBackPlace(
    ComeBackPlace(street: nationaleId, number: n('12')),
  );

  setUp(() {
    scheduler = FakeReminderScheduler();
    container = ProviderContainer(
      overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
    );
    addTearDown(container.dispose);
  });

  /// Follows the taps as the app's root does, then lets them arrive.
  Future<void> follow() async {
    container.listen(reminderTapProvider, (_, _) {});
    await pumpEventQueue();
  }

  test('should wait with no reminder tapped', () async {
    await follow();

    expect(container.read(reminderTapProvider), isNull);
  });

  test('should wait with none when the notifications cannot be read', () async {
    scheduler.failLaunch = Exception('plugin');

    await follow();

    expect(container.read(reminderTapProvider), isNull);
  });

  test('should keep the reminder that launched the app', () async {
    scheduler.launch = house;

    await follow();

    expect(container.read(reminderTapProvider), house);
  });

  test('should keep a reminder tapped until it is opened', () async {
    await follow();

    scheduler.tap(const OpenComeBackList());
    expect(container.read(reminderTapProvider), const OpenComeBackList());
    container.read(reminderTapProvider.notifier).opened();

    expect(container.read(reminderTapProvider), isNull);
  });

  test('should open the same reminder again when tapped again', () async {
    await follow();
    final seen = <ReminderTarget?>[];
    container.listen(reminderTapProvider, (_, target) => seen.add(target));

    scheduler.tap(house);
    container.read(reminderTapProvider.notifier).opened();
    scheduler.tap(house);

    expect(seen, [house, null, house]);
  });
}
