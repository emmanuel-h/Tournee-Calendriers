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
import '../../support/fakes/fake_my_tournees_store.dart';
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

  group('TeamFailure', () {
    test('should be equal by kind and reason', () {
      expect(const TourneeGone(), const TourneeGone());
      expect(const TourneeGone().hashCode, const TourneeGone().hashCode);
      expect(const TeamOffline(), const TeamOffline());
      expect(const TeamOffline().hashCode, const TeamOffline().hashCode);
      expect(
        const TeamCommandRefused(TourneeCommandFailure.notCreator),
        const TeamCommandRefused(TourneeCommandFailure.notCreator),
      );
      expect(
        const TeamCommandRefused(TourneeCommandFailure.notCreator).hashCode,
        const TeamCommandRefused(TourneeCommandFailure.notCreator).hashCode,
      );
      expect(
        const TeamCommandRefused(TourneeCommandFailure.notCreator),
        isNot(const TeamCommandRefused(TourneeCommandFailure.notAMember)),
      );
      expect(const TourneeGone(), isNot(const TeamOffline()));
      expect(const TeamOffline(), isNot(const TourneeGone()));
    });

    test('should name itself', () {
      expect('${const TourneeGone()}', 'TourneeGone');
      expect('${const TeamOffline()}', 'TeamOffline');
      expect(
        '${const TeamCommandRefused(TourneeCommandFailure.notCreator)}',
        'TeamCommandRefused(TourneeCommandFailure.notCreator)',
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
      );

      final failure = failureOf(await accept(tourneeId, leaId));

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.alreadyActive),
      );
      expect(tournees.saved, isEmpty);
    });

    test('should tell when the tournée cannot be read any more', () async {
      final accept = AcceptMember(
        tournees,
        FakeClock(acceptedAt),
        FakeIdentity(manuId),
      );

      final failure = failureOf(await accept(TourneeId('gone'), julieId));

      expect(failure, const TourneeGone());
      expect(tournees.saved, isEmpty);
    });
  });

  group('RefuseMember', () {
    test('should take the request out', () async {
      final change = valueOf(
        await RefuseMember(tournees, FakeIdentity(leaId))(tourneeId, julieId),
      );

      expect(change, MemberRefused(tourneeId: tourneeId, member: julie));
      expect(tournees.saved.single.$2, change);
      expect(tournees[tourneeId]!.memberOf(julieId), isNull);
    });

    test('should be refused to a pending member', () async {
      final failure = failureOf(
        await RefuseMember(tournees, FakeIdentity(julieId))(tourneeId, julieId),
      );

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.requestPending),
      );
    });
  });

  group('RemoveMember', () {
    test('should take the member out when the creator asks', () async {
      final change = valueOf(
        await RemoveMember(tournees, FakeIdentity(manuId))(tourneeId, leaId),
      );

      expect(change, MemberRemoved(tourneeId: tourneeId, member: lea));
      expect(tournees.saved.single.$2, change);
      expect(tournees[tourneeId]!.memberOf(leaId), isNull);
    });

    test('should be refused to another member than the creator', () async {
      final failure = failureOf(
        await RemoveMember(tournees, FakeIdentity(leaId))(tourneeId, leaId),
      );

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.notCreator),
      );
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

    test('should keep the tournée on the phone when the creator '
        'asks', () async {
      final failure = failureOf(
        await LeaveTournee(tournees, FakeIdentity(manuId), store)(tourneeId),
      );

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.creatorStays),
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
          ScriptedRandom(draws234567),
        )(tourneeId),
      );

      expect(code, codeOf('765432'));
    });

    test('should be refused to another member than the creator', () async {
      final failure = failureOf(
        await RegenerateJoinCode(
          tournees,
          FakeIdentity(leaId),
          ScriptedRandom(draws234567),
        )(tourneeId),
      );

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.notCreator),
      );
      expect(tournees.saved, isEmpty);
    });

    test('should tell when the server cannot be reached', () async {
      tournees.offline = true;

      final failure = failureOf(
        await RegenerateJoinCode(
          tournees,
          FakeIdentity(manuId),
          ScriptedRandom(draws234567),
        )(tourneeId),
      );

      expect(failure, const TeamOffline());
      expect(tournees[tourneeId]!.joinCode, firstCode);
    });
  });

  group('DeleteTournee', () {
    test('should delete the tournée and forget it on the phone', () async {
      final deletion = valueOf(
        await DeleteTournee(tournees, FakeIdentity(manuId), store)(tourneeId),
      );

      expect(deletion.tournee.id, tourneeId);
      expect(deletion.tournee.members, [manu, lea, julie]);
      expect(tournees.deleted, [deletion]);
      expect(store.myTournees.tournees, [tournee12]);
      expect(store.myTournees.currentId, isNull);
    });

    test('should be refused to another member than the creator', () async {
      final failure = failureOf(
        await DeleteTournee(tournees, FakeIdentity(leaId), store)(tourneeId),
      );

      expect(
        failure,
        const TeamCommandRefused(TourneeCommandFailure.notCreator),
      );
      expect(tournees.deleted, isEmpty);
      expect(store.saves, isEmpty);
    });

    test('should keep everything when the server cannot be reached', () async {
      tournees.offline = true;

      final failure = failureOf(
        await DeleteTournee(tournees, FakeIdentity(manuId), store)(tourneeId),
      );

      expect(failure, const TeamOffline());
      expect(tournees[tourneeId], isNotNull);
      expect(store.saves, isEmpty);
    });

    test('should tell when the tournée cannot be read any more', () async {
      final failure = failureOf(
        await DeleteTournee(tournees, FakeIdentity(manuId), store)(
          TourneeId('gone'),
        ),
      );

      expect(failure, const TourneeGone());
      expect(store.saves, isEmpty);
    });
  });
}
