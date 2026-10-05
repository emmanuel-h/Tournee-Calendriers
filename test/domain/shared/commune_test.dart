import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the INSEE code and the name when both are valid', () {
      final commune = valueOf(
        Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
      );

      expect(commune.inseeCode.value, '69264');
      expect(commune.name, 'Villefranche-sur-Saône');
    });

    test('should trim the code and the name when spaces surround them', () {
      final commune = valueOf(
        Commune.create(inseeCode: ' 69264 ', name: '  Villefranche-sur-Saône '),
      );

      expect(commune.inseeCode.value, '69264');
      expect(commune.name, 'Villefranche-sur-Saône');
    });

    // The INSEE code of a commune is five characters: the département (two
    // digits, or 2A / 2B in Corsica, or three digits overseas) then the
    // commune's number. Codes from the BAN are checked against that shape.
    const validCodes = <String, String>{
      '69264': '69264',
      '01001': '01001',
      '97411': '97411',
      '2A004': '2A004',
      '2b033': '2B033',
    };
    validCodes.forEach((input, expected) {
      test('should accept the code $expected when given "$input"', () {
        final commune = valueOf(Commune.create(inseeCode: input, name: 'X'));

        expect(commune.inseeCode.value, expected);
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
        expect(
          failureOf(Commune.create(inseeCode: code, name: 'X')),
          CommuneFailure.invalidInseeCode,
        );
      });
    }

    test('should refuse the name when it is blank', () {
      expect(
        failureOf(Commune.create(inseeCode: '69264', name: '  ')),
        CommuneFailure.blankName,
      );
    });
  });

  group('equality', () {
    Commune villefranche() => valueOf(
      Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
    );

    test('should be equal when the code and the name are equal', () {
      expect(villefranche(), villefranche());
      expect(villefranche().hashCode, villefranche().hashCode);
    });

    test('should differ when the codes differ', () {
      expect(
        villefranche(),
        isNot(
          valueOf(
            Commune.create(inseeCode: '69265', name: 'Villefranche-sur-Saône'),
          ),
        ),
      );
    });

    test('should differ when the names differ', () {
      expect(
        villefranche(),
        isNot(
          valueOf(Commune.create(inseeCode: '69264', name: 'Villefranche')),
        ),
      );
    });

    test('should differ from a value of another type', () {
      expect(villefranche(), isNot('69264'));
    });
  });

  test('should show its code and name when printed', () {
    final commune = valueOf(
      Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
    );

    expect(commune.toString(), 'Commune(69264, Villefranche-sur-Saône)');
  });
}
