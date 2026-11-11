import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the number when it is a secteur number', () {
      expect(valueOf(SectorNumber.create(49)).value, 49);
    });

    test('should refuse the number when it is 0', () {
      expect(failureOf(SectorNumber.create(0)), SectorNumberFailure.outOfRange);
    });

    test('should accept the first number when it is 1', () {
      expect(valueOf(SectorNumber.create(1)).value, 1);
    });

    test('should accept the last number when it is 9999', () {
      expect(valueOf(SectorNumber.create(9999)).value, 9999);
    });

    test('should refuse the number when it is 10000', () {
      expect(
        failureOf(SectorNumber.create(10000)),
        SectorNumberFailure.outOfRange,
      );
    });
  });

  group('parse', () {
    test('should read the number when it is typed with spaces around', () {
      expect(valueOf(SectorNumber.parse(' 49 ')).value, 49);
    });

    test('should ignore leading zeros when the number has some', () {
      expect(valueOf(SectorNumber.parse('049')).value, 49);
    });

    test('should refuse the text when it is not only digits', () {
      for (final typed in ['', ' ', '49a', '+49', '-49', '4 9', '4.9']) {
        expect(
          failureOf(SectorNumber.parse(typed)),
          SectorNumberFailure.notANumber,
          reason: typed,
        );
      }
    });

    test('should refuse the number when the digits are out of range', () {
      expect(
        failureOf(SectorNumber.parse('000')),
        SectorNumberFailure.outOfRange,
      );
    });

    test('should refuse the number when the digits are too many to read', () {
      expect(
        failureOf(SectorNumber.parse('9' * 30)),
        SectorNumberFailure.outOfRange,
      );
    });
  });

  group('equality', () {
    test('should be equal when the numbers are equal', () {
      final typed = valueOf(SectorNumber.parse('049'));
      final stored = valueOf(SectorNumber.create(49));

      expect(typed, stored);
      expect(typed.hashCode, stored.hashCode);
    });

    test('should differ when the numbers differ', () {
      expect(
        valueOf(SectorNumber.create(49)),
        isNot(valueOf(SectorNumber.create(50))),
      );
    });
  });

  test('should show its number when printed', () {
    expect(valueOf(SectorNumber.create(49)).toString(), 'SectorNumber(49)');
  });
}
