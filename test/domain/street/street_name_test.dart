import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

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

  group('matches', () {
    final musee = streetName('Rue du Musée');

    test('should match the same name', () {
      expect(musee.matches('Rue du Musée'), isTrue);
    });

    test('should match whatever the case and the accents', () {
      expect(musee.matches('RUE DU MUSEE'), isTrue);
      expect(streetName('Rue du Musee').matches('Rue du Musée'), isTrue);
    });

    test('should match either apostrophe', () {
      expect(streetName("Rue de l'Église").matches('Rue de l’Église'), isTrue);
    });

    test('should match a hyphen for a space', () {
      expect(streetName('Rue Saint Roch').matches('Rue Saint-Roch'), isTrue);
    });

    test('should not match a longer name that starts the same', () {
      expect(
        streetName('Rue Nationale').matches('Rue Nationale Prolongée'),
        isFalse,
      );
    });

    test('should not match another name', () {
      expect(musee.matches('Rue du Marché'), isFalse);
    });
  });

  group('typosFrom', () {
    final paix = streetName('Rue de la Paix');

    test('should be 0 for a name it matches', () {
      expect(paix.typosFrom('RUE DE LA PAIX'), 0);
    });

    test('should count a misspelt small word', () {
      expect(paix.typosFrom('Rue de le Paix'), 1);
      expect(paix.typosFrom('Rue du la Paix'), 1);
    });

    test('should count a small word left out or added', () {
      expect(paix.typosFrom('Rue la Paix'), 3);
      expect(streetName('Rue Paix').typosFrom('Rue de la Paix'), 6);
    });

    test('should not be close when a short word differs by one letter', () {
      // « Mare » and « Gare »: two streets, not a typo.
      expect(streetName('Rue de la Mare').typosFrom('Rue de la Gare'), isNull);
      expect(paix.typosFrom('Rue de la Gare'), isNull);
    });

    test('should count one letter off in a long word', () {
      expect(streetName('Rue Pasteur').typosFrom('Rue Pasteir'), 1);
      expect(streetName('Rue Pasteur').typosFrom('Rue Pasteurs'), 1);
    });

    test('should not be close when a word one letter off is under seven '
        'letters', () {
      expect(streetName('Rue Morand').typosFrom('Rue Morant'), isNull);
      expect(streetName('Rue Pasteur').typosFrom('Rue Paster'), isNull);
    });

    test('should not be close when a long word is two letters off', () {
      expect(streetName('Rue Pasteur').typosFrom('Rue Pastoor'), isNull);
    });

    test('should not be close when two long words are one letter off', () {
      expect(
        streetName('Avenue Antoine Lumière')
            .typosFrom('Avenue Antoinne Lumieres'),
        isNull,
      );
    });

    test('should not be close when a word is added', () {
      expect(
        streetName('Rue Nationale').typosFrom('Rue Nationale Prolongée'),
        isNull,
      );
    });

    test('should not be close for another kind of road', () {
      expect(paix.typosFrom('Impasse de la Paix'), isNull);
    });
  });

  group('closestNamed', () {
    String? closest(String name, List<String> names) =>
        closestNamed(name, names, streetName)?.toString();

    test('should take the first name it matches', () {
      expect(
        closestNamed('Rue du Musee', [
          'Rue de la Paix',
          'Rue du Musée',
          'RUE DU MUSEE',
        ], streetName),
        'Rue du Musée',
      );
    });

    test('should take the name it matches before a closer typo', () {
      expect(
        closest('Rue de le Paix', ['Rue de la Paix', 'Rue de le Paix']),
        'Rue de le Paix',
      );
    });

    test('should take the name with the fewest typos', () {
      expect(
        closest('Rue de le Paix', [
          'Rue Paix',
          'Rue de la Paix',
          'Rue la Paix',
        ]),
        'Rue de la Paix',
      );
    });

    test('should take none when no name is close', () {
      expect(closest('Rue de la Mare', ['Rue de la Gare']), isNull);
      expect(closest('Rue de la Mare', []), isNull);
    });

    test('should take none when two names are as close', () {
      expect(closest('Rue d Paix', ['Rue de Paix', 'Rue du Paix']), isNull);
    });

    test('should take the first when the closest name comes twice', () {
      final first = streetName('Rue de la Paix');
      final second = streetName('Rue de la Paix');

      expect(
        closestNamed('Rue de le Paix', [first, second], (name) => name),
        same(first),
      );
    });
  });
}
