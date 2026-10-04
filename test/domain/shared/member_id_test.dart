import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

void main() {
  test('should keep its value when it is not blank', () {
    expect(MemberId('local-7f3a').value, 'local-7f3a');
  });

  test('should refuse a value when it is empty', () {
    expect(() => MemberId(''), throwsArgumentError);
  });

  test('should refuse a value when it is only spaces', () {
    expect(() => MemberId('  '), throwsArgumentError);
  });

  group('equality', () {
    test('should be equal when the values are equal', () {
      expect(MemberId('a1'), MemberId('a1'));
      expect(MemberId('a1').hashCode, MemberId('a1').hashCode);
    });

    test('should differ when the values differ', () {
      expect(MemberId('a1'), isNot(MemberId('a2')));
    });

    test('should differ from a value of another type with the same text', () {
      expect(MemberId('a1'), isNot('a1'));
    });
  });

  test('should show its value when printed', () {
    expect(MemberId('a1').toString(), 'MemberId(a1)');
  });
}
