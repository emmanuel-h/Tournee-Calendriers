import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

void main() {
  test('should keep its value when it is not blank', () {
    expect(SectorId('t9Kq2').value, 't9Kq2');
  });

  test('should refuse a value when it is empty', () {
    expect(() => SectorId(''), throwsArgumentError);
  });

  test('should refuse a value when it is only spaces', () {
    expect(() => SectorId('  '), throwsArgumentError);
  });

  group('equality', () {
    test('should be equal when the values are equal', () {
      expect(SectorId('t1'), SectorId('t1'));
      expect(SectorId('t1').hashCode, SectorId('t1').hashCode);
    });

    test('should differ when the values differ', () {
      expect(SectorId('t1'), isNot(SectorId('t2')));
    });
  });

  test('should show its value when printed', () {
    expect(SectorId('t1').toString(), 'SectorId(t1)');
  });
}
