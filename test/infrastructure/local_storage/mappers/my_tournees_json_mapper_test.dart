import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/my_tournees_json_mapper.dart';

import '../../../domain/tournee/my_tournees_fixtures.dart';
import '../../../support/results.dart';

/// The 49 (open), the 12 and the pending 7.
MyTournees _manusPhone() => valueOf(
  MyTournees.none
      .remember(tournee49)
      .remember(tournee12)
      .remember(tournee7)
      .open(tournee49.id),
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
  group('myTourneesToJson', () {
    test('should write each tournée in order and the open one', () {
      expect(myTourneesToJson(_manusPhone()), _stored());
    });

    test('should write no open tournée as null', () {
      expect(myTourneesToJson(MyTournees.none), {
        'version': 1,
        'open': null,
        'tournees': <Object?>[],
      });
    });
  });

  group('myTourneesFromJson', () {
    test('should read back what was written', () {
      expect(myTourneesFromJson(_stored()), _manusPhone());
      expect(
        myTourneesFromJson(myTourneesToJson(MyTournees.none)),
        MyTournees.none,
      );
    });

    test('should read the year and the status of each tournée', () {
      final read = myTourneesFromJson(
        _withFirst((first) => first['campaign'] = 2027),
      );

      expect(read.tournees.first.campaign, campaign2027);
      expect(read.tournees.last.isPending, isTrue);
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
          () => myTourneesFromJson(json),
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
          () => myTourneesFromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });

    test('should refuse an open tournée that is not an active one of the '
        'list', () {
      for (final open in ['t99', 't7']) {
        expect(
          () => myTourneesFromJson({..._stored(), 'open': open}),
          throwsFormatException,
          reason: open,
        );
      }
    });
  });
}
