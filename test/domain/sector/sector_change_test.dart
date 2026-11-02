import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

import 'sector_fixtures.dart';

void main() {
  // Each member change, built for a tournée and a member.
  final memberChanges = <String, MemberChange Function(SectorId, Member)>{
    'MemberAccepted': (id, member) =>
        MemberAccepted(sectorId: id, member: member),
    'MemberRefused': (id, member) =>
        MemberRefused(sectorId: id, member: member),
    'MemberRemoved': (id, member) =>
        MemberRemoved(sectorId: id, member: member),
    'MemberLeft': (id, member) => MemberLeft(sectorId: id, member: member),
    'MemberRenamed': (id, member) =>
        MemberRenamed(sectorId: id, member: member),
    'AdminJoined': (id, member) => AdminJoined(sectorId: id, member: member),
  };

  for (final MapEntry(key: kind, value: make) in memberChanges.entries) {
    group(kind, () {
      test('should keep the tournée and the member when built', () {
        final change = make(sectorId, julie);

        expect(change.sectorId, sectorId);
        expect(change.member, julie);
      });

      test('should be equal when the tournée and the member are equal', () {
        expect(make(sectorId, julie), make(SectorId('t49'), julie));
        expect(
          make(sectorId, julie).hashCode,
          make(SectorId('t49'), julie).hashCode,
        );
      });

      test('should differ when the tournée differs', () {
        expect(make(sectorId, julie), isNot(make(SectorId('t12'), julie)));
      });

      test('should differ when the member differs', () {
        expect(make(sectorId, julie), isNot(make(sectorId, lea)));
      });

      test('should show its kind, tournée and member when printed', () {
        expect(
          make(sectorId, julie).toString(),
          '$kind(t49, Member(uid-julie, Julie, pending))',
        );
      });
    });
  }

  test('should differ when two member changes are of different kinds', () {
    expect(
      MemberRemoved(sectorId: sectorId, member: lea),
      isNot(MemberLeft(sectorId: sectorId, member: lea)),
    );
    expect(
      MemberAccepted(sectorId: sectorId, member: julie),
      isNot(MemberRefused(sectorId: sectorId, member: julie)),
    );
    expect(
      MemberRenamed(sectorId: sectorId, member: lea),
      isNot(MemberAccepted(sectorId: sectorId, member: lea)),
    );
  });

  // Each commune change, built for a tournée and a commune.
  final communeChanges =
      <String, CommuneChange Function(SectorId, SectorCommune)>{
        'CommuneAdded': (id, commune) =>
            CommuneAdded(sectorId: id, commune: commune),
        'CommuneRemoved': (id, commune) =>
            CommuneRemoved(sectorId: id, commune: commune),
      };

  for (final MapEntry(key: kind, value: make) in communeChanges.entries) {
    group(kind, () {
      test('should keep the tournée and the commune when built', () {
        final change = make(sectorId, gleizeCommune);

        expect(change.sectorId, sectorId);
        expect(change.commune, gleizeCommune);
      });

      test('should be equal when the tournée and the commune are equal', () {
        expect(
          make(sectorId, gleizeCommune),
          make(SectorId('t49'), gleizeCommune),
        );
        expect(
          make(sectorId, gleizeCommune).hashCode,
          make(SectorId('t49'), gleizeCommune).hashCode,
        );
      });

      test('should differ when the tournée differs', () {
        expect(
          make(sectorId, gleizeCommune),
          isNot(make(SectorId('t12'), gleizeCommune)),
        );
      });

      test('should differ when the commune differs', () {
        expect(
          make(sectorId, gleizeCommune),
          isNot(make(sectorId, villefrancheCommune)),
        );
      });

      test('should show its kind, tournée and commune when printed', () {
        expect(
          make(sectorId, gleizeCommune).toString(),
          '$kind(t49, SectorCommune(69092, Gleizé, GeoPoint(45.9915, 4.6883)))',
        );
      });
    });
  }

  test('should differ when two commune changes are of different kinds', () {
    expect(
      CommuneAdded(sectorId: sectorId, commune: gleizeCommune),
      isNot(CommuneRemoved(sectorId: sectorId, commune: gleizeCommune)),
    );
  });

  group('JoinCodeRegenerated', () {
    JoinCodeRegenerated regenerated({
      String id = 't49',
      String before = 'K7P2QX',
      String code = 'ABCDEF',
    }) => JoinCodeRegenerated(
      sectorId: SectorId(id),
      before: codeOf(before),
      code: codeOf(code),
    );

    test('should keep the old and the new code when built', () {
      final change = regenerated();

      expect(change.sectorId, sectorId);
      expect(change.before, codeOf('K7P2QX'));
      expect(change.code, codeOf('ABCDEF'));
    });

    test('should be equal when every field is equal', () {
      expect(regenerated(), regenerated());
      expect(regenerated().hashCode, regenerated().hashCode);
    });

    test('should differ when the tournée differs', () {
      expect(regenerated(), isNot(regenerated(id: 't12')));
    });

    test('should differ when the old code differs', () {
      expect(regenerated(), isNot(regenerated(before: 'K7P2QY')));
    });

    test('should differ when the new code differs', () {
      expect(regenerated(), isNot(regenerated(code: 'ABCDEG')));
    });

    test('should show both codes when printed', () {
      expect(
        regenerated().toString(),
        'JoinCodeRegenerated(t49, K7P-2QX → ABC-DEF)',
      );
    });
  });

  group('SectorDeleted', () {
    test('should keep the tournée as it was when built', () {
      final sector = team();

      expect(SectorDeleted(sector).sector, same(sector));
    });

    test('should show the tournée id when printed', () {
      expect(SectorDeleted(team()).toString(), 'SectorDeleted(t49)');
    });
  });
}
