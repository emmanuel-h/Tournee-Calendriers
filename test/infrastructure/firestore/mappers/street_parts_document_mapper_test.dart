import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_parts_document_mapper.dart';

import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';

final _t49 = SectorId('t49');
final _t12 = SectorId('t12');
final _number12 = valueOf(SectorNumber.create(12));
final _csVillefranche = valueOf(RescueCentre.create('CS Villefranche'));

Map<String, Object?> _entry(
  int number,
  String centre, {
  Object odd = 'all',
  Object even = 'all',
}) => {'number': number, 'centreName': centre, 'odd': odd, 'even': even};

void main() {
  group('openSectorDocument', () {
    test('should name the secteur the phone has open, and nothing else', () {
      expect(openSectorDocument(_t49), {'sectorId': 't49'});
    });
  });

  group('heldPartWrite', () {
    test(
      'should write the secteur\'s entry, both sides, naming the secteur',
      () {
        expect(
          heldPartWrite(
            _t12,
            number: _number12,
            centre: _csVillefranche,
            part: part(odd: range(19, 41), even: SidePart.none),
          ),
          {
            'sector': 't12',
            'parts': {
              't12': {
                'number': 12,
                'centreName': 'CS Villefranche',
                'odd': [19, 41],
                'even': 'none',
              },
            },
          },
        );
      },
    );

    test('should write the whole street as both sides « all »', () {
      final write = heldPartWrite(
        _t49,
        number: valueOf(SectorNumber.create(49)),
        centre: valueOf(RescueCentre.create('CS Arnas')),
        part: StreetPart.whole,
      );

      expect(write, {
        'sector': 't49',
        'parts': {'t49': _entry(49, 'CS Arnas')},
      });
    });
  });

  group('releasedPartWrite', () {
    test('should replace the secteur\'s entry by the removal, naming the '
        'secteur', () {
      const removal = #delete;

      expect(releasedPartWrite(_t49, removal), {
        'sector': 't49',
        'parts': {'t49': removal},
      });
    });
  });

  group('otherPartsFrom', () {
    test('should read every other secteur\'s entry, leaving out the one '
        'asked for', () {
      final others = otherPartsFrom({
        'sector': 't12',
        'parts': {
          't12': _entry(12, 'CS Villefranche', odd: [19, 41], even: 'none'),
          't49': _entry(49, 'CS Villefranche'),
          't3': _entry(3, 'CS Arnas', odd: 'none', even: [2, 8]),
        },
      }, except: _t49);

      expect(others, [
        SectorPart(
          sector: _number12,
          centre: _csVillefranche,
          part: part(odd: range(19, 41), even: SidePart.none),
        ),
        SectorPart(
          sector: valueOf(SectorNumber.create(3)),
          centre: valueOf(RescueCentre.create('CS Arnas')),
          part: part(odd: SidePart.none, even: range(2, 8)),
        ),
      ]);
    });

    test('should read none without a document, or without entries', () {
      expect(otherPartsFrom(null, except: _t49), isEmpty);
      expect(otherPartsFrom({'sector': 't49'}, except: _t49), isEmpty);
      expect(
        otherPartsFrom({'sector': 't49', 'parts': 'all'}, except: _t49),
        isEmpty,
      );
      expect(
        otherPartsFrom({
          'sector': 't49',
          'parts': <String, Object?>{},
        }, except: _t49),
        isEmpty,
      );
    });

    for (final (why, entry) in [
      (
        'no number',
        {'centreName': 'CS Villefranche', 'odd': 'all', 'even': 'all'},
      ),
      ('a number as text', _entry(12, 'CS Villefranche')..['number'] = '12'),
      ('a number out of range', _entry(0, 'CS Villefranche')),
      ('no centre', {'number': 12, 'odd': 'all', 'even': 'all'}),
      ('a blank centre', _entry(12, '  ')),
      ('no side', {'number': 12, 'centreName': 'CS Villefranche'}),
      ('a side refused', _entry(12, 'CS Villefranche', odd: [2, 8])),
      ('a side unreadable', _entry(12, 'CS Villefranche', even: 'some')),
      ('not a map', 'Secteur 12'),
    ]) {
      test('should leave out an entry with $why, keeping the others', () {
        final others = otherPartsFrom({
          'sector': 't12',
          'parts': {'t12': entry, 't3': _entry(3, 'CS Arnas')},
        }, except: _t49);

        expect(others.map((other) => other.sector.value), [3]);
      });
    }
  });
}
