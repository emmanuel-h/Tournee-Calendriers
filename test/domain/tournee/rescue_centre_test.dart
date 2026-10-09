import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';

import '../../support/results.dart';

void main() {
  group('key', () {
    // Each typed name and the key it must give (PLAN §5.2: comparison
    // ignores case, accents and the CS / CIS / « centre de secours » prefix).
    const table = {
      'CS Villefranche': 'villefranche',
      'cs villefranche': 'villefranche',
      'CS VILLEFRANCHE': 'villefranche',
      'Villefranche': 'villefranche',
      'CIS Villefranche': 'villefranche',
      'Cis Villefranche': 'villefranche',
      'Centre de secours Villefranche': 'villefranche',
      'centre de secours de Villefranche': 'villefranche',
      "Centre d'incendie et de secours Villefranche": 'villefranche',
      'Centre d’incendie et de secours de Villefranche': 'villefranche',
      'CS de Villefranche': 'villefranche',
      'CS du Villefranche': 'villefranche',
      'CS des Villefranche': 'villefranche',
      "CS d'Exempleville": 'exempleville',
      '  CS   Villefranche  ': 'villefranche',
      'CS Villefranche-sur-Saône': 'villefranche-sur-saone',
      'CIS VILLEFRANCHE SUR SAONE': 'villefranche-sur-saone',
      'CS Villefranche (Nord)': 'villefranche-nord',
      'CS Villefranche / Nord': 'villefranche-nord',
      'CS Villefranche 2': 'villefranche-2',
      'Écully-Villefranche': 'ecully-villefranche',
      'CSVillefranche': 'csvillefranche',
      'CS Centre de secours Villefranche': 'centre-de-secours-villefranche',
      'CS De': 'de',
      'Villefranche CS': 'villefranche-cs',
      'Centre': 'centre',
      'Centre de Villefranche': 'centre-de-villefranche',
    };

    for (final MapEntry(key: typed, value: expected) in table.entries) {
      test('should give "$expected" when the name is "$typed"', () {
        expect(valueOf(RescueCentre.create(typed)).key.value, expected);
      });
    }

    test('should give equal keys when two names differ only by prefix, '
        'case and accents', () {
      final cs = valueOf(RescueCentre.create('CS Villefranche-sur-Saône'));
      final cis = valueOf(RescueCentre.create('cis villefranche sur saone'));

      expect(cs.key, cis.key);
      expect(cs.key.hashCode, cis.key.hashCode);
    });

    test('should give different keys when the station names differ', () {
      expect(
        valueOf(RescueCentre.create('CS Villefranche')).key,
        isNot(valueOf(RescueCentre.create('CS Villefranche-sur-Saône')).key),
      );
    });

    test('should show its value when printed', () {
      expect(
        valueOf(RescueCentre.create('CS Villefranche')).key.toString(),
        'RescueCentreKey(villefranche)',
      );
    });
  });

  group('name', () {
    test('should keep the name as typed when it is clean', () {
      expect(
        valueOf(RescueCentre.create('CS Villefranche')).name,
        'CS Villefranche',
      );
    });

    test('should trim and join the spaces when the name is typed loosely', () {
      expect(
        valueOf(RescueCentre.create('  CIS  Villefranche\n')).name,
        'CIS Villefranche',
      );
    });

    test('should keep the case and the accents when given them', () {
      expect(
        valueOf(RescueCentre.create('cs villefranche-sur-Saône')).name,
        'cs villefranche-sur-Saône',
      );
    });

    test('should accept the name when it has exactly 80 characters', () {
      final name = 'CS ${'a' * 77}';

      expect(valueOf(RescueCentre.create(name)).name, name);
    });

    test('should count characters as code points when the name holds '
        'emoji', () {
      // 16 characters, then 64 fire engines of one code point (two UTF-16
      // units) each: 80 characters.
      final name = 'CS Villefranche ${'🚒' * 64}';

      expect(valueOf(RescueCentre.create(name)).name, name);
      expect(
        failureOf(RescueCentre.create('$name🚒')),
        RescueCentreFailure.tooLong,
      );
    });

    test('should refuse the name when it has 81 characters', () {
      expect(
        failureOf(RescueCentre.create('CS ${'a' * 78}')),
        RescueCentreFailure.tooLong,
      );
    });
  });

  group('blank', () {
    for (final typed in [
      '',
      '   ',
      'CS',
      'cis ',
      'Centre de secours',
      "Centre d'incendie et de secours",
      '!?',
    ]) {
      test('should refuse "$typed" when nothing names the station', () {
        expect(
          failureOf(RescueCentre.create(typed)),
          RescueCentreFailure.blank,
        );
      });
    }
  });

  group('equality', () {
    test('should be equal when the names are equal', () {
      final a = valueOf(RescueCentre.create('CS Villefranche'));
      final b = valueOf(RescueCentre.create(' CS  Villefranche '));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the names differ but the keys are equal', () {
      final cs = valueOf(RescueCentre.create('CS Villefranche'));
      final cis = valueOf(RescueCentre.create('CIS Villefranche'));

      expect(cs, isNot(cis));
      expect(cs.isSameStationAs(cis), isTrue);
    });

    test('should not be the same station when the keys differ', () {
      final a = valueOf(RescueCentre.create('CS Villefranche'));
      final b = valueOf(RescueCentre.create('CS Villefranche Nord'));

      expect(a.isSameStationAs(b), isFalse);
    });
  });

  test('should show its name when printed', () {
    expect(
      valueOf(RescueCentre.create('CS Villefranche')).toString(),
      'RescueCentre(CS Villefranche)',
    );
  });
}
