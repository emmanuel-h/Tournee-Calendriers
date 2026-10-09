import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

void main() {
  test('should keep its value when it is not blank', () {
    expect(TourneeId('t9Kq2').value, 't9Kq2');
  });

  test('should refuse a value when it is empty', () {
    expect(() => TourneeId(''), throwsArgumentError);
  });

  test('should refuse a value when it is only spaces', () {
    expect(() => TourneeId('  '), throwsArgumentError);
  });

  group('equality', () {
    test('should be equal when the values are equal', () {
      expect(TourneeId('t1'), TourneeId('t1'));
      expect(TourneeId('t1').hashCode, TourneeId('t1').hashCode);
    });

    test('should differ when the values differ', () {
      expect(TourneeId('t1'), isNot(TourneeId('t2')));
    });
  });

  test('should show its value when printed', () {
    expect(TourneeId('t1').toString(), 'TourneeId(t1)');
  });
}
