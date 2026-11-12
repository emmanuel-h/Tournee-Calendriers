import 'package:tournee_calendriers/domain/come_back/reminder.dart';

/// The phone's notifications, as the reminders to come back use them
/// (PLAN §5.17): scheduled on the phone, no server, offline too.
///
/// An application port: the use cases own it, an adapter of
/// `infrastructure/notifications/` implements it over Android's
/// notifications, tests use a fake.
abstract interface class ReminderScheduler {
  /// Cancels every reminder scheduled before, then schedules [reminders]
  /// (none: cancels them all). The schedule is always worked out whole
  /// again, so nothing of an old one can stay behind.
  ///
  /// The alarms are inexact: Android may ring a few minutes late, and no
  /// exact-alarm permission is needed. They survive a restart of the phone.
  Future<void> replaceAll(List<Reminder> reminders);

  /// Whether Android lets the app show notifications now; false when the
  /// member refused them, or turned them off in Android's settings.
  Future<bool> areAllowed();

  /// Asks Android for the notification permission (Android 13+ shows its
  /// dialog, at most a couple of times); answers whether they are allowed
  /// once the member decided.
  Future<bool> askPermission();

  /// Opens Android's notification settings of the app (« Réglages »).
  Future<void> openSettings();

  /// Where the reminder that launched the app leads; null when the app
  /// was not launched by a tap on one.
  Future<ReminderTarget?> launchTarget();

  /// Where each reminder tapped while the app runs leads.
  Stream<ReminderTarget> get taps;
}
