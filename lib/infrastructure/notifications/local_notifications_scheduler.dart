import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tournee_calendriers/application/ports/reminder_scheduler.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/infrastructure/notifications/mappers/reminder_payload.dart';

/// The French words of a reminder: its title and its text.
typedef ReminderText = ({String title, String body});

/// The [ReminderScheduler] of the phone: Android's local notifications,
/// through `flutter_local_notifications` (PLAN §5.17). No push, no
/// server: the alarms are on the phone and ring offline.
///
/// - **Inexact** alarms (`inexactAllowWhileIdle`): Android may ring a few
///   minutes late, and the app needs no exact-alarm permission, which Play
///   restricts.
/// - **After a restart** of the phone the plugin's boot receiver
///   schedules them again (declared in `AndroidManifest.xml`).
/// - The words come from [words], which the composition root draws from
///   the app's French translations: `infrastructure/` may not read them.
final class LocalNotificationsScheduler implements ReminderScheduler {
  // `this._words` in a named parameter: callers still write `words:`.
  LocalNotificationsScheduler({
    required this._words,
    required this._channelName,
    required this._channelDescription,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The notification channel of the reminders (Android 8+ groups
  /// notifications by channel; the member may silence it alone).
  static const _channelId = 'come_back';

  /// The icon in the status bar: the helmet alone, white on nothing, as
  /// Android draws a small icon.
  static const _icon = 'ic_notification';

  /// Asks MainActivity to open Android's notification settings of the app;
  /// the plugin has no such call.
  static const _settings = MethodChannel(
    'fr.mandarine.tourneecalendriers/settings',
  );

  final ReminderText Function(Reminder reminder) _words;
  final String _channelName;
  final String _channelDescription;
  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<ReminderTarget>.broadcast();

  /// The plugin is started once, the first time anything needs it: not
  /// at launch, so the first screen never waits for it.
  late final Future<void> _ready = _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings(_icon),
    ),
    onDidReceiveNotificationResponse: (response) {
      if (reminderTargetFrom(response.payload) case final target?) {
        _taps.add(target);
      }
    },
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    await _ready;
    await _plugin.cancelAllPendingNotifications();
    for (final (index, reminder) in reminders.indexed) {
      final text = _words(reminder);
      try {
        await _plugin.zonedSchedule(
          id: index,
          // The instant itself, in UTC: Android rings at that instant. The
          // domain worked it out on the phone's clock.
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
          title: text.title,
          body: text.body,
          payload: reminderPayload(reminder.target),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              // Several addresses show whole once the notification opens.
              styleInformation: BigTextStyleInformation(text.body),
            ),
          ),
        );
      } on ArgumentError {
        // Its time went by while the others were scheduled: it would no
        // longer ring anyway.
      }
    }
  }

  // A plugin that fails (a phone without notifications, a channel gone)
  // is nothing the member can act on: it answers « not allowed », « no
  // reminder », rather than an error crossing into the screens.

  @override
  Future<bool> areAllowed() => _orElse(false, () async {
    await _ready;
    return await _android?.areNotificationsEnabled() ?? false;
  });

  @override
  Future<bool> askPermission() => _orElse(false, () async {
    await _ready;
    return await _android?.requestNotificationsPermission() ?? false;
  });

  @override
  Future<void> openSettings() => _orElse(
    null,
    () => _settings.invokeMethod<void>('openNotificationSettings'),
  );

  @override
  Future<ReminderTarget?> launchTarget() => _orElse(null, () async {
    await _ready;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch == null || !launch.didNotificationLaunchApp) return null;
    return reminderTargetFrom(launch.notificationResponse?.payload);
  });

  static Future<T> _orElse<T>(T fallback, Future<T> Function() run) async {
    try {
      return await run();
    } on PlatformException {
      return fallback;
    } on MissingPluginException {
      return fallback;
    }
  }

  @override
  Stream<ReminderTarget> get taps => _taps.stream;
}
