import 'dart:io';

import 'package:tournee_calendriers/application/ports/reminder_preferences.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/reminder_preferences_json_mapper.dart';

/// The [ReminderPreferences] of the phone: `reminders.json` in the storage
/// folder (PLAN §6.3), read once at start-up and then answered from
/// memory. No network, ever.
final class LocalReminderPreferences implements ReminderPreferences {
  LocalReminderPreferences._(this._file, this.on, this.permissionAsked);

  /// Reads the preferences kept in [file]. A missing or unreadable file
  /// means the reminders are on and the permission was never asked: the
  /// next change writes the file again.
  static Future<LocalReminderPreferences> load(File file) async {
    final stored = JsonFile(file);
    var on = true;
    var permissionAsked = false;
    try {
      if (await stored.read() case final json?) {
        (:on, :permissionAsked) = reminderPreferencesFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: start afresh.
    }
    return LocalReminderPreferences._(stored, on, permissionAsked);
  }

  final JsonFile _file;

  @override
  bool on;

  @override
  bool permissionAsked;

  @override
  Future<void> setOn(bool on) {
    this.on = on;
    return _write();
  }

  @override
  Future<void> markPermissionAsked() {
    permissionAsked = true;
    return _write();
  }

  Future<void> _write() => _file.write(
    reminderPreferencesToJson(on: on, permissionAsked: permissionAsked),
  );
}
