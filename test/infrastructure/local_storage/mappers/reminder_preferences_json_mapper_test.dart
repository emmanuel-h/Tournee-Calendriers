import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/reminder_preferences_json_mapper.dart';

void main() {
  test('should write the switch and whether the permission was asked', () {
    expect(reminderPreferencesToJson(on: false, permissionAsked: true), {
      'version': 1,
      'on': false,
      'permissionAsked': true,
    });
  });

  test('should read back what it wrote', () {
    for (final (on, asked) in [(true, false), (false, true)]) {
      expect(
        reminderPreferencesFromJson(
          reminderPreferencesToJson(on: on, permissionAsked: asked),
        ),
        (on: on, permissionAsked: asked),
      );
    }
  });

  final notOurs = <String, Object?>{
    'another version': {'version': 2, 'on': true, 'permissionAsked': false},
    'a switch that is not a bool': {
      'version': 1,
      'on': 'yes',
      'permissionAsked': false,
    },
    'no permission field': {'version': 1, 'on': true},
    'a list': [1],
  };
  notOurs.forEach((what, json) {
    test('should refuse $what', () {
      expect(
        () => reminderPreferencesFromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
