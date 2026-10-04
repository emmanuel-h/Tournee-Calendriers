// The typed lists and ranges of house numbers: the « Ajouter des numéros »
// sheet and the manual street form (PLAN §5.5).
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';

import '../../support/results.dart';

/// The labels [text] expands to, or a test failure.
List<String> _labels(String text) => [
  for (final number in valueOf(parseHouseNumbers(text))) number.label,
];

/// The labels the manual form expands to, or a test failure.
List<String> _manual({
  String from = '',
  String to = '',
  Sides sides = Sides.both,
  String extras = '',
}) => [
  for (final number in valueOf(
    manualStreetNumbers(from: from, to: to, sides: sides, extras: extras),
  ))
    number.label,
];

/// The failure of the manual form, or a test failure.
NumbersFailure _manualFailure({
  String from = '',
  String to = '',
  Sides sides = Sides.both,
  String extras = '',
}) => failureOf(
  manualStreetNumbers(from: from, to: to, sides: sides, extras: extras),
);

/// `'1'` … `'n'`, as labels.
List<String> _upTo(int count) => [for (var i = 1; i <= count; i++) '$i'];

void main() {
  group('Sides', () {
    test('should include every number when both sides are asked', () {
      expect(Sides.both.includes(3), isTrue);
      expect(Sides.both.includes(4), isTrue);
    });

    test('should include only odd numbers when the odd side is asked', () {
      expect(Sides.odd.includes(3), isTrue);
      expect(Sides.odd.includes(4), isFalse);
    });

    test('should include only even numbers, 0 too, when the even side is '
        'asked', () {
      expect(Sides.even.includes(4), isTrue);
      expect(Sides.even.includes(0), isTrue);
      expect(Sides.even.includes(3), isFalse);
    });
  });

  group('parseHouseNumbers', () {
    test('should read one number when given one', () {
      expect(_labels('12'), ['12']);
    });

    test('should read a number with its suffix as HouseNumber does', () {
      expect(_labels('12 BIS'), ['12bis']);
    });

    test('should read a list separated by commas', () {
      expect(_labels('3,5,7'), ['3', '5', '7']);
    });

    test('should read a list separated by semicolons or line breaks', () {
      expect(_labels('3;5\n7'), ['3', '5', '7']);
    });

    test('should ignore spaces around each item', () {
      expect(_labels('  3 ,  14ter  '), ['3', '14ter']);
    });

    test('should ignore empty items between and after separators', () {
      expect(_labels('3,, 5,'), ['3', '5']);
    });

    test('should expand a range to every number of both sides', () {
      expect(_labels('21-25'), ['21', '22', '23', '24', '25']);
    });

    test('should expand the Numbers mockup example to six numbers', () {
      expect(_labels('12bis, 21-25'), ['12bis', '21', '22', '23', '24', '25']);
    });

    test('should accept spaces around the dash of a range', () {
      expect(_labels('21 - 23'), ['21', '22', '23']);
    });

    test('should accept an en dash in a range, as phones sometimes type', () {
      expect(_labels('21–23'), ['21', '22', '23']);
    });

    test('should expand a range typed backwards the same way', () {
      expect(_labels('25-23'), ['23', '24', '25']);
    });

    test('should expand a range of one number to that number', () {
      expect(_labels('7-7'), ['7']);
    });

    test('should expand a range starting at 0', () {
      expect(_labels('0-2'), ['0', '1', '2']);
    });

    test('should accept a range ending at the largest number', () {
      expect(_labels('99998-99999'), ['99998', '99999']);
    });

    test('should sort the numbers in street order', () {
      expect(_labels('14, 3bis, 3, 12bis, 12'), [
        '3',
        '3bis',
        '12',
        '12bis',
        '14',
      ]);
    });

    test('should keep each number once when given twice', () {
      expect(_labels('12, 10-13, 12 BIS, 12bis'), [
        '10',
        '11',
        '12',
        '12bis',
        '13',
      ]);
    });

    test('should give no number when the text is blank', () {
      expect(_labels(' '), isEmpty);
    });

    test('should give no number when there are only separators', () {
      expect(_labels(' , ;'), isEmpty);
    });

    group('fails', () {
      test('should name the item and the reason when an item is not a '
          'number', () {
        expect(
          failureOf(parseHouseNumbers('12, bis, 14')),
          const InvalidNumber('bis', HouseNumberFailure.malformed),
        );
      });

      test('should name the first wrong item when several are wrong', () {
        expect(
          failureOf(parseHouseNumbers('12 3, 12é')),
          const InvalidNumber('12 3', HouseNumberFailure.invalidSuffix),
        );
      });

      test('should name a number above the largest one', () {
        expect(
          failureOf(parseHouseNumbers('100000')),
          const InvalidNumber('100000', HouseNumberFailure.numberTooLarge),
        );
      });

      test('should name a range with a suffix', () {
        expect(
          failureOf(parseHouseNumbers('12bis-14')),
          const InvalidRange('12bis-14'),
        );
      });

      test('should name a range missing its end', () {
        expect(failureOf(parseHouseNumbers('21-')), const InvalidRange('21-'));
      });

      test('should name a range missing its start', () {
        expect(failureOf(parseHouseNumbers('-3')), const InvalidRange('-3'));
      });

      test('should name a range of three numbers', () {
        expect(
          failureOf(parseHouseNumbers('1-2-3')),
          const InvalidRange('1-2-3'),
        );
      });

      test('should name a range going past the largest number', () {
        expect(
          failureOf(parseHouseNumbers('99999-100000')),
          const InvalidRange('99999-100000'),
        );
      });

      test('should name a range with more digits than a number holds', () {
        const token = '1-99999999999999999999';

        expect(failureOf(parseHouseNumbers(token)), const InvalidRange(token));
      });
    });

    group('limit', () {
      test('should accept a range of 499 numbers', () {
        expect(_labels('1-499'), _upTo(499));
      });

      test('should accept a range of exactly 500 numbers', () {
        expect(_labels('1-500'), _upTo(500));
      });

      test('should refuse a range of 501 numbers', () {
        expect(failureOf(parseHouseNumbers('1-501')), const TooManyNumbers());
      });

      test('should refuse a typo range without expanding it', () {
        expect(failureOf(parseHouseNumbers('1-99999')), const TooManyNumbers());
      });

      test('should accept 499 numbers and one more item', () {
        expect(_labels('1-499, 12bis'), [
          ..._upTo(12),
          '12bis',
          ...[for (var i = 13; i <= 499; i++) '$i'],
        ]);
      });

      test('should refuse 500 numbers and one more item', () {
        expect(
          failureOf(parseHouseNumbers('1-500, 12bis')),
          const TooManyNumbers(),
        );
      });

      test('should refuse two ranges that make 501 numbers together', () {
        expect(
          failureOf(parseHouseNumbers('1-250, 251-501')),
          const TooManyNumbers(),
        );
      });

      test('should count each number once against the limit', () {
        expect(_labels('1-500, 1-500, 250'), _upTo(500));
      });

      test('should say the limit is 500 numbers', () {
        expect(maxNumbersAtOnce, 500);
      });
    });
  });

  group('manualStreetNumbers', () {
    test('should give every number from the first to the last for both '
        'sides', () {
      expect(_manual(from: '1', to: '5'), ['1', '2', '3', '4', '5']);
    });

    test('should give the odd numbers only when the odd side is chosen', () {
      expect(_manual(from: '1', to: '7', sides: Sides.odd), [
        '1',
        '3',
        '5',
        '7',
      ]);
    });

    test('should start at the next odd number when the first is even', () {
      expect(_manual(from: '2', to: '7', sides: Sides.odd), ['3', '5', '7']);
    });

    test('should give the even numbers only when the even side is chosen', () {
      expect(_manual(from: '2', to: '8', sides: Sides.even), [
        '2',
        '4',
        '6',
        '8',
      ]);
    });

    test('should start at the next even number when the first is odd', () {
      expect(_manual(from: '1', to: '6', sides: Sides.even), ['2', '4', '6']);
    });

    test('should include 0 on the even side', () {
      expect(_manual(from: '0', to: '4', sides: Sides.even), ['0', '2', '4']);
    });

    test('should give nothing when one number is not on the chosen side', () {
      expect(_manual(from: '3', to: '3', sides: Sides.even), isEmpty);
    });

    test('should give 59 numbers for the Manual mockup', () {
      final labels = _manual(from: '1', to: '57', extras: '12bis, 14ter');

      expect(labels.length, 59);
      expect(labels.sublist(10, 15), ['11', '12', '12bis', '13', '14']);
      expect(labels.sublist(15, 17), ['14ter', '15']);
    });

    test('should keep the extras whatever the side chosen', () {
      expect(_manual(from: '1', to: '5', sides: Sides.odd, extras: '4, 6'), [
        '1',
        '3',
        '4',
        '5',
        '6',
      ]);
    });

    test('should swap the numbers when the first is above the last', () {
      expect(_manual(from: '5', to: '3'), ['3', '4', '5']);
    });

    test('should take the first number alone when the last is blank', () {
      expect(_manual(from: '7', to: ' '), ['7']);
    });

    test('should take the last number alone when the first is blank', () {
      expect(_manual(from: '', to: '9'), ['9']);
    });

    test('should give the extras only when both numbers are blank', () {
      expect(_manual(extras: '14ter, 2'), ['2', '14ter']);
    });

    test('should give nothing when every field is blank', () {
      expect(_manual(), isEmpty);
    });

    test('should ignore spaces and leading zeros in the numbers', () {
      expect(_manual(from: ' 01 ', to: '03 '), ['1', '2', '3']);
    });

    test('should keep each number once when an extra is in the range', () {
      expect(_manual(from: '1', to: '3', extras: '2, 2bis'), [
        '1',
        '2',
        '2bis',
        '3',
      ]);
    });

    group('fails', () {
      test('should name the first field when it is not a plain number', () {
        expect(
          _manualFailure(from: '12bis', to: '20'),
          const InvalidBound(Bound.from, '12bis'),
        );
      });

      test('should name the last field when it is not a plain number', () {
        expect(
          _manualFailure(from: '1', to: ' vingt '),
          const InvalidBound(Bound.to, 'vingt'),
        );
      });

      test('should refuse a negative number in a field', () {
        expect(
          _manualFailure(from: '-1'),
          const InvalidBound(Bound.from, '-1'),
        );
      });

      test('should accept the largest number in a field', () {
        expect(_manual(from: '99999'), ['99999']);
      });

      test('should refuse a number above the largest one in a field', () {
        expect(
          _manualFailure(to: '100000'),
          const InvalidBound(Bound.to, '100000'),
        );
      });

      test('should refuse a field with more digits than a number holds', () {
        const digits = '99999999999999999999';

        expect(
          _manualFailure(from: digits),
          const InvalidBound(Bound.from, digits),
        );
      });

      test('should name the wrong extra when an extra is not a number', () {
        expect(
          _manualFailure(from: '1', to: '3', extras: '12bis, ?'),
          const InvalidNumber('?', HouseNumberFailure.malformed),
        );
      });

      test('should accept 500 numbers on one side', () {
        expect(_manual(from: '1', to: '999', sides: Sides.odd).length, 500);
      });

      test('should refuse 501 numbers on one side', () {
        expect(
          _manualFailure(from: '1', to: '1001', sides: Sides.odd),
          const TooManyNumbers(),
        );
      });

      test('should refuse 500 numbers and one extra', () {
        expect(
          _manualFailure(from: '1', to: '500', extras: '12bis'),
          const TooManyNumbers(),
        );
      });
    });
  });

  group('failures', () {
    test('should be equal when they name the same item and reason', () {
      const a = InvalidNumber('bis', HouseNumberFailure.malformed);
      const b = InvalidNumber('bis', HouseNumberFailure.malformed);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the items differ', () {
      expect(
        const InvalidNumber('bis', HouseNumberFailure.malformed),
        isNot(const InvalidNumber('ter', HouseNumberFailure.malformed)),
      );
    });

    test('should differ when the reasons differ', () {
      expect(
        const InvalidNumber('x', HouseNumberFailure.malformed),
        isNot(const InvalidNumber('x', HouseNumberFailure.empty)),
      );
    });

    test('should compare ranges by their item', () {
      expect(const InvalidRange('1-'), const InvalidRange('1-'));
      expect(
        const InvalidRange('1-').hashCode,
        const InvalidRange('1-').hashCode,
      );
      expect(const InvalidRange('1-'), isNot(const InvalidRange('2-')));
    });

    test('should compare bounds by field and text', () {
      const from = InvalidBound(Bound.from, 'x');

      expect(from, const InvalidBound(Bound.from, 'x'));
      expect(from.hashCode, const InvalidBound(Bound.from, 'x').hashCode);
      expect(from, isNot(const InvalidBound(Bound.to, 'x')));
      expect(from, isNot(const InvalidBound(Bound.from, 'y')));
    });

    test('should compare too many numbers with each other only', () {
      expect(const TooManyNumbers(), const TooManyNumbers());
      expect(const TooManyNumbers().hashCode, const TooManyNumbers().hashCode);
      expect(const TooManyNumbers(), isNot(const InvalidRange('1-')));
    });

    test('should differ from another kind of failure with the same item', () {
      expect(
        const InvalidRange('x'),
        isNot(const InvalidNumber('x', HouseNumberFailure.malformed)),
      );
      expect(
        const InvalidNumber('x', HouseNumberFailure.malformed),
        isNot(const InvalidRange('x')),
      );
      expect(
        const InvalidBound(Bound.from, 'x'),
        isNot(const InvalidRange('x')),
      );
    });

    test('should show what is wrong when printed', () {
      expect(
        const InvalidNumber('bis', HouseNumberFailure.malformed).toString(),
        'InvalidNumber(bis, HouseNumberFailure.malformed)',
      );
      expect(const InvalidRange('1-').toString(), 'InvalidRange(1-)');
      expect(
        const InvalidBound(Bound.to, 'x').toString(),
        'InvalidBound(Bound.to, x)',
      );
      expect(const TooManyNumbers().toString(), 'TooManyNumbers(500)');
    });
  });
}
