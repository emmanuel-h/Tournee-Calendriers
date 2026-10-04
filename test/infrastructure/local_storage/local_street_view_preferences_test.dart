import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_view_preferences.dart';

void main() {
  late Directory folder;
  late File file;
  final nationale = StreetId('nationale');
  final morin = StreetId('morin');

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('street_view_test');
    // In a folder not made yet, as on a first launch.
    file = File('${folder.path}/preferences/street_view.json');
  });

  tearDown(() => folder.delete(recursive: true));

  test('should hide nothing when the file does not exist', () async {
    final preferences = await LocalStreetViewPreferences.load(file);

    expect(preferences.hidesDone(nationale), isFalse);
    expect(file.existsSync(), isFalse);
  });

  test('should answer at once and keep the choice on the phone', () async {
    final preferences = await LocalStreetViewPreferences.load(file);

    final saving = preferences.setHidesDone(nationale, hide: true);
    expect(preferences.hidesDone(nationale), isTrue);
    await saving;

    expect(jsonDecode(file.readAsStringSync()), {
      'version': 1,
      'hideDone': ['nationale'],
    });
    final reloaded = await LocalStreetViewPreferences.load(file);
    expect(reloaded.hidesDone(nationale), isTrue);
    expect(reloaded.hidesDone(morin), isFalse);
  });

  test('should forget a street shown whole again', () async {
    final preferences = await LocalStreetViewPreferences.load(file);
    await preferences.setHidesDone(nationale, hide: true);
    await preferences.setHidesDone(morin, hide: true);

    await preferences.setHidesDone(nationale, hide: false);

    expect(preferences.hidesDone(nationale), isFalse);
    final reloaded = await LocalStreetViewPreferences.load(file);
    expect(reloaded.hidesDone(nationale), isFalse);
    expect(reloaded.hidesDone(morin), isTrue);
  });

  test('should write in the order asked when toggled quickly', () async {
    final preferences = await LocalStreetViewPreferences.load(file);

    await Future.wait([
      preferences.setHidesDone(nationale, hide: true),
      preferences.setHidesDone(nationale, hide: false),
      preferences.setHidesDone(morin, hide: true),
    ]);

    final reloaded = await LocalStreetViewPreferences.load(file);
    expect(reloaded.hidesDone(nationale), isFalse);
    expect(reloaded.hidesDone(morin), isTrue);
  });

  test(
    'should start with nothing hidden when the file is unreadable',
    () async {
      await file.parent.create(recursive: true);
      file.writeAsStringSync('{"version": 9}');

      final preferences = await LocalStreetViewPreferences.load(file);

      expect(preferences.hidesDone(nationale), isFalse);
    },
  );

  test('should start with nothing hidden when the file is not JSON', () async {
    await file.parent.create(recursive: true);
    file.writeAsBytesSync([0xff, 0xfe, 0x00]);

    final preferences = await LocalStreetViewPreferences.load(file);

    expect(preferences.hidesDone(nationale), isFalse);
  });

  test('should keep writing after a write failed', () async {
    final preferences = await LocalStreetViewPreferences.load(file);
    // A folder where the file should be: the rename over it fails.
    await Directory(file.path).create(recursive: true);

    await expectLater(
      preferences.setHidesDone(nationale, hide: true),
      throwsA(isA<FileSystemException>()),
    );
    await Directory(file.path).delete();
    await preferences.setHidesDone(morin, hide: true);

    final reloaded = await LocalStreetViewPreferences.load(file);
    expect(reloaded.hidesDone(nationale), isTrue);
    expect(reloaded.hidesDone(morin), isTrue);
  });
}
