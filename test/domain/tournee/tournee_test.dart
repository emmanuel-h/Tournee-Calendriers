import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/actor.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';

import '../../support/results.dart';
import '../../support/scripted_random.dart';
import 'tournee_fixtures.dart';

void main() {
  group('createdBy', () {
    final number = valueOf(TourneeNumber.create(12));
    final centre = valueOf(RescueCentre.create('CIS Villefranche-sur-Saône'));
    final year = valueOf(CampaignYear.create(2027));
    final at = DateTime.utc(2026, 12, 5, 19, 30);

    Tournee created() => Tournee.createdBy(
      id: TourneeId('t12'),
      number: number,
      centre: centre,
      campaign: year,
      joinCode: codeOf('ABC-234'),
      creator: leaId,
      creatorName: nameOf('Léa'),
      at: at,
    );

    test('should keep its identity when a member creates it', () {
      final tournee = created();

      expect(tournee.id, TourneeId('t12'));
      expect(tournee.number, number);
      expect(tournee.centre, centre);
      expect(tournee.currentCampaign, year);
      expect(tournee.joinCode, codeOf('ABC234'));
      expect(tournee.createdBy, leaId);
      expect(tournee.createdAt, at);
    });

    test('should hold only its creator, active, when it is created', () {
      final tournee = created();

      expect(tournee.members, [
        Member(
          id: leaId,
          name: nameOf('Léa'),
          requestedAt: at,
          acceptance: ChangeStamp(by: leaId, at: at),
        ),
      ]);
      expect(tournee.memberOf(leaId)!.isActive, isTrue);
    });
  });

  group('create (from storage)', () {
    test('should keep every field when the members are valid', () {
      final tournee = team();

      expect(tournee.id, tourneeId);
      expect(tournee.number, number49);
      expect(tournee.centre, csVillefranche);
      expect(tournee.joinCode, firstCode);
      expect(tournee.createdBy, manuId);
      expect(tournee.createdAt, createdAt);
      expect(tournee.currentCampaign, campaign2026);
    });

    test('should sort the members by request time when they come in any '
        'order', () {
      expect(team(members: [julie, manu, lea]).members, [manu, lea, julie]);
    });

    test('should sort members by id when they asked at the same time', () {
      final early = Member(
        id: MemberId('uid-b'),
        name: nameOf('Bea'),
        requestedAt: julieAskedAt,
      );
      final late = Member(
        id: MemberId('uid-a'),
        name: nameOf('Ali'),
        requestedAt: julieAskedAt,
      );

      expect(
        team(members: [early, manu, late]).members.map((m) => m.id.value),
        ['uid-manu', 'uid-a', 'uid-b'],
      );
    });

    test('should keep a tournée whose creator left', () {
      // The creator has no power of their own any more (PLAN §5.12): they
      // may leave like anyone, and the tournée goes on.
      final tournee = valueOf(_restore([lea, julie]));

      expect(tournee.createdBy, manuId);
      expect(tournee.members, [lea, julie]);
    });

    test('should keep a tournée with no member left', () {
      // Even the last member may leave: admins manage the empty tournée.
      expect(valueOf(_restore([])).members, isEmpty);
    });

    test('should refuse the members when two share an id', () {
      final leaAgain = Member(
        id: leaId,
        name: nameOf('Léa B'),
        requestedAt: julieAskedAt,
      );

      expect(
        failureOf(_restore([manu, lea, leaAgain])),
        NewTourneeFailure.duplicateMember,
      );
    });

    test('should not let the member list be changed from outside', () {
      expect(() => team().members.add(julie), throwsUnsupportedError);
    });
  });

  group('queries', () {
    test('should list the pending requests apart when asked for them', () {
      expect(team().pendingMembers, [julie]);
    });

    test('should list the active members in order when asked for them', () {
      expect(team().activeMembers, [manu, lea]);
    });

    test('should find a member when given their id', () {
      expect(team().memberOf(leaId), lea);
    });

    test('should find nobody when the id is not in the tournée', () {
      expect(team().memberOf(paulId), isNull);
    });
  });

  group('accept', () {
    final at = DateTime.utc(2026, 11, 2, 8, 20);

    test('should make the request active, stamped, when an active member '
        'accepts it', () {
      final (tournee, change) = valueOf(
        team().accept(julieId, by: leaActing, at: at),
      );

      final accepted = Member(
        id: julieId,
        name: nameOf('Julie'),
        requestedAt: julieAskedAt,
        acceptance: ChangeStamp(by: leaId, at: at),
      );
      expect(tournee.members, [manu, lea, accepted]);
      expect(tournee.pendingMembers, isEmpty);
      expect(change.tourneeId, tourneeId);
      expect(change.member, accepted);
    });

    test('should keep the rest of the tournée when a request is accepted', () {
      final (tournee, _) = valueOf(
        team().accept(julieId, by: manuAsAdmin, at: at),
      );

      _expectSameIdentity(tournee, team());
    });

    test('should stamp the admin who is not in the tournée when they '
        'accept a request', () {
      final (_, change) = valueOf(
        team().accept(julieId, by: samAsAdmin, at: at),
      );

      expect(change.member.acceptance, ChangeStamp(by: samId, at: at));
    });

    test('should refuse when the member is unknown', () {
      expect(
        failureOf(team().accept(paulId, by: manuAsAdmin, at: at)),
        TourneeCommandFailure.unknownMember,
      );
    });

    test('should refuse when the member is already active', () {
      expect(
        failureOf(team().accept(leaId, by: manuAsAdmin, at: at)),
        TourneeCommandFailure.alreadyActive,
      );
    });
  });

  group('refuse', () {
    test('should remove the request when an active member refuses it', () {
      final (tournee, change) = valueOf(team().refuse(julieId, by: leaActing));

      expect(tournee.members, [manu, lea]);
      expect(change.tourneeId, tourneeId);
      expect(change.member, julie);
      _expectSameIdentity(tournee, team());
    });

    test('should refuse when the member is unknown', () {
      expect(
        failureOf(team().refuse(paulId, by: manuAsAdmin)),
        TourneeCommandFailure.unknownMember,
      );
    });

    test('should refuse when the member is already active', () {
      expect(
        failureOf(team().refuse(leaId, by: manuAsAdmin)),
        TourneeCommandFailure.alreadyActive,
      );
    });
  });

  group('remove', () {
    test('should cut the member out when an admin removes them', () {
      final (tournee, change) = valueOf(team().remove(leaId, by: manuAsAdmin));

      expect(tournee.members, [manu, julie]);
      expect(change.tourneeId, tourneeId);
      expect(change.member, lea);
      _expectSameIdentity(tournee, team());
    });

    test('should refuse when the member is unknown', () {
      expect(
        failureOf(team().remove(paulId, by: manuAsAdmin)),
        TourneeCommandFailure.unknownMember,
      );
    });

    test('should remove an admin, the creator too, when another admin '
        'removes them', () {
      final (tournee, change) = valueOf(team().remove(manuId, by: samAsAdmin));

      expect(tournee.members, [lea, julie]);
      expect(change.member, manu);
    });

    test('should refuse when the member is a pending request', () {
      expect(
        failureOf(team().remove(julieId, by: manuAsAdmin)),
        TourneeCommandFailure.memberPending,
      );
    });
  });

  group('leave', () {
    test('should take an active member out when they leave', () {
      final (tournee, change) = valueOf(team().leave(by: leaId));

      expect(tournee.members, [manu, julie]);
      expect(change.tourneeId, tourneeId);
      expect(change.member, lea);
      _expectSameIdentity(tournee, team());
    });

    test('should take a pending request out when its author cancels it', () {
      final (tournee, change) = valueOf(team().leave(by: julieId));

      expect(tournee.members, [manu, lea]);
      expect(change.member, julie);
    });

    test('should take the creator out when they leave', () {
      final (tournee, change) = valueOf(team().leave(by: manuId));

      expect(tournee.members, [lea, julie]);
      expect(tournee.createdBy, manuId);
      expect(change.member, manu);
    });

    test('should leave nobody when the last member leaves', () {
      final (tournee, _) = valueOf(team(members: [manu]).leave(by: manuId));

      expect(tournee.members, isEmpty);
    });
  });

  group('rename', () {
    test('should give the member their new name when they rename '
        'themself', () {
      final (tournee, change) = valueOf(
        team().rename(nameOf('Léa B.'), by: leaId),
      );

      final renamed = Member(
        id: leaId,
        name: nameOf('Léa B.'),
        requestedAt: leaAskedAt,
        acceptance: ChangeStamp(by: manuId, at: leaAcceptedAt),
      );
      expect(tournee.members, [manu, renamed, julie]);
      expect(change.tourneeId, tourneeId);
      expect(change.member, renamed);
      _expectSameIdentity(tournee, team());
    });

    test('should rename the creator too when they rename themself', () {
      final (tournee, change) = valueOf(
        team().rename(nameOf('Emmanuel'), by: manuId),
      );

      expect(tournee.memberOf(manuId)!.name, nameOf('Emmanuel'));
      expect(
        tournee.memberOf(manuId)!.acceptance,
        ChangeStamp(by: manuId, at: createdAt),
      );
      expect(change.member.name, nameOf('Emmanuel'));
      expect(tournee.members.skip(1), [lea, julie]);
    });
  });

  group('regenerateCode', () {
    test('should give a new code drawn from the source when an admin asks', () {
      // A, B, C, D, E, F: positions 0 to 5 of the alphabet.
      final random = ScriptedRandom([0, 1, 2, 3, 4, 5]);

      final (tournee, change) = valueOf(
        team().regenerateCode(by: manuAsAdmin, random: random),
      );

      expect(tournee.joinCode, codeOf('ABCDEF'));
      expect(change.tourneeId, tourneeId);
      expect(change.before, firstCode);
      expect(change.code, codeOf('ABCDEF'));
      expect(tournee.members, team().members);
      expect(tournee.id, tourneeId);
      expect(tournee.number, number49);
      expect(tournee.centre, csVillefranche);
      expect(tournee.createdBy, manuId);
      expect(tournee.createdAt, createdAt);
      expect(tournee.currentCampaign, campaign2026);
    });

    test('should draw again when the new code is the old one', () {
      // K7P2QX first (the current code), then AAAAAA.
      final random = ScriptedRandom([
        9, 28, 12, 23, 13, 20, //
        0, 0, 0, 0, 0, 0,
      ]);

      final (tournee, change) = valueOf(
        team().regenerateCode(by: manuAsAdmin, random: random),
      );

      expect(tournee.joinCode, codeOf('AAAAAA'));
      expect(change.code, codeOf('AAAAAA'));
    });
  });

  group('delete', () {
    test('should hand the whole tournée to storage when an admin deletes '
        'it', () {
      final tournee = team();

      final deleted = valueOf(tournee.delete(by: samAsAdmin));

      expect(deleted.tournee, same(tournee));
    });
  });

  group('joinAsAdmin', () {
    final at = DateTime.utc(2026, 11, 2, 10);

    test('should add the admin as an active member accepted by themself', () {
      final (tournee, change) = valueOf(
        team().joinAsAdmin(by: samAsAdmin, name: nameOf('Sam'), at: at),
      );

      final sam = Member(
        id: samId,
        name: nameOf('Sam'),
        requestedAt: at,
        acceptance: ChangeStamp(by: samId, at: at),
      );
      expect(tournee.members, [manu, lea, julie, sam]);
      expect(tournee.activeMembers, [manu, lea, sam]);
      expect(change.tourneeId, tourneeId);
      expect(change.member, sam);
      _expectSameIdentity(tournee, team());
    });
  });

  test('should show its id, number, centre and campaign when printed', () {
    expect(team().toString(), 'Tournee(t49, 49, CS Villefranche, 2026)');
  });

  group('permissions', () {
    // Who may run each command (PLAN §5.12, §6.1, §8.2): `null` means the
    // command is allowed, otherwise the failure it returns. Manu created
    // the tournée and is an admin, Léa is active, Julie is pending, Paul is
    // not in it; Sam is an admin who is not in it, and Julie is tried once
    // more as an admin whose own request still waits.
    final at = DateTime.utc(2026, 11, 2, 9);
    final commands = <String, Object? Function(Tournee, Actor)>{
      'accept a request': (t, by) => t.accept(julieId, by: by, at: at),
      'refuse a request': (t, by) => t.refuse(julieId, by: by),
      'remove Léa': (t, by) => t.remove(leaId, by: by),
      'leave': (t, by) => t.leave(by: by.member),
      'regenerate the code': (t, by) =>
          t.regenerateCode(by: by, random: ScriptedRandom([0, 0, 0, 0, 0, 0])),
      'delete the tournée': (t, by) => t.delete(by: by),
      'rename themself': (t, by) => t.rename(nameOf('Zoé'), by: by.member),
      'join as an admin': (t, by) =>
          t.joinAsAdmin(by: by, name: nameOf('Zoé'), at: at),
    };
    const TourneeCommandFailure? ok = null;
    const pending = TourneeCommandFailure.requestPending;
    const outsider = TourneeCommandFailure.notAMember;
    const notAdmin = TourneeCommandFailure.notAdmin;
    const inIt = TourneeCommandFailure.alreadyMember;
    const matrix = <String, List<TourneeCommandFailure?>>{
      //                 Manu, Léa, Julie, Paul, Sam, Julie (admin)
      'accept a request': [ok, ok, pending, outsider, ok, ok],
      'refuse a request': [ok, ok, pending, outsider, ok, ok],
      'remove Léa': [ok, notAdmin, pending, outsider, ok, ok],
      'leave': [ok, ok, ok, outsider, outsider, ok],
      'regenerate the code': [ok, notAdmin, pending, outsider, ok, ok],
      'delete the tournée': [ok, notAdmin, pending, outsider, ok, ok],
      'rename themself': [ok, ok, pending, outsider, outsider, pending],
      'join as an admin': [inIt, notAdmin, notAdmin, notAdmin, ok, inIt],
    };
    final actors = {
      'Manu (active admin)': manuAsAdmin,
      'Léa (active)': leaActing,
      'Julie (pending)': julieActing,
      'Paul (outsider)': paulActing,
      'Sam (admin, outsider)': samAsAdmin,
      'Julie (pending admin)': Actor(member: julieId, isAdmin: true),
    };

    for (final MapEntry(key: command, value: run) in commands.entries) {
      final expected = matrix[command]!;
      var column = 0;
      for (final MapEntry(key: actor, value: by) in actors.entries) {
        final failure = expected[column++];
        final verdict = failure == null ? 'allow' : 'refuse with $failure';
        test('should $verdict when $actor tries to $command', () {
          final result = run(team(), by);

          if (failure == null) {
            expect(result, isA<Ok<Object?, TourneeCommandFailure>>());
          } else {
            expect(
              result,
              isA<Err<Object?, TourneeCommandFailure>>().having(
                (err) => err.failure,
                'failure',
                failure,
              ),
            );
          }
        });
      }
    }
  });
}

Result<Tournee, NewTourneeFailure> _restore(List<Member> members) =>
    Tournee.create(
      id: tourneeId,
      number: number49,
      centre: csVillefranche,
      joinCode: firstCode,
      createdBy: manuId,
      createdAt: createdAt,
      currentCampaign: campaign2026,
      members: members,
    );

/// Checks that a command on members left the rest of the tournée as it was.
void _expectSameIdentity(Tournee actual, Tournee expected) {
  expect(actual.id, expected.id);
  expect(actual.number, expected.number);
  expect(actual.centre, expected.centre);
  expect(actual.joinCode, expected.joinCode);
  expect(actual.createdBy, expected.createdBy);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.currentCampaign, expected.currentCampaign);
}
