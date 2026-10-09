import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the number when it is a tournée number', () {
      expect(valueOf(TourneeNumber.create(49)).value, 49);
    });

    test('should refuse the number when it is 0', () {
      expect(
        failureOf(TourneeNumber.create(0)),
        TourneeNumberFailure.outOfRange,
      );
    });

    test('should accept the first number when it is 1', () {
      expect(valueOf(TourneeNumber.create(1)).value, 1);
    });

    test('should accept the last number when it is 9999', () {
      expect(valueOf(TourneeNumber.create(9999)).value, 9999);
    });

    test('should refuse the number when it is 10000', () {
      expect(
        failureOf(TourneeNumber.create(10000)),
        TourneeNumberFailure.outOfRange,
      );
    });
  });

  group('parse', () {
    test('should read the number when it is typed with spaces around', () {
      expect(valueOf(TourneeNumber.parse(' 49 ')).value, 49);
    });

    test('should ignore leading zeros when the number has some', () {
      expect(valueOf(TourneeNumber.parse('049')).value, 49);
    });

    test('should refuse the text when it is not only digits', () {
      for (final typed in ['', ' ', '49a', '+49', '-49', '4 9', '4.9']) {
        expect(
          failureOf(TourneeNumber.parse(typed)),
          TourneeNumberFailure.notANumber,
          reason: typed,
        );
      }
    });

    test('should refuse the number when the digits are out of range', () {
      expect(
        failureOf(TourneeNumber.parse('000')),
        TourneeNumberFailure.outOfRange,
      );
    });

    test('should refuse the number when the digits are too many to read', () {
      expect(
        failureOf(TourneeNumber.parse('9' * 30)),
        TourneeNumberFailure.outOfRange,
      );
    });
  });

  group('equality', () {
    test('should be equal when the numbers are equal', () {
      final typed = valueOf(TourneeNumber.parse('049'));
      final stored = valueOf(TourneeNumber.create(49));

      expect(typed, stored);
      expect(typed.hashCode, stored.hashCode);
    });

    test('should differ when the numbers differ', () {
      expect(
        valueOf(TourneeNumber.create(49)),
        isNot(valueOf(TourneeNumber.create(50))),
      );
    });
  });

  test('should show its number when printed', () {
    expect(valueOf(TourneeNumber.create(49)).toString(), 'TourneeNumber(49)');
  });
}
