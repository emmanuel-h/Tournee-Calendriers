import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the hint when it is short', () {
      final comeBack = valueOf(ComeBack.create('après 19h'));

      expect(comeBack.hint, 'après 19h');
    });

    test('should trim spaces around the hint', () {
      final comeBack = valueOf(ComeBack.create('  le samedi \n'));

      expect(comeBack.hint, 'le samedi');
    });

    test('should have no hint when the hint is blank', () {
      final comeBack = valueOf(ComeBack.create('   '));

      expect(comeBack.hint, '');
      expect(comeBack, ComeBack.withoutHint);
    });

    test('should accept the hint when it has 49 characters', () {
      expect(valueOf(ComeBack.create('a' * 49)).hint, 'a' * 49);
    });

    test('should accept the hint when it has exactly 50 characters', () {
      expect(valueOf(ComeBack.create('a' * 50)).hint, 'a' * 50);
    });

    test('should refuse the hint when it has 51 characters', () {
      expect(failureOf(ComeBack.create('a' * 51)), ComeBackFailure.hintTooLong);
    });

    test('should count the limit after trimming when spaces surround it', () {
      expect(valueOf(ComeBack.create('  ${'a' * 50}  ')).hint, 'a' * 50);
    });

    test('should count an emoji as one character', () {
      final hint = '🔔' * 50;

      expect(valueOf(ComeBack.create(hint)).hint, hint);
    });
  });

  test('should allow hints of 50 characters', () {
    expect(ComeBack.maxHintLength, 50);
  });

  test('should hold an empty hint when it is the come-back without hint', () {
    expect(ComeBack.withoutHint.hint, '');
  });

  group('keptBy', () {
    final evening = valueOf(ComeBack.create('après 19h'));

    test('should keep the hint of a door « repasser »', () {
      expect(ComeBack.keptBy(VisitStatus.comeBack, evening), evening);
    });

    test('should come back without hint when « repasser » has none', () {
      expect(ComeBack.keptBy(VisitStatus.comeBack, null), ComeBack.withoutHint);
    });

    for (final status in [
      VisitStatus.toDo,
      VisitStatus.done,
      VisitStatus.nobodyHome,
    ]) {
      test('should keep nothing when the door is $status', () {
        expect(ComeBack.keptBy(status, evening), isNull);
      });
    }
  });

  group('equality', () {
    test('should be equal when the hints are equal', () {
      final a = valueOf(ComeBack.create('après 19h'));
      final b = valueOf(ComeBack.create(' après 19h'));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the hints differ', () {
      expect(
        valueOf(ComeBack.create('après 19h')),
        isNot(valueOf(ComeBack.create('après 20h'))),
      );
    });

    test('should differ from a value of another type with the same hint', () {
      expect(valueOf(ComeBack.create('après 19h')), isNot('après 19h'));
    });
  });

  test('should show its hint when printed', () {
    expect(
      valueOf(ComeBack.create('après 19h')).toString(),
      'ComeBack(après 19h)',
    );
  });
}
