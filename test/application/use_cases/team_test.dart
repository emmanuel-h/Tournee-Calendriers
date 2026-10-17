import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/team.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/scripted_random.dart';

final acceptedAt = DateTime.utc(2026, 11, 2, 8, 20);

/// The indexes of `2`, `3`, `4`, `5`, `6`, `7` in the code alphabet.
final draws234567 = [
  for (final character in '234567'.split(''))
    JoinCode.alphabet.indexOf(character),
];

void main() {
  late FakeTourneeRepository tournees;
  late FakeMyTourneesStore store;

  /// The phone of a member who is not an admin, and of one who is.
  final member = FakeAdminStatus();
  final admin = FakeAdminStatus(phoneIsAdmin: true);

  // The 49 of Manu, Léa and Julie; the phone has it open and also knows
  // the 12.
  setUp(() {
    tournees = FakeTourneeRepository([team()]);
    store = FakeMyTourneesStore(
      valueOf(
        MyTournees.none
            .remember(tournee49)
            .remember(tournee12)
            .open(tournee49.id),
      ),
    );
  });

  group('TeamCommandRefused', () {
    test('should be equal by reason', () {
      expect(
        const TeamCommandRefused(TourneeCommandFailure.notAdmin),
        const TeamCommandRefused(TourneeCommandFailure.notAdmin),
      );
      expect(
        const TeamCommandRefused(TourneeCommandFailure.notAdmin).hashCode,
        const TeamCommandRefused(TourneeCommandFailure.notAdmin).hashCode,
      );
      expect(
        const TeamCommandRefused(TourneeCommandFailure.notAdmin),
        isNot(const TeamCommandRefused(TourneeCommandFailure.notAMember)),
      );
    });

    test('should name itself', () {
      expect(
        '${const TeamCommandRefused(TourneeCommandFailure.notAdmin)}',
        'TeamCommandRefused(TourneeCommandFailure.notAdmin)',
      );
    });
  });

  group('ObserveTeam', () {
    test('should give the tournée then each change of the team', () async {
      final seen = <Tournee?>[];
      final listening = ObserveTeam(tournees)(tourneeId).listen(seen.add);
      addTearDown(listening.cancel);
      await pumpEventQueue();

      tournees.put(team(members: [manu, lea]));
      await pumpEventQueue();

      expect(seen.map((tournee) => tournee?.members.length), [3, 2]);
    });
  });

  group('ReadCurrentMember', () {
    test('should give the member using the phone', () {
      expect(ReadCurrentMember(FakeIdentity(leaId))(), leaId);
    });
  });

  group('AcceptMember', () {
    test('should let the request in, accepted by the member on the phone, '
        'now', () async {
      final accept = AcceptMember(
        tournees,
        FakeClock(acceptedAt),
        FakeIdentity(leaId),
        member,
      );

      final change = valueOf(await accept(tourneeId, julieId));

      final accepted = Member(
        id: julieId,
        name: nameOf('Julie'),
        requestedAt: julieAskedAt,
        acceptance: ChangeStamp(by: leaId, at: acceptedAt),
      );
      expect(change, MemberAccepted(tourneeId: tourneeId, member: accepted));
      expect(tournees.saved.single.$2, change);
      expect(tournees[tourneeId]!.memberOf(julieId), accepted);
    });

    test('should be refused when the request was already accepted', () async {
      final accept = AcceptMember(
        tournees,
        FakeClock(acceptedAt),
        FakeIdentity(manuId),
        admin,
      );

      final failure = failureOf(await accept(tourneeId, leaId));

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.alreadyActive),
      );
      expect(tournees.saved, isEmpty);
    });

    test('should let in a request answered by an admin who is not in the '
        'team', () async {
      final accept = AcceptMember(
        tournees,
        FakeClock(acceptedAt),
        FakeIdentity(samId),
        admin,
      );

      final change = valueOf(await accept(tourneeId, julieId));

      expect(change.member.acceptance, ChangeStamp(by: samId, at: acceptedAt));
    });

    test('should be refused to someone outside who is not an admin', () async {
      final accept = AcceptMember(
        tournees,
        FakeClock(acceptedAt),
        FakeIdentity(samId),
        member,
      );

      final failure = failureOf(await accept(tourneeId, julieId));

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.notAMember),
      );
    });

    test('should still let a member accept when the admin status cannot be '
        'read', () async {
      final unreadable = FakeAdminStatus(phoneIsAdmin: true)..unreadable = true;
      final accept = AcceptMember(
        tournees,
        FakeClock(acceptedAt),
        FakeIdentity(leaId),
        unreadable,
      );

      final change = valueOf(await accept(tourneeId, julieId));

      expect(change.member.acceptance, ChangeStamp(by: leaId, at: acceptedAt));
    });

    test('should tell when the tournée cannot be read any more', () async {
      final accept = AcceptMember(
        tournees,
        FakeClock(acceptedAt),
        FakeIdentity(manuId),
        admin,
      );

      final failure = failureOf(await accept(TourneeId('gone'), julieId));

      expect(failure, TeamProblem.tourneeGone);
      expect(tournees.saved, isEmpty);
    });
  });

  group('RefuseMember', () {
    test('should take the request out', () async {
      final change = valueOf(
        await RefuseMember(tournees, FakeIdentity(leaId), member)(
          tourneeId,
          julieId,
        ),
      );

      expect(change, MemberRefused(tourneeId: tourneeId, member: julie));
      expect(tournees.saved.single.$2, change);
      expect(tournees[tourneeId]!.memberOf(julieId), isNull);
    });

    test('should be refused to a pending member', () async {
      final failure = failureOf(
        await RefuseMember(tournees, FakeIdentity(julieId), member)(
          tourneeId,
          julieId,
        ),
      );

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.requestPending),
      );
    });
  });

  group('RefuseMember as an admin', () {
    test('should take the request out when an admin outside the team '
        'refuses it', () async {
      final change = valueOf(
        await RefuseMember(tournees, FakeIdentity(samId), admin)(
          tourneeId,
          julieId,
        ),
      );

      expect(change, MemberRefused(tourneeId: tourneeId, member: julie));
    });
  });

  group('RemoveMember', () {
    test('should take the member out when an admin asks', () async {
      final change = valueOf(
        await RemoveMember(tournees, FakeIdentity(samId), admin)(
          tourneeId,
          leaId,
        ),
      );

      expect(change, MemberRemoved(tourneeId: tourneeId, member: lea));
      expect(tournees.saved.single.$2, change);
      expect(tournees[tourneeId]!.memberOf(leaId), isNull);
    });

    test('should be refused to a member who is not an admin, the creator '
        'too', () async {
      // Manu created the 49, but here his phone is not an admin.
      final failure = failureOf(
        await RemoveMember(tournees, FakeIdentity(manuId), member)(
          tourneeId,
          leaId,
        ),
      );

      expect(failure, const TeamCommandRefused(TourneeCommandFailure.notAdmin));
      expect(tournees.saved, isEmpty);
    });
  });

  group('LeaveTournee', () {
    test('should take the member out and forget the tournée on the '
        'phone', () async {
      final change = valueOf(
        await LeaveTournee(tournees, FakeIdentity(leaId), store)(tourneeId),
      );

      expect(change, MemberLeft(tourneeId: tourneeId, member: lea));
      expect(tournees.saved.single.$2, change);
      expect(store.myTournees.tournees, [tournee12]);
      expect(store.myTournees.currentId, isNull);
    });

    test('should let the creator leave too', () async {
      final change = valueOf(
        await LeaveTournee(tournees, FakeIdentity(manuId), store)(tourneeId),
      );

      expect(change, MemberLeft(tourneeId: tourneeId, member: manu));
      expect(store.myTournees.tournees, [tournee12]);
    });

    test('should keep the tournée on the phone when the member is not in '
        'it', () async {
      final failure = failureOf(
        await LeaveTournee(tournees, FakeIdentity(samId), store)(tourneeId),
      );

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.notAMember),
      );
      expect(store.saves, isEmpty);
    });
  });

  group('RegenerateJoinCode', () {
    test('should store a new code drawn from the random source', () async {
      final code = valueOf(
        await RegenerateJoinCode(
          tournees,
          FakeIdentity(manuId),
          admin,
          ScriptedRandom(draws234567),
        )(tourneeId),
      );

      expect(code, codeOf('234567'));
      expect(
        tournees.saved.single.$2,
        JoinCodeRegenerated(
          tourneeId: tourneeId,
          before: firstCode,
          code: codeOf('234567'),
        ),
      );
    });

    test('should give the code stored when the server took another', () async {
      tournees.codeTaken = codeOf('765432');

      final code = valueOf(
        await RegenerateJoinCode(
          tournees,
          FakeIdentity(manuId),
          admin,
          ScriptedRandom(draws234567),
        )(tourneeId),
      );

      expect(code, codeOf('765432'));
    });

    test('should be refused to a member who is not an admin', () async {
      final failure = failureOf(
        await RegenerateJoinCode(
          tournees,
          FakeIdentity(leaId),
          member,
          ScriptedRandom(draws234567),
        )(tourneeId),
      );

      expect(failure, const TeamCommandRefused(TourneeCommandFailure.notAdmin));
      expect(tournees.saved, isEmpty);
    });

    test('should be refused when the admin status cannot be read', () async {
      final failure = failureOf(
        await RegenerateJoinCode(
          tournees,
          FakeIdentity(manuId),
          FakeAdminStatus(phoneIsAdmin: true)..unreadable = true,
          ScriptedRandom(draws234567),
        )(tourneeId),
      );

      expect(failure, const TeamCommandRefused(TourneeCommandFailure.notAdmin));
      expect(tournees.saved, isEmpty);
    });

    test('should tell when the server cannot be reached', () async {
      tournees.offline = true;

      final failure = failureOf(
        await RegenerateJoinCode(
          tournees,
          FakeIdentity(manuId),
          admin,
          ScriptedRandom(draws234567),
        )(tourneeId),
      );

      expect(failure, TeamProblem.offline);
      expect(tournees[tourneeId]!.joinCode, firstCode);
    });

    test('should tell when the server says the phone is no longer an '
        'admin\'s', () async {
      tournees.notAdmin = true;

      final failure = failureOf(
        await RegenerateJoinCode(
          tournees,
          FakeIdentity(manuId),
          admin,
          ScriptedRandom(draws234567),
        )(tourneeId),
      );

      expect(failure, TeamProblem.notAdmin);
      expect(tournees[tourneeId]!.joinCode, firstCode);
    });
  });

  group('DeleteTournee', () {
    test('should delete the tournée and forget it on the phone', () async {
      final deletion = valueOf(
        await DeleteTournee(tournees, FakeIdentity(manuId), admin, store)(
          tourneeId,
        ),
      );

      expect(deletion.tournee.id, tourneeId);
      expect(deletion.tournee.members, [manu, lea, julie]);
      expect(tournees.deleted, [deletion]);
      expect(store.myTournees.tournees, [tournee12]);
      expect(store.myTournees.currentId, isNull);
    });

    test('should let an admin who is not in the team delete it', () async {
      final deletion = valueOf(
        await DeleteTournee(tournees, FakeIdentity(samId), admin, store)(
          tourneeId,
        ),
      );

      expect(tournees.deleted, [deletion]);
    });

    test('should be refused to a member who is not an admin', () async {
      final failure = failureOf(
        await DeleteTournee(tournees, FakeIdentity(leaId), member, store)(
          tourneeId,
        ),
      );

      expect(failure, const TeamCommandRefused(TourneeCommandFailure.notAdmin));
      expect(tournees.deleted, isEmpty);
      expect(store.saves, isEmpty);
    });

    test('should keep everything when the server cannot be reached', () async {
      tournees.offline = true;

      final failure = failureOf(
        await DeleteTournee(tournees, FakeIdentity(manuId), admin, store)(
          tourneeId,
        ),
      );

      expect(failure, TeamProblem.offline);
      expect(tournees[tourneeId], isNotNull);
      expect(store.saves, isEmpty);
    });

    test('should keep everything when the server says the phone is no '
        'longer an admin\'s', () async {
      tournees.notAdmin = true;

      final failure = failureOf(
        await DeleteTournee(tournees, FakeIdentity(manuId), admin, store)(
          tourneeId,
        ),
      );

      expect(failure, TeamProblem.notAdmin);
      expect(tournees[tourneeId], isNotNull);
      expect(store.saves, isEmpty);
    });

    test('should tell when the tournée cannot be read any more', () async {
      final failure = failureOf(
        await DeleteTournee(tournees, FakeIdentity(manuId), admin, store)(
          TourneeId('gone'),
        ),
      );

      expect(failure, TeamProblem.tourneeGone);
      expect(store.saves, isEmpty);
    });
  });

  group('JoinAsAdmin', () {
    final joinedAt = DateTime.utc(2026, 11, 2, 10);

    // Sam, an admin, visits the 49 from « Toutes les tournées ».
    setUp(() {
      store.myTournees = valueOf(
        MyTournees.none
            .remember(summaryOf('t49', 49, status: MemberStatus.visiting))
            .remember(tournee12)
            .open(tourneeId),
      );
    });

    JoinAsAdmin joinAs(FakeAdminStatus admins, {FakePhoneSettings? settings}) =>
        JoinAsAdmin(
          tournees,
          FakeIdentity(samId),
          admins,
          FakeClock(joinedAt),
          settings ?? FakePhoneSettings(memberName: nameOf('Sam')),
          store,
        );

    test('should make the admin an active member, accepted by themself, '
        'and the tournée theirs on the phone', () async {
      final change = valueOf(await joinAs(admin)(tourneeId));

      final sam = Member(
        id: samId,
        name: nameOf('Sam'),
        requestedAt: joinedAt,
        acceptance: ChangeStamp(by: samId, at: joinedAt),
      );
      expect(change, AdminJoined(tourneeId: tourneeId, member: sam));
      expect(tournees.saved.single.$2, change);
      expect(tournees[tourneeId]!.activeMembers, [manu, lea, sam]);
      expect(store.myTournees.tournees, [tournee49, tournee12]);
      expect(store.myTournees.currentId, tourneeId);
    });

    test('should be refused to someone who is no longer an admin', () async {
      final failure = failureOf(await joinAs(member)(tourneeId));

      expect(failure, const TeamCommandRefused(TourneeCommandFailure.notAdmin));
      expect(tournees.saved, isEmpty);
      expect(store.saves, isEmpty);
    });

    test('should change nothing when the server cannot be reached', () async {
      tournees.offline = true;

      final failure = failureOf(await joinAs(admin)(tourneeId));

      expect(failure, TeamProblem.offline);
      expect(tournees[tourneeId]!.memberOf(samId), isNull);
      expect(store.saves, isEmpty);
    });

    test('should change nothing when the server says the phone is no '
        'longer an admin\'s', () async {
      tournees.notAdmin = true;

      final failure = failureOf(await joinAs(admin)(tourneeId));

      expect(failure, TeamProblem.notAdmin);
      expect(tournees[tourneeId]!.memberOf(samId), isNull);
      expect(store.saves, isEmpty);
    });

    test('should ask for a first name when the phone has none', () async {
      final failure = failureOf(
        await joinAs(admin, settings: FakePhoneSettings())(tourneeId),
      );

      expect(failure, TeamProblem.noName);
      expect(tournees.saved, isEmpty);
    });

    test('should tell when the tournée cannot be read any more', () async {
      final failure = failureOf(await joinAs(admin)(TourneeId('gone')));

      expect(failure, TeamProblem.tourneeGone);
      expect(store.saves, isEmpty);
    });

    test('should save nothing on the phone when it no longer knows the '
        'tournée', () async {
      store.myTournees = MyTournees.none;

      valueOf(await joinAs(admin)(tourneeId));

      expect(store.saves, isEmpty);
    });
  });

  group('ForgetVisitedTournee', () {
    test('should forget the tournée on the phone and write nothing', () async {
      await ForgetVisitedTournee(store)(tourneeId);

      expect(store.myTournees.tournees, [tournee12]);
      expect(store.myTournees.currentId, isNull);
      expect(tournees.saved, isEmpty);
    });
  });
}
