import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the name when it is typed cleanly', () {
      expect(valueOf(MemberName.create('Léa')).text, 'Léa');
    });

    test('should trim and join the spaces when the name is typed loosely', () {
      expect(
        valueOf(MemberName.create('  Jean   Pierre\n')).text,
        'Jean Pierre',
      );
    });

    test('should refuse the name when it is only spaces', () {
      expect(failureOf(MemberName.create(' \n ')), MemberNameFailure.blank);
    });

    test('should accept a name of one character', () {
      expect(valueOf(MemberName.create('A')).text, 'A');
    });

    test('should accept the name when it has exactly 30 characters', () {
      expect(valueOf(MemberName.create('a' * 30)).text, 'a' * 30);
    });

    test('should refuse the name when it has 31 characters', () {
      expect(failureOf(MemberName.create('a' * 31)), MemberNameFailure.tooLong);
    });

    test('should count characters as code points when the name holds '
        'emoji', () {
      expect(valueOf(MemberName.create('🚒' * 30)).text, '🚒' * 30);
      expect(
        failureOf(MemberName.create('🚒' * 31)),
        MemberNameFailure.tooLong,
      );
    });
  });

  group('key', () {
    String keyOf(String text) => valueOf(MemberName.create(text)).key;

    test('should ignore case and accents when names are compared', () {
      expect(keyOf('Léa'), 'lea');
      expect(keyOf('LÉA'), 'lea');
      expect(keyOf('Lea'), 'lea');
      expect(keyOf('Zoë Œillet'), 'zoe oeillet');
    });

    test('should drop the accents typed as a separate mark', () {
      // « e » followed by U+0301, the combining acute accent.
      expect(keyOf('Le\u0301a'), 'lea');
    });

    test('should read dashes, apostrophes, dots, underscores and slashes as '
        'spaces', () {
      expect(keyOf('Jean-Paul'), 'jean paul');
      expect(keyOf("N'Golo"), 'n golo');
      expect(keyOf('Léa B.'), 'lea b');
      expect(keyOf('__Léa__'), 'lea');
      expect(keyOf('Léa/B'), 'lea b');
    });

    test('should keep the case of letters the server cannot lower', () {
      // The security rules lower A to Z only: « Ø » and « ø » stay apart.
      expect(keyOf('ZØ'), 'zØ');
      expect(keyOf('ΣΑΜ'), 'ΣΑΜ');
      expect(keyOf('ÇA ÑANDÚ ŸVES ÆLLE'), 'ca nandu yves aelle');
      // The same as the rules' tests (firebase/test/names.test.mjs).
      expect(keyOf('ÀÂÄÁÃÅ ÉÈÊË ÎÏÍÌ'), 'aaaaaa eeee iiii');
      expect(keyOf('ÔÖÓÒÕ ÙÛÜÚ ŸÝ'), 'ooooo uuuu yy');
      expect(keyOf('Œdipe Ærø'), 'oedipe aerø');
      expect(keyOf('Zoé_B/2'), 'zoe b 2');
      expect(keyOf('N’Golo'), 'n golo');
    });

    test('should keep apart names that differ by more than case and '
        'accents', () {
      expect(keyOf('Léa B.'), isNot(keyOf('Léa')));
      expect(keyOf('🚒 Léa'), '🚒 lea');
    });

    test('should refuse a name with nothing but separators', () {
      // Its key would be empty: no name could be held under it.
      for (final text in ['-', '...', "' _ /", '.']) {
        expect(
          failureOf(MemberName.create(text)),
          MemberNameFailure.blank,
          reason: text,
        );
      }
    });

    test('should accept a name of one letter among separators', () {
      expect(keyOf('-a-'), 'a');
    });
  });

  group('equality', () {
    test('should be equal when the cleaned names are equal', () {
      final a = valueOf(MemberName.create('Léa'));
      final b = valueOf(MemberName.create(' Léa '));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the case differs', () {
      expect(
        valueOf(MemberName.create('Léa')),
        isNot(valueOf(MemberName.create('léa'))),
      );
    });
  });

  test('should show its text when printed', () {
    expect(valueOf(MemberName.create('Léa')).toString(), 'MemberName(Léa)');
  });
}
