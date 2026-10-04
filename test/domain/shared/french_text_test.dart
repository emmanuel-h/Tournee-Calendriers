import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';

void main() {
  group('searchKey', () {
    test('should lower the case when given capitals', () {
      expect(searchKey('RUE NATIONALE'), 'rue nationale');
    });

    test('should drop the accents of French letters when given them', () {
      expect(
        searchKey('àâäáãå çéèêë îïíì ôöóòõ ùûüú ÿý ñ'),
        'aaaaaa ceeee iiii ooooo uuuu yy n',
      );
      expect(searchKey('ÉGLISE'), 'eglise');
    });

    test('should spell the ligatures out when given œ or æ', () {
      expect(searchKey('Cœur Lætitia'), 'coeur laetitia');
    });

    test('should drop an accent typed as a separate mark', () {
      // « e » followed by U+0301 COMBINING ACUTE ACCENT.
      expect(searchKey('E\u0301glise'), 'eglise');
    });

    test(
      'should drop the first and last combining marks, not their neighbours',
      () {
        // U+0300 and U+036F bound the block of combining marks; U+02FF and
        // U+0370 sit just outside it.
        expect(searchKey('a\u0300b\u036Fc'), 'abc');
        expect(searchKey('a\u02FFb\u0370c'), 'a\u02FFb\u0371c');
      },
    );

    test('should read hyphens and apostrophes as spaces', () {
      expect(searchKey("Allée de l'Église"), 'allee de l eglise');
      expect(searchKey('Saint-Roch'), 'saint roch');
      expect(searchKey('l’Abbé'), 'l abbe');
    });

    test('should trim and make each run of spaces one space', () {
      expect(searchKey('  Rue   des\tLilas  '), 'rue des lilas');
    });

    test('should keep digits and other characters as they are', () {
      expect(searchKey('Rue du 8 Mai 1945 & co'), 'rue du 8 mai 1945 & co');
    });
  });

  group('compareFrench', () {
    test('should sort an accented initial with its plain letter', () {
      final names = ['Rue Nationale', 'Église', 'Avenue', 'Ecole', 'Zola']
        ..sort(compareFrench);

      expect(names, ['Avenue', 'Ecole', 'Église', 'Rue Nationale', 'Zola']);
    });

    test('should ignore the case', () {
      expect(compareFrench('allée', 'Avenue'), lessThan(0));
      expect(compareFrench('Avenue', 'allée'), greaterThan(0));
    });

    test('should tell equal two names that differ only by accents or case', () {
      expect(compareFrench('Église', 'eglise'), 0);
    });
  });

  group('matchesFilter', () {
    test('should find a name by a part typed without accents or capitals', () {
      expect(matchesFilter("Place de l'Église", 'eglise'), isTrue);
      expect(matchesFilter('Rue Nationale', 'NATION'), isTrue);
    });

    test('should find a hyphenated name typed with a space', () {
      expect(matchesFilter('Rue Saint-Roch', 'saint roch'), isTrue);
    });

    test('should not find a name that does not hold the text', () {
      expect(matchesFilter('Rue Nationale', 'lilas'), isFalse);
    });

    test('should find every name when the filter is blank', () {
      expect(matchesFilter('Rue Nationale', '   '), isTrue);
      expect(matchesFilter('Rue Nationale', ''), isTrue);
    });
  });
}
