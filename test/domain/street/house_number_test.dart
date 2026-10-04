import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';

import '../../support/results.dart';

/// Shorthand for a number the test knows is valid.
HouseNumber _n(String text) => valueOf(HouseNumber.parse(text));

void main() {
  group('parse', () {
    // input → number, suffix (canonical, lowercase), label
    const valid = <String, (int, String?, String)>{
      '12': (12, null, '12'),
      '0': (0, null, '0'),
      '012': (12, null, '12'),
      '12bis': (12, 'bis', '12bis'),
      '12 bis': (12, 'bis', '12bis'),
      '12BIS': (12, 'bis', '12bis'),
      '12Bis': (12, 'bis', '12bis'),
      '12   bis': (12, 'bis', '12bis'),
      '  12 bis  ': (12, 'bis', '12bis'),
      '12\tbis': (12, 'bis', '12bis'),
      '7ter': (7, 'ter', '7ter'),
      '7 quater': (7, 'quater', '7quater'),
      '9 QUINQUIES': (9, 'quinquies', '9quinquies'),
      '9 decies': (9, 'decies', '9decies'),
      '12 B': (12, 'b', '12B'),
      '3A': (3, 'a', '3A'),
      '3a': (3, 'a', '3A'),
      '5 b2': (5, 'b2', '5B2'),
      '4 lot': (4, 'lot', '4LOT'),
    };

    valid.forEach((input, expected) {
      final (number, suffix, label) = expected;
      test(
        'should read $number, $suffix and show $label when given "$input"',
        () {
          final houseNumber = _n(input);

          expect(houseNumber.number, number);
          expect(houseNumber.suffix, suffix);
          expect(houseNumber.label, label);
        },
      );
    });

    const invalid = <String, HouseNumberFailure>{
      '': HouseNumberFailure.empty,
      '   ': HouseNumberFailure.empty,
      'bis': HouseNumberFailure.malformed,
      'A3': HouseNumberFailure.malformed,
      '-3': HouseNumberFailure.malformed,
      ' n°12': HouseNumberFailure.malformed,
      '12 3': HouseNumberFailure.invalidSuffix,
      '12 b is': HouseNumberFailure.invalidSuffix,
      '12-bis': HouseNumberFailure.invalidSuffix,
      '12.5': HouseNumberFailure.invalidSuffix,
      '12é': HouseNumberFailure.invalidSuffix,
      '12 bis!': HouseNumberFailure.invalidSuffix,
    };

    invalid.forEach((input, failure) {
      test('should fail with $failure when given "$input"', () {
        expect(failureOf(HouseNumber.parse(input)), failure);
      });
    });

    test('should accept the number when it is 99998', () {
      expect(_n('99998').number, 99998);
    });

    test('should accept the number when it is the maximum 99999', () {
      expect(_n('99999').number, 99999);
    });

    test('should refuse the number when it is 100000', () {
      expect(
        failureOf(HouseNumber.parse('100000')),
        HouseNumberFailure.numberTooLarge,
      );
    });

    test('should refuse the number when it is too long to fit in an int', () {
      expect(
        failureOf(HouseNumber.parse('9' * 25)),
        HouseNumberFailure.numberTooLarge,
      );
    });

    test('should accept the number when leading zeros pad the maximum', () {
      expect(_n('0099999').number, 99999);
    });

    test('should accept the suffix when it has 15 letters', () {
      expect(_n('3 ${'a' * 15}').suffix, 'a' * 15);
    });

    test('should accept the suffix when it has the maximum 16 letters', () {
      expect(_n('3 ${'a' * 16}').suffix, 'a' * 16);
    });

    test('should refuse the suffix when it has 17 letters', () {
      expect(
        failureOf(HouseNumber.parse('3 ${'a' * 17}')),
        HouseNumberFailure.suffixTooLong,
      );
    });
  });

  group('create', () {
    test('should hold the number alone when there is no suffix', () {
      final houseNumber = valueOf(HouseNumber.create(12));

      expect(houseNumber.number, 12);
      expect(houseNumber.suffix, isNull);
      expect(houseNumber.label, '12');
    });

    test('should hold the suffix when the address base gives one', () {
      final houseNumber = valueOf(HouseNumber.create(12, suffix: 'bis'));

      expect(houseNumber.number, 12);
      expect(houseNumber.suffix, 'bis');
      expect(houseNumber.label, '12bis');
    });

    test('should lower-case and trim the suffix', () {
      final houseNumber = valueOf(HouseNumber.create(3, suffix: ' A '));

      expect(houseNumber.suffix, 'a');
      expect(houseNumber.label, '3A');
    });

    test('should have no suffix when the suffix is empty', () {
      expect(valueOf(HouseNumber.create(5, suffix: '')).suffix, isNull);
    });

    test('should have no suffix when the suffix is blank', () {
      expect(valueOf(HouseNumber.create(5, suffix: '  ')).suffix, isNull);
    });

    test('should accept the number zero', () {
      expect(valueOf(HouseNumber.create(0)).label, '0');
    });

    test('should refuse the number when it is negative', () {
      expect(
        failureOf(HouseNumber.create(-1)),
        HouseNumberFailure.negativeNumber,
      );
    });

    test('should accept the number when it is the maximum 99999', () {
      expect(valueOf(HouseNumber.create(99999)).number, 99999);
    });

    test('should refuse the number when it is 100000', () {
      expect(
        failureOf(HouseNumber.create(100000)),
        HouseNumberFailure.numberTooLarge,
      );
    });

    test('should refuse the suffix when it starts with a digit', () {
      expect(
        failureOf(HouseNumber.create(3, suffix: '1a')),
        HouseNumberFailure.invalidSuffix,
      );
    });

    test('should refuse the suffix when it holds a space', () {
      expect(
        failureOf(HouseNumber.create(3, suffix: 'b is')),
        HouseNumberFailure.invalidSuffix,
      );
    });

    test('should refuse the suffix when it has 17 letters', () {
      expect(
        failureOf(HouseNumber.create(3, suffix: 'a' * 17)),
        HouseNumberFailure.suffixTooLong,
      );
    });

    test('should allow numbers up to 99999 and suffixes up to 16', () {
      expect(HouseNumber.maxNumber, 99999);
      expect(HouseNumber.maxSuffixLength, 16);
    });
  });

  group('plain', () {
    test('should make the number without suffix when given an integer', () {
      final number = HouseNumber.plain(57);

      expect(number.number, 57);
      expect(number.suffix, isNull);
      expect(number, _n('57'));
    });

    test('should accept 0 and the largest number', () {
      expect(HouseNumber.plain(0).number, 0);
      expect(HouseNumber.plain(99999).number, 99999);
    });

    test('should throw when the number is below 0', () {
      expect(() => HouseNumber.plain(-1), throwsRangeError);
    });

    test('should throw when the number is above the largest one', () {
      expect(() => HouseNumber.plain(100000), throwsRangeError);
    });
  });

  group('label', () {
    test('should read back as the same number when parsed again', () {
      for (final text in ['0', '12', '12bis', '9decies', '3A', '5B2']) {
        final houseNumber = _n(text);

        expect(_n(houseNumber.label), houseNumber, reason: text);
      }
    });

    test('should show the label when printed', () {
      expect(_n('12 bis').toString(), 'HouseNumber(12bis)');
    });
  });

  group('odd and even', () {
    test('should be even when the number is zero', () {
      expect(_n('0').isEven, isTrue);
      expect(_n('0').isOdd, isFalse);
    });

    test('should be odd when the number is 1', () {
      expect(_n('1').isOdd, isTrue);
      expect(_n('1').isEven, isFalse);
    });

    test('should be even when the number is 2', () {
      expect(_n('2').isEven, isTrue);
      expect(_n('2').isOdd, isFalse);
    });

    test('should follow the integer part when there is a suffix', () {
      expect(_n('3bis').isOdd, isTrue);
      expect(_n('12A').isEven, isTrue);
    });
  });

  group('equality', () {
    test('should be equal when written differently', () {
      final a = _n('12bis');
      final b = _n(' 12 BIS ');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should be equal when parsed and when built from parts', () {
      expect(_n('3A'), valueOf(HouseNumber.create(3, suffix: 'a')));
    });

    test('should differ when the numbers differ', () {
      expect(_n('12'), isNot(_n('13')));
    });

    test('should differ when only one has a suffix', () {
      expect(_n('12'), isNot(_n('12A')));
    });

    test('should differ when the suffixes differ', () {
      expect(_n('12bis'), isNot(_n('12ter')));
    });

    test('should differ from its label', () {
      expect(_n('12'), isNot('12'));
    });
  });

  group('ordering', () {
    List<String> sorted(List<String> texts) =>
        (texts.map(_n).toList()..sort()).map((n) => n.label).toList();

    test('should sort the French way when the street is shuffled', () {
      expect(sorted(['4', '3A', '3quater', '3', '3ter', '3bis']), [
        '3',
        '3bis',
        '3ter',
        '3quater',
        '3A',
        '4',
      ]);
    });

    test('should sort every Latin multiplicative in its order', () {
      expect(
        sorted([
          '1decies',
          '1nonies',
          '1octies',
          '1septies',
          '1sexies',
          '1quinquies',
          '1quater',
          '1ter',
          '1bis',
        ]),
        [
          '1bis',
          '1ter',
          '1quater',
          '1quinquies',
          '1sexies',
          '1septies',
          '1octies',
          '1nonies',
          '1decies',
        ],
      );
    });

    test('should sort numbers by value, not as text', () {
      expect(sorted(['10', '9', '100', '9bis']), ['9', '9bis', '10', '100']);
    });

    // Pairs (smaller, larger): each is checked in both directions, so the
    // test fails if a comparison is inverted.
    const pairs = [
      ('3', '4'),
      ('3Z', '4'),
      ('3', '3bis'),
      ('3', '3A'),
      ('3bis', '3ter'),
      ('3decies', '3A'),
      ('3bis', '3A'),
      ('3A', '3B'),
      ('3AA', '3B'),
      ('3A', '3AA'),
    ];

    for (final (smaller, larger) in pairs) {
      test('should put $smaller before $larger', () {
        expect(_n(smaller).compareTo(_n(larger)), lessThan(0));
        expect(_n(larger).compareTo(_n(smaller)), greaterThan(0));
      });
    }

    test('should compare as equal when the numbers are equal', () {
      expect(_n('12bis').compareTo(_n('12 BIS')), 0);
      expect(_n('12').compareTo(_n('12')), 0);
      expect(_n('12B').compareTo(_n('12b')), 0);
    });
  });
}
