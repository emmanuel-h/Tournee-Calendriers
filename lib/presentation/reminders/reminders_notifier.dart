import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// « RAPPELS » of Paramètres, and whether the reminders ring at all. Not
/// `autoDispose`: the reminders of the whole app follow its switch
/// (`reminderSyncProvider`), and « À repasser » its 🔔.
final remindersProvider = NotifierProvider<RemindersNotifier, RemindersState>(
  RemindersNotifier.new,
);

/// What « RAPPELS » shows (PLAN §5.17, mockup SettingsReminders).
final class RemindersState {
  const RemindersState({required this.on, required this.allowed});

  /// « Rappels pour repasser » is on.
  final bool on;

  /// Android lets the app show notifications; true until it was asked.
  final bool allowed;

  /// « Bloqués par Android » with « Réglages » in place of the switch:
  /// the member wants them, Android refuses.
  bool get blocked => on && !allowed;

  @override
  bool operator ==(Object other) =>
      other is RemindersState && other.on == on && other.allowed == allowed;

  @override
  int get hashCode => Object.hash(on, allowed);

  @override
  String toString() => 'RemindersState(on: $on, allowed: $allowed)';
}

/// Shows and changes « Rappels pour repasser », and tells when Android
/// blocks the notifications. On the phone only.
final class RemindersNotifier extends Notifier<RemindersState> {
  @override
  RemindersState build() {
    // Android is asked in the background; until it answers, nothing is
    // said blocked.
    unawaited(checkAllowed());
    return RemindersState(
      on: ref.watch(readRemindersOnProvider)(),
      allowed: true,
    );
  }

  /// Asks Android again whether it lets the notifications show: at
  /// start-up, and when the member comes back from its settings.
  Future<void> checkAllowed() async {
    final allowed = await ref.read(readRemindersAllowedProvider)();
    state = RemindersState(on: state.on, allowed: allowed);
  }

  /// The switch: turned on, Android is asked for the permission.
  Future<void> turn({required bool on}) async {
    state = RemindersState(on: on, allowed: state.allowed);
    final allowed = await ref.read(switchRemindersProvider)(on: on);
    state = RemindersState(on: on, allowed: allowed);
  }

  /// « Réglages »: Android's notification settings of the app.
  Future<void> openSettings() => ref.read(openReminderSettingsProvider)();
}
