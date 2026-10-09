import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';

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
