import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/my_sectors_json_mapper.dart';

import '../../../domain/sector/my_sectors_fixtures.dart';
import '../../../support/results.dart';

/// The 49 (open), the 12 and the pending 7.
MySectors _manusPhone() => valueOf(
  MySectors.none
      .remember(sector49)
      .remember(sector12)
      .remember(sector7)
      .open(sector49.id),
);

/// How the phone keeps [_manusPhone].
Map<String, Object?> _stored() => {
  'version': 1,
  'open': 't49',
  'tournees': [
    {
      'id': 't49',
      'number': 49,
      'centre': 'CS Villefranche',
      'campaign': 2026,
      'status': 'active',
    },
    {
      'id': 't12',
      'number': 12,
      'centre': 'CS Villefranche',
      'campaign': 2026,
      'status': 'active',
    },
    {
      'id': 't7',
      'number': 7,
      'centre': 'CS Villefranche',
      'campaign': 2026,
      'status': 'pending',
    },
  ],
};

/// [_stored] with [change] made to its first tournée.
Map<String, Object?> _withFirst(void Function(Map<String, Object?>) change) {
  final stored = _stored();
  change((stored['tournees']! as List<Object?>).first! as Map<String, Object?>);
  return stored;
}

void main() {
  group('mySectorsToJson', () {
    test('should write each tournée in order and the open one', () {
      expect(mySectorsToJson(_manusPhone()), _stored());
    });

    test('should write no open tournée as null', () {
      expect(mySectorsToJson(MySectors.none), {
        'version': 1,
        'open': null,
        'tournees': <Object?>[],
      });
    });
  });

  group('a visited tournée', () {
    // The 12 that an admin opened without being in its team (PLAN §5.12).
    final visited = valueOf(
      MySectors.none.remember(sector12Visited).open(sector12Visited.id),
    );
    final stored = {
      'version': 1,
      'open': 't12',
      'tournees': [
        {
          'id': 't12',
          'number': 12,
          'centre': 'CS Villefranche',
          'campaign': 2026,
          'status': 'visiting',
        },
      ],
    };

    test('should write it as visiting', () {
      expect(mySectorsToJson(visited), stored);
    });

    test('should read it back as visiting, open', () {
      expect(mySectorsFromJson(stored), visited);
    });
  });

  group('mySectorsFromJson', () {
    test('should read back what was written', () {
      expect(mySectorsFromJson(_stored()), _manusPhone());
      expect(
        mySectorsFromJson(mySectorsToJson(MySectors.none)),
        MySectors.none,
      );
    });

    test('should read the year and the status of each tournée', () {
      final read = mySectorsFromJson(
        _withFirst((first) => first['campaign'] = 2027),
      );

      expect(read.sectors.first.campaign, campaign2027);
      expect(read.sectors.last.isPending, isTrue);
    });

    test('should refuse what is not a version 1 list', () {
      for (final json in <Object?>[
        null,
        'text',
        {..._stored(), 'version': 2},
        {..._stored(), 'tournees': 'none'},
        {..._stored(), 'open': 49},
        {'version': 1, 'tournees': <Object?>[]},
      ]) {
        expect(
          () => mySectorsFromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });

    test('should refuse a tournée it cannot read', () {
      for (final change in <void Function(Map<String, Object?>)>[
        (first) => first['id'] = ' ',
        (first) => first['id'] = 49,
        (first) => first['number'] = 0,
        (first) => first['number'] = '49',
        (first) => first['centre'] = 'CS',
        (first) => first['campaign'] = 1999,
        (first) => first['status'] = 'ACTIVE',
        (first) => first.remove('status'),
      ]) {
        final json = _withFirst(change);
        expect(
          () => mySectorsFromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });

    test('should refuse an open tournée that is not an active one of the '
        'list', () {
      for (final open in ['t99', 't7']) {
        expect(
          () => mySectorsFromJson({..._stored(), 'open': open}),
          throwsFormatException,
          reason: open,
        );
      }
    });
  });
}
