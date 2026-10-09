import 'dart:math';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';

import '../../support/results.dart';
import '../../support/scripted_random.dart';

void main() {
  group('alphabet', () {
    test('should hold 31 characters when look-alikes are left out', () {
      expect(JoinCode.alphabet, 'ABCDEFGHJKMNPQRSTUVWXYZ23456789');
      expect(JoinCode.alphabet.length, 31);
    });

    test('should leave out 0, O, 1, I and L when listing the characters', () {
      for (final lookAlike in ['0', 'O', '1', 'I', 'L']) {
        expect(JoinCode.alphabet, isNot(contains(lookAlike)));
      }
    });
  });

  group('generate', () {
    test('should pick each character from the alphabet at the drawn '
        'position', () {
      final code = JoinCode.generate(ScriptedRandom([9, 28, 12, 23, 13, 20]));

      expect(code.value, 'K7P2QX');
    });

    test('should draw each position among the 31 characters', () {
      final random = ScriptedRandom([0, 30, 0, 30, 0, 30]);

      final code = JoinCode.generate(random);

      expect(code.value, 'A9A9A9');
      expect(random.maxima, [31, 31, 31, 31, 31, 31]);
    });

    test('should make six characters of the alphabet when the source is '
        'random', () {
      final code = JoinCode.generate(Random(42));

      expect(code.value, hasLength(6));
      for (final character in code.value.split('')) {
        expect(JoinCode.alphabet, contains(character));
      }
    });
  });

  group('parse', () {
    test('should read the code when it is typed as shown', () {
      expect(valueOf(JoinCode.parse('K7P-2QX')).value, 'K7P2QX');
    });

    test('should read the code when it is typed without the dash', () {
      expect(valueOf(JoinCode.parse('K7P2QX')).value, 'K7P2QX');
    });

    test('should ignore case when the code is typed in lower case', () {
      expect(valueOf(JoinCode.parse('k7p-2qx')).value, 'K7P2QX');
    });

    test('should ignore spaces around and inside when the code is pasted', () {
      expect(valueOf(JoinCode.parse(' K7P 2QX\n')).value, 'K7P2QX');
    });

    test('should refuse a character outside the alphabet when one is '
        'typed', () {
      for (final typed in [
        'K7P-2Q0',
        'K7P-2QO',
        'K7P-2Q1',
        'K7P-2QI',
        'l7P2QX',
      ]) {
        expect(
          failureOf(JoinCode.parse(typed)),
          JoinCodeFailure.invalidCharacter,
          reason: typed,
        );
      }
    });

    test('should refuse punctuation other than the dash when it is typed', () {
      expect(
        failureOf(JoinCode.parse('K7P_2QX')),
        JoinCodeFailure.invalidCharacter,
      );
    });

    test('should refuse the code when it has five characters', () {
      expect(failureOf(JoinCode.parse('K7P2Q')), JoinCodeFailure.wrongLength);
    });

    test('should refuse the code when it has seven characters', () {
      expect(failureOf(JoinCode.parse('K7P2QXA')), JoinCodeFailure.wrongLength);
    });

    test('should refuse the code when nothing is typed', () {
      expect(failureOf(JoinCode.parse(' - ')), JoinCodeFailure.wrongLength);
    });

    test('should name the character first when the code is both too long '
        'and holds a look-alike', () {
      expect(
        failureOf(JoinCode.parse('K7P2QX0')),
        JoinCodeFailure.invalidCharacter,
      );
    });
  });

  test('should show three characters, a dash and three characters when '
      'displayed', () {
    expect(valueOf(JoinCode.parse('K7P2QX')).display, 'K7P-2QX');
  });

  group('equality', () {
    test('should be equal when the characters are equal', () {
      final typed = valueOf(JoinCode.parse('k7p-2qx'));
      final stored = valueOf(JoinCode.parse('K7P2QX'));

      expect(typed, stored);
      expect(typed.hashCode, stored.hashCode);
    });

    test('should differ when one character differs', () {
      expect(
        valueOf(JoinCode.parse('K7P2QX')),
        isNot(valueOf(JoinCode.parse('K7P2QY'))),
      );
    });
  });

  test('should show its value when printed', () {
    expect(valueOf(JoinCode.parse('K7P2QX')).toString(), 'JoinCode(K7P-2QX)');
  });
}
