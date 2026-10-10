import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/moved_streets_json_mapper.dart';

void main() {
  group('movedStreetsToJson', () {
    test('should write the version and the tournées, sorted', () {
      expect(movedStreetsToJson({TourneeId('t49'), TourneeId('t12')}), {
        'version': 1,
        'movedInto': ['t12', 't49'],
      });
    });

    test('should write an empty list when no tournée received them', () {
      expect(movedStreetsToJson({}), {'version': 1, 'movedInto': <String>[]});
    });
  });

  group('movedStreetsFromJson', () {
    test('should read back what was written', () {
      final tournees = {TourneeId('t49'), TourneeId('t12')};

      expect(movedStreetsFromJson(movedStreetsToJson(tournees)), tournees);
    });

    final unreadable = <String, Object?>{
      'not an object': ['t49'],
      'another version': {
        'version': 2,
        'movedInto': ['t49'],
      },
      'no version': {
        'movedInto': ['t49'],
      },
      'no list': {'version': 1},
      'a list of something else': {
        'version': 1,
        'movedInto': [49],
      },
      'a blank id': {
        'version': 1,
        'movedInto': ['  '],
      },
    };
    for (final MapEntry(key: name, value: json) in unreadable.entries) {
      test('should refuse the file when it has $name', () {
        expect(() => movedStreetsFromJson(json), throwsFormatException);
      });
    }
  });
}
