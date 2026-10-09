import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';

import 'tournee_fixtures.dart';

void main() {
  final requestedAt = DateTime.utc(2026, 11, 2, 8, 12);
  final acceptance = ChangeStamp(
    by: MemberId('uid-manu'),
    at: DateTime.utc(2026, 11, 2, 8, 14),
  );

  test('should be pending when nobody has accepted it', () {
    final julie = Member(
      id: MemberId('uid-julie'),
      name: nameOf('Julie'),
      requestedAt: requestedAt,
    );

    expect(julie.id, MemberId('uid-julie'));
    expect(julie.name, nameOf('Julie'));
    expect(julie.requestedAt, requestedAt);
    expect(julie.acceptance, isNull);
    expect(julie.status, MemberStatus.pending);
    expect(julie.isActive, isFalse);
  });

  test('should be active when someone has accepted it', () {
    final julie = Member(
      id: MemberId('uid-julie'),
      name: nameOf('Julie'),
      requestedAt: requestedAt,
      acceptance: acceptance,
    );

    expect(julie.acceptance, acceptance);
    expect(julie.status, MemberStatus.active);
    expect(julie.isActive, isTrue);
  });

  group('equality', () {
    Member julie({
      String id = 'uid-julie',
      String name = 'Julie',
      DateTime? at,
      ChangeStamp? accepted,
    }) => Member(
      id: MemberId(id),
      name: nameOf(name),
      requestedAt: at ?? requestedAt,
      acceptance: accepted,
    );

    test('should be equal when every field is equal', () {
      expect(julie(accepted: acceptance), julie(accepted: acceptance));
      expect(
        julie(accepted: acceptance).hashCode,
        julie(accepted: acceptance).hashCode,
      );
    });

    test('should differ when the id differs', () {
      expect(julie(), isNot(julie(id: 'uid-other')));
    });

    test('should differ when the name differs', () {
      expect(julie(), isNot(julie(name: 'Léa')));
    });

    test('should differ when the request time differs', () {
      expect(julie(), isNot(julie(at: DateTime.utc(2026, 11, 3))));
    });

    test('should differ when one is accepted and the other is not', () {
      expect(julie(), isNot(julie(accepted: acceptance)));
    });
  });

  test('should show its id, name and status when printed', () {
    final julie = Member(
      id: MemberId('uid-julie'),
      name: nameOf('Julie'),
      requestedAt: requestedAt,
    );

    expect(julie.toString(), 'Member(uid-julie, Julie, pending)');
  });
}
