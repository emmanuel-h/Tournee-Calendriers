import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/team.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../../support/scripted_random.dart';
import '../../support/street_fixtures.dart' show insee;

final acceptedAt = DateTime.utc(2026, 11, 2, 8, 20);

/// The indexes of `2`, `3`, `4`, `5`, `6`, `7` in the code alphabet.
final draws234567 = [
  for (final character in '234567'.split(''))
    JoinCode.alphabet.indexOf(character),
];

void main() {
  late FakeSectorRepository sectors;
  late FakeMySectorsStore store;

  /// The phone of a member who is not an admin, and of one who is.
  final member = FakeAdminStatus();
  final admin = FakeAdminStatus(phoneIsAdmin: true);

  // The 49 of Manu, Léa and Julie; the phone has it open and also knows
  // the 12.
  setUp(() {
    sectors = FakeSectorRepository([team()]);
    store = FakeMySectorsStore(
      valueOf(
        MySectors.none.remember(sector49).remember(sector12).open(sector49.id),
      ),
    );
  });

  group('TeamCommandRefused', () {
    test('should be equal by reason', () {
      expect(
        const TeamCommandRefused(SectorCommandFailure.notAdmin),
        const TeamCommandRefused(SectorCommandFailure.notAdmin),
      );
      expect(
        const TeamCommandRefused(SectorCommandFailure.notAdmin).hashCode,
        const TeamCommandRefused(SectorCommandFailure.notAdmin).hashCode,
      );
      expect(
        const TeamCommandRefused(SectorCommandFailure.notAdmin),
        isNot(const TeamCommandRefused(SectorCommandFailure.notAMember)),
      );
    });

    test('should name itself', () {
      expect(
        '${const TeamCommandRefused(SectorCommandFailure.notAdmin)}',
        'TeamCommandRefused(SectorCommandFailure.notAdmin)',
      );
    });
  });

  group('ObserveTeam', () {
    test('should give the tournée then each change of the team', () async {
      final seen = <Sector?>[];
      final listening = ObserveTeam(sectors)(sectorId).listen(seen.add);
      addTearDown(listening.cancel);
      await pumpEventQueue();

      sectors.put(team(members: [manu, lea]));
      await pumpEventQueue();

      expect(seen.map((sector) => sector?.members.length), [3, 2]);
    });
  });

  group('ObserveSectorCommunes', () {
    test('should give the communes then each change of them, not of the '
        'team', () async {
      sectors.put(team(communes: [villefrancheCommune]));
      final seen = <List<SectorCommune>>[];
      final listening = ObserveSectorCommunes(sectors)(sectorId)
          .listen(seen.add);
      addTearDown(listening.cancel);
      await pumpEventQueue();

      sectors.put(team(members: [manu, lea], communes: [villefrancheCommune]));
      await pumpEventQueue();
      sectors.put(team(communes: [villefrancheCommune, gleizeCommune]));
      await pumpEventQueue();

      expect(seen, [
        [villefrancheCommune],
        [villefrancheCommune, gleizeCommune],
      ]);
    });

    test('should give none when the tournée cannot be read', () async {
      sectors.put(team(communes: [villefrancheCommune]));
      final seen = <List<SectorCommune>>[];
      final listening = ObserveSectorCommunes(sectors)(sectorId)
          .listen(seen.add);
      addTearDown(listening.cancel);
      await pumpEventQueue();

      sectors.lose(sectorId);
      await pumpEventQueue();

      expect(seen, [
        [villefrancheCommune],
        <SectorCommune>[],
      ]);
    });
  });

  group('AddCommune', () {
    test('should add the commune for a member and store the change', () async {
      sectors.put(team(communes: [villefrancheCommune]));

      final change = valueOf(
        await AddCommune(sectors, FakeIdentity(leaId), member)(
          sectorId,
          gleizeCommune,
        ),
      );

      expect(change, CommuneAdded(sectorId: sectorId, commune: gleizeCommune));
      expect(sectors.saved.single.$2, change);
      expect(sectors[sectorId]!.communes, [villefrancheCommune, gleizeCommune]);
    });

    test('should let an admin outside the team add one', () async {
      final change = valueOf(
        await AddCommune(sectors, FakeIdentity(samId), admin)(
          sectorId,
          gleizeCommune,
        ),
      );

      expect(change.commune, gleizeCommune);
    });

    test('should be refused when the tournée already covers it', () async {
      sectors.put(team(communes: [gleizeCommune]));

      final failure = failureOf(
        await AddCommune(sectors, FakeIdentity(leaId), member)(
          sectorId,
          gleizeCommune,
        ),
      );

      expect(
        failure,
        const TeamCommandRefused(SectorCommandFailure.communeAlreadyIn),
      );
      expect(sectors.saved, isEmpty);
    });

    test('should fail when the tournée is gone', () async {
      sectors.lose(sectorId);

      final failure = failureOf(
        await AddCommune(sectors, FakeIdentity(leaId), member)(
          sectorId,
          gleizeCommune,
        ),
      );

      expect(failure, TeamProblem.sectorGone);
    });
  });

  group('RemoveCommune', () {
    test('should remove the commune for a member and store the '
        'change', () async {
      sectors.put(team(communes: [villefrancheCommune, gleizeCommune]));

      final change = valueOf(
        await RemoveCommune(sectors, FakeIdentity(leaId), member)(
          sectorId,
          insee('69264'),
        ),
      );

      expect(
        change,
        CommuneRemoved(sectorId: sectorId, commune: villefrancheCommune),
      );
      expect(sectors.saved.single.$2, change);
      expect(sectors[sectorId]!.communes, [gleizeCommune]);
    });

    test('should be refused for the last commune', () async {
      sectors.put(team(communes: [villefrancheCommune]));

      final failure = failureOf(
        await RemoveCommune(sectors, FakeIdentity(samId), admin)(
          sectorId,
          insee('69264'),
        ),
      );

      expect(
        failure,
        const TeamCommandRefused(SectorCommandFailure.lastCommune),
      );
      expect(sectors.saved, isEmpty);
    });

    test('should be refused for a pending member', () async {
      sectors.put(team(communes: [villefrancheCommune, gleizeCommune]));

      final failure = failureOf(
        await RemoveCommune(sectors, FakeIdentity(julieId), member)(
          sectorId,
          insee('69092'),
        ),
      );

      expect(
        failure,
        const TeamCommandRefused(SectorCommandFailure.requestPending),
      );
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
        sectors,
        FakeClock(acceptedAt),
        FakeIdentity(leaId),
        member,
      );

      final change = valueOf(await accept(sectorId, julieId));

      final accepted = Member(
        id: julieId,
        name: nameOf('Julie'),
        requestedAt: julieAskedAt,
        acceptance: ChangeStamp(by: leaId, at: acceptedAt),
      );
      expect(change, MemberAccepted(sectorId: sectorId, member: accepted));
      expect(sectors.saved.single.$2, change);
      expect(sectors[sectorId]!.memberOf(julieId), accepted);
    });

    test('should be refused when the request was already accepted', () async {
      final accept = AcceptMember(
        sectors,
        FakeClock(acceptedAt),
        FakeIdentity(manuId),
        admin,
      );

      final failure = failureOf(await accept(sectorId, leaId));

      expect(
        failure,
        const TeamCommandRefused(SectorCommandFailure.alreadyActive),
      );
      expect(sectors.saved, isEmpty);
    });

    test('should let in a request answered by an admin who is not in the '
        'team', () async {
      final accept = AcceptMember(
        sectors,
        FakeClock(acceptedAt),
        FakeIdentity(samId),
        admin,
      );

      final change = valueOf(await accept(sectorId, julieId));

      expect(change.member.acceptance, ChangeStamp(by: samId, at: acceptedAt));
    });

    test('should be refused to someone outside who is not an admin', () async {
      final accept = AcceptMember(
        sectors,
        FakeClock(acceptedAt),
        FakeIdentity(samId),
        member,
      );

      final failure = failureOf(await accept(sectorId, julieId));

      expect(
        failure,
        const TeamCommandRefused(SectorCommandFailure.notAMember),
      );
    });

    test('should still let a member accept when the admin status cannot be '
        'read', () async {
      final unreadable = FakeAdminStatus(phoneIsAdmin: true)..unreadable = true;
      final accept = AcceptMember(
        sectors,
        FakeClock(acceptedAt),
        FakeIdentity(leaId),
        unreadable,
      );

      final change = valueOf(await accept(sectorId, julieId));

      expect(change.member.acceptance, ChangeStamp(by: leaId, at: acceptedAt));
    });

    test('should tell when the tournée cannot be read any more', () async {
      final accept = AcceptMember(
        sectors,
        FakeClock(acceptedAt),
        FakeIdentity(manuId),
        admin,
      );

      final failure = failureOf(await accept(SectorId('gone'), julieId));

      expect(failure, TeamProblem.sectorGone);
      expect(sectors.saved, isEmpty);
    });
  });

  group('RefuseMember', () {
    test('should take the request out', () async {
      final change = valueOf(
        await RefuseMember(sectors, FakeIdentity(leaId), member)(
          sectorId,
          julieId,
        ),
      );

      expect(change, MemberRefused(sectorId: sectorId, member: julie));
      expect(sectors.saved.single.$2, change);
      expect(sectors[sectorId]!.memberOf(julieId), isNull);
    });

    test('should be refused to a pending member', () async {
      final failure = failureOf(
        await RefuseMember(sectors, FakeIdentity(julieId), member)(
          sectorId,
          julieId,
        ),
      );

      expect(
        failure,
        const TeamCommandRefused(SectorCommandFailure.requestPending),
      );
    });
  });

  group('RefuseMember as an admin', () {
    test('should take the request out when an admin outside the team '
        'refuses it', () async {
      final change = valueOf(
        await RefuseMember(sectors, FakeIdentity(samId), admin)(
          sectorId,
          julieId,
        ),
      );

      expect(change, MemberRefused(sectorId: sectorId, member: julie));
    });
  });

  group('RemoveMember', () {
    test('should take the member out when an admin asks', () async {
      final change = valueOf(
        await RemoveMember(sectors, FakeIdentity(samId), admin)(
          sectorId,
          leaId,
        ),
      );

      expect(change, MemberRemoved(sectorId: sectorId, member: lea));
      expect(sectors.saved.single.$2, change);
      expect(sectors[sectorId]!.memberOf(leaId), isNull);
    });

    test('should be refused to a member who is not an admin, the creator '
        'too', () async {
      // Manu created the 49, but here his phone is not an admin.
      final failure = failureOf(
        await RemoveMember(sectors, FakeIdentity(manuId), member)(
          sectorId,
          leaId,
        ),
      );

      expect(failure, const TeamCommandRefused(SectorCommandFailure.notAdmin));
      expect(sectors.saved, isEmpty);
    });
  });

  group('LeaveSector', () {
    test('should take the member out and forget the tournée on the '
        'phone', () async {
      final change = valueOf(
        await LeaveSector(sectors, FakeIdentity(leaId), store)(sectorId),
      );

      expect(change, MemberLeft(sectorId: sectorId, member: lea));
      expect(sectors.saved.single.$2, change);
      expect(store.mySectors.sectors, [sector12]);
      expect(store.mySectors.currentId, isNull);
    });

    test('should let the creator leave too', () async {
      final change = valueOf(
        await LeaveSector(sectors, FakeIdentity(manuId), store)(sectorId),
      );

      expect(change, MemberLeft(sectorId: sectorId, member: manu));
      expect(store.mySectors.sectors, [sector12]);
    });

    test('should keep the tournée on the phone when the member is not in '
        'it', () async {
      final failure = failureOf(
        await LeaveSector(sectors, FakeIdentity(samId), store)(sectorId),
      );

      expect(
        failure,
        const TeamCommandRefused(SectorCommandFailure.notAMember),
      );
      expect(store.saves, isEmpty);
    });
  });

  group('RegenerateJoinCode', () {
    test('should store a new code drawn from the random source', () async {
      final code = valueOf(
        await RegenerateJoinCode(
          sectors,
          FakeIdentity(manuId),
          admin,
          ScriptedRandom(draws234567),
        )(sectorId),
      );

      expect(code, codeOf('234567'));
      expect(
        sectors.saved.single.$2,
        JoinCodeRegenerated(
          sectorId: sectorId,
          before: firstCode,
          code: codeOf('234567'),
        ),
      );
    });

    test('should give the code stored when the server took another', () async {
      sectors.codeTaken = codeOf('765432');

      final code = valueOf(
        await RegenerateJoinCode(
          sectors,
          FakeIdentity(manuId),
          admin,
          ScriptedRandom(draws234567),
        )(sectorId),
      );

      expect(code, codeOf('765432'));
    });

    test('should be refused to a member who is not an admin', () async {
      final failure = failureOf(
        await RegenerateJoinCode(
          sectors,
          FakeIdentity(leaId),
          member,
          ScriptedRandom(draws234567),
        )(sectorId),
      );

      expect(failure, const TeamCommandRefused(SectorCommandFailure.notAdmin));
      expect(sectors.saved, isEmpty);
    });

    test('should be refused when the admin status cannot be read', () async {
      final failure = failureOf(
        await RegenerateJoinCode(
          sectors,
          FakeIdentity(manuId),
          FakeAdminStatus(phoneIsAdmin: true)..unreadable = true,
          ScriptedRandom(draws234567),
        )(sectorId),
      );

      expect(failure, const TeamCommandRefused(SectorCommandFailure.notAdmin));
      expect(sectors.saved, isEmpty);
    });

    test('should tell when the server cannot be reached', () async {
      sectors.offline = true;

      final failure = failureOf(
        await RegenerateJoinCode(
          sectors,
          FakeIdentity(manuId),
          admin,
          ScriptedRandom(draws234567),
        )(sectorId),
      );

      expect(failure, TeamProblem.offline);
      expect(sectors[sectorId]!.joinCode, firstCode);
    });

    test('should tell when the server says the phone is no longer an '
        'admin\'s', () async {
      sectors.notAdmin = true;

      final failure = failureOf(
        await RegenerateJoinCode(
          sectors,
          FakeIdentity(manuId),
          admin,
          ScriptedRandom(draws234567),
        )(sectorId),
      );

      expect(failure, TeamProblem.notAdmin);
      expect(sectors[sectorId]!.joinCode, firstCode);
    });
  });

  group('DeleteSector', () {
    test('should delete the tournée and forget it on the phone', () async {
      final deletion = valueOf(
        await DeleteSector(sectors, FakeIdentity(manuId), admin, store)(
          sectorId,
        ),
      );

      expect(deletion.sector.id, sectorId);
      expect(deletion.sector.members, [manu, lea, julie]);
      expect(sectors.deleted, [deletion]);
      expect(store.mySectors.sectors, [sector12]);
      expect(store.mySectors.currentId, isNull);
    });

    test('should let an admin who is not in the team delete it', () async {
      final deletion = valueOf(
        await DeleteSector(sectors, FakeIdentity(samId), admin, store)(
          sectorId,
        ),
      );

      expect(sectors.deleted, [deletion]);
    });

    test('should be refused to a member who is not an admin', () async {
      final failure = failureOf(
        await DeleteSector(sectors, FakeIdentity(leaId), member, store)(
          sectorId,
        ),
      );

      expect(failure, const TeamCommandRefused(SectorCommandFailure.notAdmin));
      expect(sectors.deleted, isEmpty);
      expect(store.saves, isEmpty);
    });

    test('should keep everything when the server cannot be reached', () async {
      sectors.offline = true;

      final failure = failureOf(
        await DeleteSector(sectors, FakeIdentity(manuId), admin, store)(
          sectorId,
        ),
      );

      expect(failure, TeamProblem.offline);
      expect(sectors[sectorId], isNotNull);
      expect(store.saves, isEmpty);
    });

    test('should keep everything when the server says the phone is no '
        'longer an admin\'s', () async {
      sectors.notAdmin = true;

      final failure = failureOf(
        await DeleteSector(sectors, FakeIdentity(manuId), admin, store)(
          sectorId,
        ),
      );

      expect(failure, TeamProblem.notAdmin);
      expect(sectors[sectorId], isNotNull);
      expect(store.saves, isEmpty);
    });

    test('should tell when the tournée cannot be read any more', () async {
      final failure = failureOf(
        await DeleteSector(sectors, FakeIdentity(manuId), admin, store)(
          SectorId('gone'),
        ),
      );

      expect(failure, TeamProblem.sectorGone);
      expect(store.saves, isEmpty);
    });
  });

  group('JoinAsAdmin', () {
    final joinedAt = DateTime.utc(2026, 11, 2, 10);

    // Sam, an admin, visits the 49 from « Toutes les tournées ».
    setUp(() {
      store.mySectors = valueOf(
        MySectors.none
            .remember(summaryOf('t49', 49, status: MemberStatus.visiting))
            .remember(sector12)
            .open(sectorId),
      );
    });

    JoinAsAdmin joinAs(FakeAdminStatus admins, {FakePhoneSettings? settings}) =>
        JoinAsAdmin(
          sectors,
          FakeIdentity(samId),
          admins,
          FakeClock(joinedAt),
          settings ?? FakePhoneSettings(memberName: nameOf('Sam')),
          store,
        );

    test('should make the admin an active member, accepted by themself, '
        'and the tournée theirs on the phone', () async {
      final change = valueOf(await joinAs(admin)(sectorId));

      final sam = Member(
        id: samId,
        name: nameOf('Sam'),
        requestedAt: joinedAt,
        acceptance: ChangeStamp(by: samId, at: joinedAt),
      );
      expect(change, AdminJoined(sectorId: sectorId, member: sam));
      expect(sectors.saved.single.$2, change);
      expect(sectors[sectorId]!.activeMembers, [manu, lea, sam]);
      expect(store.mySectors.sectors, [sector49, sector12]);
      expect(store.mySectors.currentId, sectorId);
    });

    test('should be refused to someone who is no longer an admin', () async {
      final failure = failureOf(await joinAs(member)(sectorId));

      expect(failure, const TeamCommandRefused(SectorCommandFailure.notAdmin));
      expect(sectors.saved, isEmpty);
      expect(store.saves, isEmpty);
    });

    test('should change nothing when the server cannot be reached', () async {
      sectors.offline = true;

      final failure = failureOf(await joinAs(admin)(sectorId));

      expect(failure, TeamProblem.offline);
      expect(sectors[sectorId]!.memberOf(samId), isNull);
      expect(store.saves, isEmpty);
    });

    test('should change nothing when the server says the phone is no '
        'longer an admin\'s', () async {
      sectors.notAdmin = true;

      final failure = failureOf(await joinAs(admin)(sectorId));

      expect(failure, TeamProblem.notAdmin);
      expect(sectors[sectorId]!.memberOf(samId), isNull);
      expect(store.saves, isEmpty);
    });

    test('should ask for a first name when the phone has none', () async {
      final failure = failureOf(
        await joinAs(admin, settings: FakePhoneSettings())(sectorId),
      );

      expect(failure, TeamProblem.noName);
      expect(sectors.saved, isEmpty);
    });

    test('should tell when the tournée cannot be read any more', () async {
      final failure = failureOf(await joinAs(admin)(SectorId('gone')));

      expect(failure, TeamProblem.sectorGone);
      expect(store.saves, isEmpty);
    });

    test('should save nothing on the phone when it no longer knows the '
        'tournée', () async {
      store.mySectors = MySectors.none;

      valueOf(await joinAs(admin)(sectorId));

      expect(store.saves, isEmpty);
    });
  });

  group('ForgetVisitedSector', () {
    test('should forget the tournée on the phone and write nothing', () async {
      await ForgetVisitedSector(store)(sectorId);

      expect(store.mySectors.sectors, [sector12]);
      expect(store.mySectors.currentId, isNull);
      expect(sectors.saved, isEmpty);
    });
  });
}
