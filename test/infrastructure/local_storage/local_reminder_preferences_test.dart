import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_reminder_preferences.dart';

void main() {
  late Directory folder;
  late File file;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('reminders_test');
    file = File('${folder.path}/reminders.json');
  });

  tearDown(() => folder.delete(recursive: true));

  test('should be on and never asked when the file does not exist', () async {
    final preferences = await LocalReminderPreferences.load(file);

    expect(preferences.on, isTrue);
    expect(preferences.permissionAsked, isFalse);
  });

  test('should answer at once and keep the choices on the phone', () async {
    final preferences = await LocalReminderPreferences.load(file);

    final switching = preferences.setOn(false);
    expect(preferences.on, isFalse);
    await switching;
    await preferences.markPermissionAsked();

    expect(jsonDecode(file.readAsStringSync()), {
      'version': 1,
      'on': false,
      'permissionAsked': true,
    });
    final reloaded = await LocalReminderPreferences.load(file);
    expect(reloaded.on, isFalse);
    expect(reloaded.permissionAsked, isTrue);
  });

  test('should start afresh from a file it cannot read', () async {
    file.writeAsStringSync('{"version": 9}');

    final preferences = await LocalReminderPreferences.load(file);

    expect(preferences.on, isTrue);
    expect(preferences.permissionAsked, isFalse);
  });
}
