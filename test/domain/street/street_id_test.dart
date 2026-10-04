import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

void main() {
  group('StreetId', () {
    test('should keep its value when it is not blank', () {
      expect(StreetId('s-42').value, 's-42');
    });

    test('should refuse a value when it is blank', () {
      expect(() => StreetId(' '), throwsArgumentError);
    });

    test('should be equal when the values are equal', () {
      expect(StreetId('s-42'), StreetId('s-42'));
      expect(StreetId('s-42').hashCode, StreetId('s-42').hashCode);
    });

    test('should differ when the values differ', () {
      expect(StreetId('s-42'), isNot(StreetId('s-43')));
    });

    test('should differ from a BAN id with the same value', () {
      expect(StreetId('69264_0420'), isNot(BanStreetId('69264_0420')));
    });

    test('should show its value when printed', () {
      expect(StreetId('s-42').toString(), 'StreetId(s-42)');
    });
  });

  group('BanStreetId', () {
    test('should keep its value when it is not blank', () {
      expect(BanStreetId('69264_0420').value, '69264_0420');
    });

    test('should refuse a value when it is blank', () {
      expect(() => BanStreetId(''), throwsArgumentError);
    });

    test('should be equal when the values are equal', () {
      expect(BanStreetId('69264_0420'), BanStreetId('69264_0420'));
      expect(
        BanStreetId('69264_0420').hashCode,
        BanStreetId('69264_0420').hashCode,
      );
    });

    test('should differ when the values differ', () {
      expect(BanStreetId('69264_0420'), isNot(BanStreetId('69264_0421')));
    });

    test('should differ from a street id with the same value', () {
      expect(BanStreetId('69264_0420'), isNot(StreetId('69264_0420')));
    });

    test('should show its value when printed', () {
      expect(BanStreetId('69264_0420').toString(), 'BanStreetId(69264_0420)');
    });
  });
}
