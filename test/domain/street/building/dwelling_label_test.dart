import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';

import '../../../support/results.dart';

void main() {
  group('parse', () {
    test('should keep a generated label as it is', () {
      expect(valueOf(DwellingLabel.parse('51')).text, '51');
    });

    test('should trim a typed label', () {
      expect(valueOf(DwellingLabel.parse('  Gauche \n')).text, 'Gauche');
    });

    test('should keep the case and the inner spaces', () {
      expect(valueOf(DwellingLabel.parse('Fond cour')).text, 'Fond cour');
    });

    test('should refuse an empty label', () {
      expect(failureOf(DwellingLabel.parse('')), DwellingLabelFailure.blank);
    });

    test('should refuse a label of spaces only', () {
      expect(failureOf(DwellingLabel.parse('   ')), DwellingLabelFailure.blank);
    });

    test('should accept one character', () {
      expect(valueOf(DwellingLabel.parse('A')).text, 'A');
    });

    test('should accept a label of the longest length', () {
      final longest = 'x' * DwellingLabel.maxLength;

      expect(valueOf(DwellingLabel.parse(longest)).text, longest);
    });

    test('should refuse a label one character too long', () {
      expect(
        failureOf(DwellingLabel.parse('x' * (DwellingLabel.maxLength + 1))),
        DwellingLabelFailure.tooLong,
      );
    });

    test('should count the length after trimming', () {
      final padded = '  ${'x' * DwellingLabel.maxLength}  ';

      expect(valueOf(DwellingLabel.parse(padded)).text, hasLength(12));
    });

    test('should count an emoji as one character', () {
      final withEmoji = '${'x' * (DwellingLabel.maxLength - 1)}🚒';

      expect(valueOf(DwellingLabel.parse(withEmoji)).text, withEmoji);
    });

    test('should allow labels of 12 characters', () {
      expect(DwellingLabel.maxLength, 12);
    });
  });

  group('constructor', () {
    test('should build a label made by code', () {
      expect(DwellingLabel('5A').text, '5A');
    });

    test('should throw when the code made a blank label', () {
      expect(() => DwellingLabel(' '), throwsArgumentError);
    });
  });

  test('should be equal when the texts are equal', () {
    expect(DwellingLabel('51'), DwellingLabel(' 51 '));
    expect(DwellingLabel('51').hashCode, DwellingLabel('51').hashCode);
  });

  test('should differ when the case differs', () {
    expect(DwellingLabel('gauche'), isNot(DwellingLabel('Gauche')));
  });

  test('should show its text when printed', () {
    expect(DwellingLabel('51').toString(), 'DwellingLabel(51)');
  });
}
