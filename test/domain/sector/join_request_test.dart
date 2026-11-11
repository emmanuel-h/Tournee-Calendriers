import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/join_request.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

import 'sector_fixtures.dart';

void main() {
  JoinRequest request({
    String sector = 't49',
    String code = 'K7P-2QX',
    String by = 'uid-julie',
    String name = 'Julie',
    DateTime? at,
  }) => JoinRequest(
    sector: SectorId(sector),
    code: codeOf(code),
    by: MemberId(by),
    name: nameOf(name),
    at: at ?? julieAskedAt,
  );

  test('should ask for the secteur with the code it was made with', () {
    final asked = request();

    expect(asked.sector, sectorId);
    expect(asked.code, firstCode);
  });

  test('should make the newcomer a pending member asking at that time', () {
    final asked = request();

    expect(asked, julieRequest);
    expect(asked.member, julie);
    expect(asked.member.id, julieId);
    expect(asked.member.name, nameOf('Julie'));
    expect(asked.member.requestedAt, julieAskedAt);
    expect(asked.member.acceptance, isNull);
    expect(asked.member.status, MemberStatus.pending);
  });

  group('equality', () {
    test('should be equal when every field is equal', () {
      expect(request(), request());
      expect(request().hashCode, request().hashCode);
    });

    test('should differ when the secteur differs', () {
      expect(request(), isNot(request(sector: 't12')));
    });

    test('should differ when the code differs', () {
      expect(request(), isNot(request(code: '234-567')));
    });

    test('should differ when the newcomer differs', () {
      expect(request(), isNot(request(by: 'uid-paul')));
    });

    test('should differ when the name differs', () {
      expect(request(), isNot(request(name: 'Jules')));
    });

    test('should differ when the time differs', () {
      expect(request(), isNot(request(at: DateTime.utc(2026, 11, 3))));
    });

    test('should not equal its member', () {
      expect(request(), isNot(julie));
    });
  });

  test('should name the secteur, the code and the newcomer', () {
    expect(request().toString(), 'JoinRequest(t49, K7P-2QX, uid-julie)');
  });
}
