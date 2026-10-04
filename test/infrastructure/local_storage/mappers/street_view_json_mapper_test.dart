import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/street_view_json_mapper.dart';

void main() {
  group('streetViewToJson', () {
    test('should write the version and the streets hiding done, sorted', () {
      expect(streetViewToJson({StreetId('nationale'), StreetId('morin')}), {
        'version': 1,
        'hideDone': ['morin', 'nationale'],
      });
    });

    test('should write an empty list when no street hides done', () {
      expect(streetViewToJson({}), {'version': 1, 'hideDone': <String>[]});
    });
  });

  group('streetViewFromJson', () {
    test('should read back what was written', () {
      final streets = {StreetId('nationale'), StreetId('morin')};

      expect(streetViewFromJson(streetViewToJson(streets)), streets);
    });

    final unreadable = <String, Object?>{
      'not an object': ['nationale'],
      'another version': {
        'version': 2,
        'hideDone': ['nationale'],
      },
      'no version': {
        'hideDone': ['nationale'],
      },
      'no list': {'version': 1},
      'a list of something else': {
        'version': 1,
        'hideDone': [12],
      },
      'a blank id': {
        'version': 1,
        'hideDone': ['  '],
      },
    };
    for (final MapEntry(key: name, value: json) in unreadable.entries) {
      test('should refuse the file when it has $name', () {
        expect(() => streetViewFromJson(json), throwsFormatException);
      });
    }
  });
}
