import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/phone_settings_json_mapper.dart';

import '../../../domain/tournee/tournee_fixtures.dart';

void main() {
  group('phoneSettingsToJson', () {
    test('should write the name and the theme under fixed names', () {
      expect(
        phoneSettingsToJson(name: nameOf('Manu'), theme: ThemeChoice.dark),
        {'version': 1, 'name': 'Manu', 'theme': 'dark'},
      );
      expect(
        phoneSettingsToJson(name: null, theme: ThemeChoice.light)['theme'],
        'light',
      );
      expect(phoneSettingsToJson(name: null, theme: ThemeChoice.system), {
        'version': 1,
        'name': null,
        'theme': 'system',
      });
    });
  });

  group('phoneSettingsFromJson', () {
    test('should read back the name and each theme', () {
      for (final theme in ThemeChoice.values) {
        final read = phoneSettingsFromJson(
          phoneSettingsToJson(name: nameOf('Léa'), theme: theme),
        );

        expect(read.name, nameOf('Léa'));
        expect(read.theme, theme);
      }
    });

    test('should read no name as null', () {
      final read = phoneSettingsFromJson({
        'version': 1,
        'name': null,
        'theme': 'light',
      });

      expect(read.name, isNull);
      expect(read.theme, ThemeChoice.light);
    });

    test('should refuse what is not a version 1 file', () {
      for (final json in <Object?>[
        null,
        'text',
        {'version': 2, 'name': null, 'theme': 'dark'},
        {'version': 1, 'name': 7, 'theme': 'dark'},
        {'version': 1, 'name': ' ', 'theme': 'dark'},
        {'version': 1, 'name': 'a' * 31, 'theme': 'dark'},
        {'version': 1, 'name': null, 'theme': 'DARK'},
        {'version': 1, 'theme': 'dark'},
      ]) {
        expect(
          () => phoneSettingsFromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });
}
