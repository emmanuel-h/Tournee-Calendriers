import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/shared/recent_time.dart';
import 'package:tournee_calendriers/presentation/team/team_notifier.dart';
import 'package:tournee_calendriers/presentation/team/team_state.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_cache_reset.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../../support/scripted_random.dart';

/// Gleizé as the commune search suggests it.
final _gleizeOption = CommuneOption.of(
  CommuneMatch(
    commune: gleizeCommune.commune,
    postcodes: const ['69400'],
    centre: gleizeCommune.centre,
  ),
);

/// Two minutes after Julie asked to join.
final twoMinutesLater = DateTime.utc(2026, 11, 2, 8, 14);

/// The indexes of `2`…`7` in the code alphabet: the code `234567`.
const draws234567 = [23, 24, 25, 26, 27, 28];

void main() {
  late FakeSectorRepository sectors;
  late FakeMySectorsStore store;
  late FakeAdminStatus admins;

  /// The phone of [member], with the 49 open (or [mine]). Manu and Sam are
  /// admins of the app; the phone is an admin's when [member] is one of
  /// them, unless [admin] says otherwise.
  ProviderContainer phoneOf(
    MemberId member, {
    MySectors? mine,
    bool? admin,
    FakePhoneSettings? settings,
  }) {
    admins = FakeAdminStatus(
      phoneIsAdmin: admin ?? (member == manuId || member == samId),
      admins: [manuId, samId],
    );
    sectors = FakeSectorRepository([team()]);
    store = FakeMySectorsStore(
      mine ??
          valueOf(
            MySectors.none
                .remember(sector49)
                .remember(sector12)
                .open(sector49.id),
          ),
    );
    final container = ProviderContainer(
      overrides: [
        sectorRepositoryProvider.overrideWithValue(sectors),
        mySectorsStoreProvider.overrideWithValue(store),
        phoneCacheResetProvider.overrideWithValue(FakePhoneCacheReset()),
        identityProvider.overrideWithValue(FakeIdentity(member)),
        clockProvider.overrideWithValue(FakeClock(twoMinutesLater)),
        randomProvider.overrideWithValue(ScriptedRandom(draws234567)),
        adminStatusProvider.overrideWithValue(admins),
        phoneSettingsProvider.overrideWithValue(
          settings ?? FakePhoneSettings(memberName: nameOf('Sam')),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// The team as shown once the repository has answered.
  Future<TeamShown> shown(ProviderContainer container) async {
    container.listen(teamProvider, (_, _) {});
    await pumpEventQueue();
    return container.read(teamProvider) as TeamShown;
  }

  group('state', () {
    test('should have no team when no tournée is open', () {
      final container = phoneOf(
        manuId,
        mine: MySectors.none.remember(sector49),
      );

      final state = container.read(teamProvider);

      expect(state, isA<NoTeam>());
      expect(state.waitingRequests, 0);
    });

    test('should be loading until the tournée is read', () {
      final container = phoneOf(manuId);

      final state = container.read(teamProvider);

      expect(state, isA<TeamLoading>());
      expect(state.waitingRequests, 0);
    });

    test('should show the tournée, its code, the requests and the members '
        'as an admin in the team sees them', () async {
      final team = await shown(phoneOf(manuId));

      expect(team.number, 49);
      expect(team.centre, 'CS Villefranche');
      expect(team.campaign, 2026);
      expect(team.code, 'K7P-2QX');
      expect(team.qrData, 'K7P2QX');
      expect(team.iAmAdmin, isTrue);
      expect(team.iAmIn, isTrue);
      expect(team.requests, [
        RequestRow(id: julieId, name: 'Julie', asked: const MinutesAgo(2)),
      ]);
      expect(team.waitingRequests, 1);
      expect(team.members, [
        MemberRow(
          id: manuId,
          name: 'Manu',
          isMe: true,
          isAdmin: true,
          canRemove: false,
        ),
        MemberRow(
          id: leaId,
          name: 'Léa',
          isMe: false,
          isAdmin: false,
          canRemove: true,
        ),
      ]);
    });

    test('should offer an admin\'s commands to admins only, and label the '
        'admins', () async {
      final team = await shown(phoneOf(leaId));

      expect(team.iAmAdmin, isFalse);
      expect(team.iAmIn, isTrue);
      expect(team.members, [
        MemberRow(
          id: manuId,
          name: 'Manu',
          isMe: false,
          isAdmin: true,
          canRemove: false,
        ),
        MemberRow(
          id: leaId,
          name: 'Léa',
          isMe: true,
          isAdmin: false,
          canRemove: false,
        ),
      ]);
    });

    test('should ask once whether each other member is an admin', () async {
      // The phone knows about itself already (`adminProvider`).
      final container = phoneOf(leaId);
      await shown(container);

      sectors.put(team(members: [manu, lea]));
      await pumpEventQueue();

      expect(admins.asked, [manuId]);
    });

    test('should show an admin outside the team as a visitor, not among '
        'the members', () async {
      final team = await shown(phoneOf(samId));

      expect(team.iAmAdmin, isTrue);
      expect(team.iAmIn, isFalse);
      expect(team.members.map((member) => member.id), [manuId, leaId]);
      expect(team.members.every((member) => member.canRemove), isTrue);
    });

    test('should take the admin powers away when the phone stops being an '
        'admin', () async {
      final container = phoneOf(manuId);
      await shown(container);

      admins.phoneIsAdmin = false;
      await pumpEventQueue();

      final state = container.read(teamProvider) as TeamShown;
      expect(state.iAmAdmin, isFalse);
      expect(state.members.first.canRemove, isFalse);
    });

    test('should name a member of the team, and nobody else', () async {
      final team = await shown(phoneOf(leaId));

      expect(team.nameOf(manuId), 'Manu');
      expect(team.nameOf(leaId), 'Léa');
      expect(team.nameOf(julieId), 'Julie');
      expect(team.nameOf(paulId), isNull);
    });

    test('should follow the team when it changes', () async {
      final container = phoneOf(manuId);
      await shown(container);

      sectors.put(team(members: [manu, lea]));
      await pumpEventQueue();

      final state = container.read(teamProvider) as TeamShown;
      expect(state.requests, isEmpty);
      expect(state.waitingRequests, 0);
    });

    test('should be unavailable once the tournée cannot be read', () async {
      final container = phoneOf(manuId);
      await shown(container);

      sectors.lose(sectorId);
      await pumpEventQueue();

      expect(container.read(teamProvider), isA<TeamUnavailable>());
      expect(container.read(teamProvider).waitingRequests, 0);
    });

    test('should be unavailable when the tournée cannot be followed', () async {
      final container = phoneOf(manuId);
      sectors.watchError = StateError('no access');
      container.listen(teamProvider, (_, _) {});
      await pumpEventQueue();

      expect(container.read(teamProvider), isA<TeamUnavailable>());
    });

    test('should follow another tournée when it is opened', () async {
      final container = phoneOf(manuId);
      await shown(container);

      await container.read(mySectorsProvider.notifier).open(sector12.id);
      await pumpEventQueue();

      // The fake knows only the 49.
      expect(container.read(teamProvider), isA<TeamUnavailable>());
    });
  });

  group('communes', () {
    test('should list the communes, each removable by a member when there '
        'are several', () async {
      final container = phoneOf(leaId);
      sectors.put(team(communes: [villefrancheCommune, gleizeCommune]));

      final shownTeam = await shown(container);

      expect(shownTeam.canPrepare, isTrue);
      expect(shownTeam.communes, [
        CommuneRow(
          inseeCode: villefrancheCommune.inseeCode,
          name: 'Villefranche-sur-Saône',
          removable: true,
        ),
        CommuneRow(
          inseeCode: gleizeCommune.inseeCode,
          name: 'Gleizé',
          removable: true,
        ),
      ]);
    });

    test('should not let the last commune be removed', () async {
      final container = phoneOf(leaId);
      sectors.put(team(communes: [villefrancheCommune]));

      final shownTeam = await shown(container);

      expect(shownTeam.communes.single.removable, isFalse);
    });

    test('should list none for a tournée created before the communes, and '
        'still let one be added', () async {
      final shownTeam = await shown(phoneOf(leaId));

      expect(shownTeam.communes, isEmpty);
      expect(shownTeam.canPrepare, isTrue);
    });

    test('should let an admin outside the team change them', () async {
      final container = phoneOf(samId);
      sectors.put(team(communes: [villefrancheCommune, gleizeCommune]));

      final shownTeam = await shown(container);

      expect(shownTeam.canPrepare, isTrue);
      expect(shownTeam.communes.first.removable, isTrue);
    });

    test('should not let a member still pending change them', () async {
      final container = phoneOf(julieId);
      sectors.put(team(communes: [villefrancheCommune, gleizeCommune]));

      final shownTeam = await shown(container);

      expect(shownTeam.canPrepare, isFalse);
      expect(shownTeam.communes.first.removable, isFalse);
    });

    test('should add the commune picked', () async {
      final container = phoneOf(leaId);
      sectors.put(team(communes: [villefrancheCommune]));
      await shown(container);

      final failure = await container
          .read(teamProvider.notifier)
          .addCommune(_gleizeOption);
      await pumpEventQueue();

      expect(failure, isNull);
      expect(
        sectors.saved.single.$2,
        CommuneAdded(sectorId: sectorId, commune: gleizeCommune),
      );
      final state = container.read(teamProvider) as TeamShown;
      expect(state.communes.map((commune) => commune.name), [
        'Villefranche-sur-Saône',
        'Gleizé',
      ]);
    });

    test('should tell a commune is already in the tournée', () async {
      final container = phoneOf(leaId);
      sectors.put(team(communes: [gleizeCommune]));
      await shown(container);

      expect(
        await container.read(teamProvider.notifier).addCommune(_gleizeOption),
        TeamActionFailure.communeAlreadyIn,
      );
    });

    test('should tell the tournée covers as many communes as it may', () async {
      final container = phoneOf(leaId);
      sectors.put(
        team(
          communes: [
            for (var i = 1; i <= Sector.maxCommunes; i++)
              SectorCommune(
                commune: valueOf(
                  Commune.create(
                    inseeCode: '69${'$i'.padLeft(3, '0')}',
                    name: 'Commune $i',
                  ),
                ),
              ),
          ],
        ),
      );
      await shown(container);

      expect(
        await container.read(teamProvider.notifier).addCommune(_gleizeOption),
        TeamActionFailure.tooManyCommunes,
      );
    });

    test('should remove the commune of the ✕', () async {
      final container = phoneOf(leaId);
      sectors.put(team(communes: [villefrancheCommune, gleizeCommune]));
      await shown(container);

      final failure = await container
          .read(teamProvider.notifier)
          .removeCommune(villefrancheCommune.inseeCode);

      expect(failure, isNull);
      expect(
        sectors.saved.single.$2,
        CommuneRemoved(sectorId: sectorId, commune: villefrancheCommune),
      );
    });

    test('should tell the team changed when the last commune is '
        'removed meanwhile', () async {
      final container = phoneOf(leaId);
      sectors.put(team(communes: [villefrancheCommune]));
      await shown(container);

      expect(
        await container
            .read(teamProvider.notifier)
            .removeCommune(villefrancheCommune.inseeCode),
        TeamActionFailure.teamChanged,
      );
    });

    test('should compare communes by value', () {
      CommuneRow row({String name = 'Gleizé', bool removable = true}) =>
          CommuneRow(
            inseeCode: gleizeCommune.inseeCode,
            name: name,
            removable: removable,
          );

      expect(row(), row());
      expect(row().hashCode, row().hashCode);
      expect(row(), isNot(row(name: 'Gleize')));
      expect(row(), isNot(row(removable: false)));
      expect(
        row(),
        isNot(
          CommuneRow(
            inseeCode: villefrancheCommune.inseeCode,
            name: 'Gleizé',
            removable: true,
          ),
        ),
      );
    });
  });

  group('row equality', () {
    test('should compare requests by value', () {
      final row = RequestRow(
        id: julieId,
        name: 'Julie',
        asked: const MinutesAgo(2),
      );
      final same = RequestRow(
        id: julieId,
        name: 'Julie',
        asked: const MinutesAgo(2),
      );

      expect(row, same);
      expect(row.hashCode, same.hashCode);
      expect(
        row,
        isNot(
          RequestRow(id: paulId, name: 'Julie', asked: const MinutesAgo(2)),
        ),
      );
      expect(
        row,
        isNot(
          RequestRow(id: julieId, name: 'Paul', asked: const MinutesAgo(2)),
        ),
      );
      expect(
        row,
        isNot(RequestRow(id: julieId, name: 'Julie', asked: const JustNow())),
      );
    });

    test('should compare members by value', () {
      MemberRow row({
        MemberId? id,
        String name = 'Léa',
        bool isMe = false,
        bool isAdmin = false,
        bool canRemove = true,
      }) => MemberRow(
        id: id ?? leaId,
        name: name,
        isMe: isMe,
        isAdmin: isAdmin,
        canRemove: canRemove,
      );

      expect(row(), row());
      expect(row().hashCode, row().hashCode);
      expect(row(id: paulId), isNot(row()));
      expect(row(name: 'Paul'), isNot(row()));
      expect(row(isMe: true), isNot(row()));
      expect(row(isAdmin: true), isNot(row()));
      expect(row(canRemove: false), isNot(row()));
    });
  });

  group('commands', () {
    test('should accept a request as the member on the phone', () async {
      final container = phoneOf(leaId);
      await shown(container);

      final failure = await container
          .read(teamProvider.notifier)
          .accept(julieId);
      await pumpEventQueue();

      expect(failure, isNull);
      final (_, change) = sectors.saved.single;
      expect((change as MemberAccepted).member.acceptance!.by, leaId);
      final state = container.read(teamProvider) as TeamShown;
      expect(state.requests, isEmpty);
      expect(state.members.map((member) => member.name), [
        'Manu',
        'Léa',
        'Julie',
      ]);
    });

    test('should tell the team changed when the request was already '
        'answered', () async {
      final container = phoneOf(leaId);
      await shown(container);
      sectors.put(team(members: [manu, lea]));

      final failure = await container
          .read(teamProvider.notifier)
          .accept(julieId);

      expect(failure, TeamActionFailure.teamChanged);
    });

    test('should refuse a request', () async {
      final container = phoneOf(leaId);
      await shown(container);

      final failure = await container
          .read(teamProvider.notifier)
          .refuse(julieId);

      expect(failure, isNull);
      expect(sectors.saved.single.$2, isA<MemberRefused>());
    });

    test('should remove a member', () async {
      final container = phoneOf(manuId);
      await shown(container);

      final failure = await container.read(teamProvider.notifier).remove(leaId);

      expect(failure, isNull);
      expect(sectors.saved.single.$2, isA<MemberRemoved>());
    });

    test('should show the new code once drawn', () async {
      final container = phoneOf(manuId);
      await shown(container);

      final failure = await container
          .read(teamProvider.notifier)
          .regenerateCode();
      await pumpEventQueue();

      expect(failure, isNull);
      final state = container.read(teamProvider) as TeamShown;
      expect(state.code, '234-567');
      expect(state.qrData, '234567');
    });

    test('should tell a new code needs the network', () async {
      final container = phoneOf(manuId);
      await shown(container);
      sectors.offline = true;

      final failure = await container
          .read(teamProvider.notifier)
          .regenerateCode();

      expect(failure, TeamActionFailure.offline);
    });

    test('should tell the phone is no longer an admin\'s when the server '
        'refuses a new code', () async {
      final container = phoneOf(manuId);
      await shown(container);
      sectors.notAdmin = true;

      final failure = await container
          .read(teamProvider.notifier)
          .regenerateCode();

      expect(failure, TeamActionFailure.notAdmin);
    });

    test('should tell the phone is no longer an admin\'s when it learnt it '
        'before the tournée refused the command', () async {
      // The admin status already says no, the screen still shows « Retirer »:
      // the tournée refuses it with `notAdmin`, not as a team change.
      final container = phoneOf(manuId, admin: false);
      await shown(container);

      final failure = await container.read(teamProvider.notifier).remove(leaId);

      expect(failure, TeamActionFailure.notAdmin);
      expect(sectors.saved, isEmpty);
    });

    test('should leave the tournée, which the phone forgets', () async {
      final container = phoneOf(leaId);
      await shown(container);

      final failure = await container.read(teamProvider.notifier).leave();
      await pumpEventQueue();

      expect(failure, isNull);
      expect(store.mySectors.find(sectorId), isNull);
      expect(container.read(teamProvider), isA<NoTeam>());
    });

    test('should delete the tournée, which the phone forgets', () async {
      final container = phoneOf(manuId);
      await shown(container);

      final failure = await container
          .read(teamProvider.notifier)
          .deleteSector();
      await pumpEventQueue();

      expect(failure, isNull);
      expect(sectors.deleted, hasLength(1));
      expect(container.read(teamProvider), isA<NoTeam>());
    });

    test('should tell deleting needs the network', () async {
      final container = phoneOf(manuId);
      await shown(container);
      sectors.offline = true;

      final failure = await container
          .read(teamProvider.notifier)
          .deleteSector();

      expect(failure, TeamActionFailure.offline);
      expect(store.mySectors.find(sectorId), isNotNull);
    });

    test('should tell the phone is no longer an admin\'s when the server '
        'refuses deleting', () async {
      final container = phoneOf(manuId);
      await shown(container);
      sectors.notAdmin = true;

      final failure = await container
          .read(teamProvider.notifier)
          .deleteSector();

      expect(failure, TeamActionFailure.notAdmin);
      expect(store.mySectors.find(sectorId), isNotNull);
    });

    test('should tell the team changed when the tournée cannot be read any '
        'more', () async {
      final container = phoneOf(leaId);
      await shown(container);
      sectors.lose(sectorId);

      final failure = await container.read(teamProvider.notifier).leave();

      expect(failure, TeamActionFailure.teamChanged);
    });

    test('should tell the team changed when no tournée is open', () async {
      final container = phoneOf(
        manuId,
        mine: MySectors.none.remember(sector49),
      );

      final notifier = container.read(teamProvider.notifier);

      expect(await notifier.accept(julieId), TeamActionFailure.teamChanged);
      expect(await notifier.refuse(julieId), TeamActionFailure.teamChanged);
      expect(await notifier.remove(leaId), TeamActionFailure.teamChanged);
      expect(await notifier.regenerateCode(), TeamActionFailure.teamChanged);
      expect(await notifier.leave(), TeamActionFailure.teamChanged);
      expect(await notifier.deleteSector(), TeamActionFailure.teamChanged);
      expect(await notifier.joinAsAdmin(), TeamActionFailure.teamChanged);
      await notifier.forgetVisit();
      expect(sectors.saved, isEmpty);
      expect(sectors.deleted, isEmpty);
      expect(store.saves, isEmpty);
    });

    group('as an admin visiting', () {
      MySectors visiting() => valueOf(
        MySectors.none
            .remember(summaryOf('t49', 49, status: MemberStatus.visiting))
            .open(sectorId),
      );

      test('should join the team at once', () async {
        final container = phoneOf(samId, mine: visiting());
        await shown(container);

        final failure = await container
            .read(teamProvider.notifier)
            .joinAsAdmin();
        await pumpEventQueue();

        expect(failure, isNull);
        expect(sectors.saved.single.$2, isA<AdminJoined>());
        expect(store.mySectors.current, sector49);
        final state = container.read(teamProvider) as TeamShown;
        expect(state.iAmIn, isTrue);
      });

      test('should tell joining needs the network', () async {
        final container = phoneOf(samId, mine: visiting());
        await shown(container);
        sectors.offline = true;

        final failure = await container
            .read(teamProvider.notifier)
            .joinAsAdmin();

        expect(failure, TeamActionFailure.offline);
      });

      test('should tell the phone is no longer an admin\'s when the server '
          'refuses joining', () async {
        final container = phoneOf(samId, mine: visiting());
        await shown(container);
        sectors.notAdmin = true;

        final failure = await container
            .read(teamProvider.notifier)
            .joinAsAdmin();

        expect(failure, TeamActionFailure.notAdmin);
        expect(store.mySectors.current!.isVisiting, isTrue);
      });

      test('should tell joining needs a first name', () async {
        final container = phoneOf(
          samId,
          mine: visiting(),
          settings: FakePhoneSettings(),
        );
        await shown(container);

        final failure = await container
            .read(teamProvider.notifier)
            .joinAsAdmin();

        expect(failure, TeamActionFailure.noName);
      });

      test('should forget the tournée on the phone only', () async {
        final container = phoneOf(samId, mine: visiting());
        await shown(container);

        await container.read(teamProvider.notifier).forgetVisit();
        await pumpEventQueue();

        expect(store.mySectors.find(sectorId), isNull);
        expect(sectors.saved, isEmpty);
        expect(container.read(teamProvider), isA<NoTeam>());
      });
    });
  });
}
