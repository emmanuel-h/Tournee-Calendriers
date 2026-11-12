import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// The reminder tapped that the app has still to open, null when none
/// waits (PLAN §5.17). Not `autoDispose`: the app's root follows it for as
/// long as the app runs, the one that launched the app included.
final reminderTapProvider =
    NotifierProvider<ReminderTapNotifier, ReminderTarget?>(
      ReminderTapNotifier.new,
    );

/// Follows the reminders tapped (`FollowReminderTaps`) and keeps the last
/// one until the app has opened it ([opened]): the app may not have its
/// screens yet when the reminder that launched it arrives.
final class ReminderTapNotifier extends Notifier<ReminderTarget?> {
  @override
  ReminderTarget? build() {
    final taps = ref
        .watch(followReminderTapsProvider)()
        .listen(
          (target) => state = target,
          // The notifications could not be read (a plugin error): no
          // reminder to open, the app opens as usual.
          onError: (Object _) {},
        );
    ref.onDispose(taps.cancel);
    return null;
  }

  /// The app opened the reminder: none waits any more. The same reminder
  /// tapped again is then a change, and opens again.
  void opened() => state = null;
}
