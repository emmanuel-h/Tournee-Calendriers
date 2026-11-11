import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/infrastructure/shared/mappers/street_part_fields.dart';

import '../../../support/street_fixtures.dart';

void main() {
  group('storedPart', () {
    test('should store nothing for the whole street', () {
      expect(storedPart(StreetPart.whole), isNull);
    });

    test('should store each side: a range as its bounds', () {
      expect(storedPart(part(odd: range(7, 21), even: range(2, 30))), {
        'odd': [7, 21],
        'even': [2, 30],
      });
    });

    test('should store a whole side as « all » and an empty one as '
        '« none »', () {
      expect(storedPart(part(odd: SidePart.all, even: SidePart.none)), {
        'odd': 'all',
        'even': 'none',
      });
      expect(storedPart(part(odd: SidePart.none, even: SidePart.all)), {
        'odd': 'none',
        'even': 'all',
      });
    });
  });

  group('partFrom', () {
    test('should read a missing part as the whole street', () {
      expect(partFrom(null), StreetPart.whole);
    });

    for (final held in [
      part(odd: range(7, 21), even: range(2, 30)),
      part(odd: SidePart.all, even: SidePart.none),
      part(odd: SidePart.none, even: range(0, 8)),
      part(odd: SidePart.none, even: SidePart.none),
    ]) {
      test('should read back $held as stored', () {
        expect(partFrom(storedPart(held)), held);
      });
    }

    test('should read « all » on both sides as the whole street', () {
      expect(partFrom({'odd': 'all', 'even': 'all'}), StreetPart.whole);
    });

    for (final (what, json) in [
      ('a text', 'all'),
      ('a part without its even side', {'odd': 'all'}),
      ('a side of another word', {'odd': 'some', 'even': 'all'}),
      (
        'a range of one bound',
        {
          'odd': [7],
          'even': 'all',
        },
      ),
      (
        'a range of three bounds',
        {
          'odd': [7, 9, 11],
          'even': 'all',
        },
      ),
      (
        'a range of texts',
        {
          'odd': ['7', '21'],
          'even': 'all',
        },
      ),
      (
        'a range out of the numbers',
        {
          'odd': [7, 100001],
          'even': 'all',
        },
      ),
      (
        'a reversed range',
        {
          'odd': [21, 7],
          'even': 'all',
        },
      ),
      (
        'a bound on the other side',
        {
          'odd': 'all',
          'even': [1, 30],
        },
      ),
    ]) {
      test('should refuse $what', () {
        expect(() => partFrom(json), throwsFormatException);
      });
    }
  });
}
