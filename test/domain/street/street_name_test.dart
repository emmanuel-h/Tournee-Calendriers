import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the name when it is typed cleanly', () {
      expect(
        valueOf(StreetName.create('Chemin des Vignes')).text,
        'Chemin des Vignes',
      );
    });

    test('should trim spaces around the name', () {
      expect(
        valueOf(StreetName.create('  Rue des Lilas \n')).text,
        'Rue des Lilas',
      );
    });

    test('should turn each run of spaces or line breaks inside into one '
        'space', () {
      expect(
        valueOf(StreetName.create('Rue  des\n\tLilas')).text,
        'Rue des Lilas',
      );
    });

    test('should keep the case and the accents when given them', () {
      expect(
        valueOf(StreetName.create("allée de l'Église")).text,
        "allée de l'Église",
      );
    });

    test('should refuse the name when it is empty', () {
      expect(failureOf(StreetName.create('')), StreetNameFailure.blank);
    });

    test('should refuse the name when it is only spaces', () {
      expect(failureOf(StreetName.create(' \t\n ')), StreetNameFailure.blank);
    });

    test('should accept a name of one character', () {
      expect(valueOf(StreetName.create('A')).text, 'A');
    });

    test('should accept the name when it has 149 characters', () {
      expect(valueOf(StreetName.create('a' * 149)).text, 'a' * 149);
    });

    test('should accept the name when it has exactly 150 characters', () {
      expect(valueOf(StreetName.create('a' * 150)).text, 'a' * 150);
    });

    test('should refuse the name when it has 151 characters', () {
      expect(
        failureOf(StreetName.create('a' * 151)),
        StreetNameFailure.tooLong,
      );
    });

    test('should count the limit after trimming when spaces surround it', () {
      expect(valueOf(StreetName.create('  ${'a' * 150}  ')).text, 'a' * 150);
    });

    test('should count the limit after joining the spaces inside', () {
      final name = '${'a' * 74}    ${'b' * 75}';

      expect(valueOf(StreetName.create(name)).text, '${'a' * 74} ${'b' * 75}');
    });

    test('should count an emoji as one character when measuring', () {
      final name = '🚒' * 150;

      expect(valueOf(StreetName.create(name)).text, name);
      expect(
        failureOf(StreetName.create('🚒' * 151)),
        StreetNameFailure.tooLong,
      );
    });
  });

  group('equality', () {
    test('should be equal when the cleaned texts are equal', () {
      final typed = valueOf(StreetName.create(' Rue  des Lilas '));
      final clean = valueOf(StreetName.create('Rue des Lilas'));

      expect(typed, clean);
      expect(typed.hashCode, clean.hashCode);
    });

    test('should differ when the case differs', () {
      expect(
        valueOf(StreetName.create('Rue des Lilas')),
        isNot(valueOf(StreetName.create('rue des lilas'))),
      );
    });

    test('should differ from a value of another type', () {
      expect(
        valueOf(StreetName.create('Rue des Lilas')),
        isNot('Rue des Lilas'),
      );
    });
  });

  test('should show its text when printed', () {
    expect(
      valueOf(StreetName.create('Rue des Lilas')).toString(),
      'StreetName(Rue des Lilas)',
    );
  });
}
