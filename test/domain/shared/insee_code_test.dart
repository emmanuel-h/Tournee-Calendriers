import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';

import '../../support/results.dart';

void main() {
  group('parse', () {
    // The INSEE code of a commune is five characters: the département (two
    // digits, or 2A / 2B in Corsica, or three digits overseas) then the
    // commune's number.
    const validCodes = <String, String>{
      '69264': '69264',
      ' 69264 ': '69264',
      '01001': '01001',
      '97411': '97411',
      '2A004': '2A004',
      '2b033': '2B033',
    };
    validCodes.forEach((input, expected) {
      test('should read $expected when given "$input"', () {
        expect(valueOf(InseeCode.parse(input)).value, expected);
      });
    });

    const invalidCodes = [
      '',
      '6926',
      '692640',
      '6926A',
      '2C004',
      'AB264',
      '69 264',
    ];
    for (final code in invalidCodes) {
      test('should refuse the code when given "$code"', () {
        expect(failureOf(InseeCode.parse(code)), InseeCodeFailure.badShape);
      });
    }
  });

  group('equality', () {
    test('should be equal when the codes read the same', () {
      expect(
        valueOf(InseeCode.parse('2a004')),
        valueOf(InseeCode.parse('2A004')),
      );
      expect(
        valueOf(InseeCode.parse('2a004')).hashCode,
        valueOf(InseeCode.parse('2A004')).hashCode,
      );
    });

    test('should differ when the codes differ', () {
      expect(
        valueOf(InseeCode.parse('69264')),
        isNot(valueOf(InseeCode.parse('69123'))),
      );
    });
  });

  test('should show the code when printed', () {
    expect(valueOf(InseeCode.parse('69264')).toString(), 'InseeCode(69264)');
  });
}
