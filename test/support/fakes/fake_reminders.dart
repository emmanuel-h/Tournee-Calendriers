// In-memory fakes of the reminder ports (PLAN §5.17): no Android, no file;
// they record what the use cases asked so tests can assert it.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/reminder_preferences.dart';
import 'package:tournee_calendriers/application/ports/reminder_scheduler.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';

final class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.allowed = true, this.launch});

  /// What [areAllowed] answers; [askPermission] answers [grant] and sets it.
  bool allowed;

  /// What the member answers Android's permission dialog.
  bool grant = true;

  /// Where the reminder that launched the app leads.
  ReminderTarget? launch;

  /// The reminders as last scheduled; null until [replaceAll] runs.
  List<Reminder>? scheduled;

  /// Every list given to [replaceAll], in order.
  final replaced = <List<Reminder>>[];

  /// When set, the next [replaceAll] records its list, then throws it, as
  /// Android refusing would; [launchTarget] throws [failLaunch].
  Exception? failNextReplace;
  Exception? failLaunch;

  /// When set, each [replaceAll] waits for it once it has recorded its
  /// list: a test holds a replacement half way.
  Completer<void>? holdReplaces;

  /// How many times the permission was asked, the settings opened.
  var asked = 0;
  var settingsOpened = 0;

  final _taps = StreamController<ReminderTarget>.broadcast(sync: true);

  /// A reminder tapped while the app runs.
  void tap(ReminderTarget target) => _taps.add(target);

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    replaced.add(reminders);
    scheduled = reminders;
    if (failNextReplace case final failure?) {
      failNextReplace = null;
      throw failure;
    }
    await holdReplaces?.future;
  }

  @override
  Future<bool> areAllowed() async => allowed;

  @override
  Future<bool> askPermission() async {
    asked++;
    return allowed = grant;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<ReminderTarget?> launchTarget() async {
    if (failLaunch case final failure?) throw failure;
    return launch;
  }

  @override
  Stream<ReminderTarget> get taps => _taps.stream;
}

final class FakeReminderPreferences implements ReminderPreferences {
  FakeReminderPreferences({this.on = true, this.permissionAsked = false});

  @override
  bool on;

  @override
  bool permissionAsked;

  /// Every value given to [setOn], in order.
  final switched = <bool>[];

  @override
  Future<void> setOn(bool on) async {
    switched.add(on);
    this.on = on;
  }

  @override
  Future<void> markPermissionAsked() async => permissionAsked = true;
}
