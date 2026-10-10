import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

void main() {
  final lea = MemberId('lea');
  final paul = MemberId('paul');
  final twoPm = DateTime.utc(2026, 11, 2, 14, 2);
  final threePm = DateTime.utc(2026, 11, 2, 15);

  test('should keep who made the change and when', () {
    final stamp = ChangeStamp(by: lea, at: twoPm);

    expect(stamp.by, lea);
    expect(stamp.at, twoPm);
  });

  test('should name another member and keep the time when restamped', () {
    final stamp = ChangeStamp(by: lea, at: twoPm).restampedBy(paul);

    expect(stamp.by, paul);
    expect(stamp.at, twoPm);
  });

  group('equality', () {
    test('should be equal when the member and the time are equal', () {
      final a = ChangeStamp(by: lea, at: twoPm);
      final b = ChangeStamp(
        by: MemberId('lea'),
        at: DateTime.utc(2026, 11, 2, 14, 2),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the members differ', () {
      expect(
        ChangeStamp(by: lea, at: twoPm),
        isNot(ChangeStamp(by: paul, at: twoPm)),
      );
    });

    test('should differ when the times differ', () {
      expect(
        ChangeStamp(by: lea, at: twoPm),
        isNot(ChangeStamp(by: lea, at: threePm)),
      );
    });

    test('should differ from a value of another type', () {
      expect(ChangeStamp(by: lea, at: twoPm), isNot(twoPm));
    });
  });

  test('should show the member and the time when printed', () {
    expect(
      ChangeStamp(by: lea, at: twoPm).toString(),
      'ChangeStamp(lea, 2026-11-02 14:02:00.000Z)',
    );
  });
}
