import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

import 'tournee_fixtures.dart';

void main() {
  // Each member change, built for a tournée and a member.
  final memberChanges = <String, MemberChange Function(TourneeId, Member)>{
    'MemberAccepted': (id, member) =>
        MemberAccepted(tourneeId: id, member: member),
    'MemberRefused': (id, member) =>
        MemberRefused(tourneeId: id, member: member),
    'MemberRemoved': (id, member) =>
        MemberRemoved(tourneeId: id, member: member),
    'MemberLeft': (id, member) => MemberLeft(tourneeId: id, member: member),
  };

  for (final MapEntry(key: kind, value: make) in memberChanges.entries) {
    group(kind, () {
      test('should keep the tournée and the member when built', () {
        final change = make(tourneeId, julie);

        expect(change.tourneeId, tourneeId);
        expect(change.member, julie);
      });

      test('should be equal when the tournée and the member are equal', () {
        expect(make(tourneeId, julie), make(TourneeId('t49'), julie));
        expect(
          make(tourneeId, julie).hashCode,
          make(TourneeId('t49'), julie).hashCode,
        );
      });

      test('should differ when the tournée differs', () {
        expect(make(tourneeId, julie), isNot(make(TourneeId('t12'), julie)));
      });

      test('should differ when the member differs', () {
        expect(make(tourneeId, julie), isNot(make(tourneeId, lea)));
      });

      test('should show its kind, tournée and member when printed', () {
        expect(
          make(tourneeId, julie).toString(),
          '$kind(t49, Member(uid-julie, Julie, pending))',
        );
      });
    });
  }

  test('should differ when two member changes are of different kinds', () {
    expect(
      MemberRemoved(tourneeId: tourneeId, member: lea),
      isNot(MemberLeft(tourneeId: tourneeId, member: lea)),
    );
    expect(
      MemberAccepted(tourneeId: tourneeId, member: julie),
      isNot(MemberRefused(tourneeId: tourneeId, member: julie)),
    );
  });

  group('JoinCodeRegenerated', () {
    JoinCodeRegenerated regenerated({
      String id = 't49',
      String before = 'K7P2QX',
      String code = 'ABCDEF',
    }) => JoinCodeRegenerated(
      tourneeId: TourneeId(id),
      before: codeOf(before),
      code: codeOf(code),
    );

    test('should keep the old and the new code when built', () {
      final change = regenerated();

      expect(change.tourneeId, tourneeId);
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

  group('TourneeDeleted', () {
    test('should keep the tournée as it was when built', () {
      final tournee = team();

      expect(TourneeDeleted(tournee).tournee, same(tournee));
    });

    test('should show the tournée id when printed', () {
      expect(TourneeDeleted(team()).toString(), 'TourneeDeleted(t49)');
    });
  });
}
