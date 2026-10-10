import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_phone_settings.dart';

import '../../domain/tournee/tournee_fixtures.dart';

void main() {
  late Directory folder;
  late File file;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('phone_settings_test');
    // In a folder not made yet, as on a first launch.
    file = File('${folder.path}/storage/settings.json');
  });

  tearDown(() => folder.delete(recursive: true));

  test('should have no name and the phone theme when the file does not '
      'exist', () async {
    final settings = await LocalPhoneSettings.load(file);

    expect(settings.memberName, isNull);
    expect(settings.theme, ThemeChoice.system);
    expect(file.existsSync(), isFalse);
  });

  test('should answer at once and keep the name and the theme on the '
      'phone', () async {
    final settings = await LocalPhoneSettings.load(file);

    final naming = settings.setMemberName(nameOf('Manu'));
    expect(settings.memberName, nameOf('Manu'));
    await naming;
    final theming = settings.setTheme(ThemeChoice.dark);
    expect(settings.theme, ThemeChoice.dark);
    await theming;

    expect(jsonDecode(file.readAsStringSync()), {
      'version': 1,
      'name': 'Manu',
      'theme': 'dark',
    });
    final reloaded = await LocalPhoneSettings.load(file);
    expect(reloaded.memberName, nameOf('Manu'));
    expect(reloaded.theme, ThemeChoice.dark);
  });

  test('should start afresh when the file is not ours', () async {
    await file.parent.create(recursive: true);
    file.writeAsStringSync('[]');

    final settings = await LocalPhoneSettings.load(file);

    expect(settings.memberName, isNull);
    expect(settings.theme, ThemeChoice.system);
  });

  test('should start afresh when the file is not JSON', () async {
    await file.parent.create(recursive: true);
    file.writeAsStringSync('{');

    final settings = await LocalPhoneSettings.load(file);

    expect(settings.memberName, isNull);
    expect(settings.theme, ThemeChoice.system);
  });
}
