// The providers wire each use case to the ports bound in the container: a
// call through a provider must reach the fakes given as overrides.
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override`, the type of a container's overrides.
import 'package:flutter_riverpod/misc.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/application/use_cases/choose_start_point.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/application/use_cases/find_imported_streets.dart';
import 'package:tournee_calendriers/application/use_cases/import_reference_area.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/move_streets_into_sector.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/corbeille.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../application/use_cases/street_fixtures.dart';
import '../domain/round/round_fixtures.dart'
    show cash, cheque, newRound, offered;
import '../domain/sector/my_sectors_fixtures.dart';
import '../domain/sector/sector_fixtures.dart'
    show
        campaign2026,
        gleizeCommune,
        villefrancheCommune,
        codeOf,
        csVillefranche,
        julieId,
        leaId,
        manuId,
        nameOf,
        number49,
        samId,
        team,
        sectorId;
import '../support/fakes/fake_address_directory.dart';
import '../support/fakes/fake_admin_status.dart';
import '../support/fakes/fake_commune_search.dart';
import '../support/fakes/fake_member_account.dart';
import '../support/fakes/fake_moved_streets_log.dart';
import '../support/fakes/fake_my_sectors_store.dart';
import '../support/fakes/fake_offline_map_store.dart';
import '../support/fakes/fake_open_round_store.dart';
import '../support/fakes/fake_pending_sync.dart';
import '../support/fakes/fake_phone_settings.dart';
import '../support/fakes/fake_ports.dart';
import '../support/fakes/fake_round_ledger.dart';
import '../support/fakes/fake_sector_directory.dart';
import '../support/fakes/fake_sector_downloads.dart';
import '../support/fakes/fake_sector_repository.dart';
import '../support/fakes/fake_server_connection.dart';
import '../support/fakes/fake_street_repository.dart';
import '../support/fakes/fake_street_shapes.dart';
import '../support/fakes/fake_street_view_preferences.dart';
import '../support/fakes/fake_streets_download.dart';
import '../support/geo_fixtures.dart';
import '../support/results.dart';
import '../support/scripted_random.dart';
import '../support/street_fixtures.dart';

void main() {
  late FakeStreetRepository streets;
  late FakeStreetRepository phoneStreets;
  late FakeMovedStreetsLog movedStreets;
  late FakeAddressDirectory directory;
  late FakeStreetShapes shapes;
  late FakeCommuneSearch communes;
  late FakeStreetViewPreferences preferences;
  late FakeMemberAccount account;
  late FakeMySectorsStore mySectors;
  late FakePhoneSettings settings;
  late FakeSectorDirectory sectorDirectory;
  late FakeSectorRepository sectors;
  late FakePendingSync pending;
  late FakeAdminStatus admins;
  late FakeOpenRoundStore rounds;
  late FakeRoundLedger ledger;
  late ProviderContainer container;

  /// Every port bound to the fakes, the member on the phone being
  /// [member].
  List<Override> overridesAs(MemberId member) => [
    streetRepositoryProvider.overrideWithValue(streets),
    phoneStreetRepositoryProvider.overrideWithValue(phoneStreets),
    movedStreetsLogProvider.overrideWithValue(movedStreets),
    pendingSyncProvider.overrideWithValue(pending),
    serverConnectionProvider.overrideWithValue(
      FakeServerConnection(offline: true),
    ),
    addressDirectoryProvider.overrideWithValue(directory),
    streetShapesProvider.overrideWithValue(shapes),
    communeSearchProvider.overrideWithValue(communes),
    clockProvider.overrideWithValue(FakeClock(twoPm)),
    idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
    identityProvider.overrideWithValue(FakeIdentity(member)),
    streetViewPreferencesProvider.overrideWithValue(preferences),
    memberAccountProvider.overrideWithValue(account),
    mySectorsStoreProvider.overrideWithValue(mySectors),
    phoneSettingsProvider.overrideWithValue(settings),
    sectorDirectoryProvider.overrideWithValue(sectorDirectory),
    sectorRepositoryProvider.overrideWithValue(sectors),
    adminStatusProvider.overrideWithValue(admins),
    openRoundStoreProvider.overrideWithValue(rounds),
    roundLedgerProvider.overrideWithValue(ledger),
    // The indexes of `2`…`7` in the alphabet: the code `234567`.
    randomProvider.overrideWithValue(ScriptedRandom([23, 24, 25, 26, 27, 28])),
  ];

  /// A container where Manu, the creator of the 49, uses the phone.
  ProviderContainer asManu() {
    final manusPhone = ProviderContainer(overrides: overridesAs(manuId));
    addTearDown(manusPhone.dispose);
    return manusPhone;
  }

  setUp(() {
    streets = repositoryWithLilas();
    // Rue Pierre Morin, kept on the phone since M1.
    phoneStreets = FakeStreetRepository([
      valueOf(
        Street.create(
          id: StreetId('morin'),
          name: 'Rue Pierre Morin',
          commune: villefranche,
          banId: BanStreetId('69264_1460'),
        ),
      ),
    ]);
    movedStreets = FakeMovedStreetsLog();
    directory = FakeAddressDirectory(
      communes: {
        '69264': Ok(
          CommuneStreets(
            commune: villefranche,
            streets: const [],
            skippedStreets: 0,
          ),
        ),
      },
    );
    shapes = FakeStreetShapes();
    communes = FakeCommuneSearch(
      answers: {
        'Villef': Ok([
          CommuneMatch(commune: villefranche, postcodes: const ['69400']),
        ]),
      },
    );
    preferences = FakeStreetViewPreferences([lilasId]);
    account = FakeMemberAccount(nextMember: MemberId('uid-lea'));
    mySectors = FakeMySectorsStore(
      MySectors.none.remember(sector49).remember(sector7),
    );
    settings = FakePhoneSettings(memberName: nameOf('Léa'));
    sectorDirectory = FakeSectorDirectory();
    sectors = FakeSectorRepository([team()]);
    pending = FakePendingSync(2);
    // The phone is an admin's, and Manu is one.
    admins = FakeAdminStatus(phoneIsAdmin: true, admins: [manuId]);
    rounds = FakeOpenRoundStore();
    ledger = FakeRoundLedger();
    // A ProviderContainer is what a ProviderScope holds, without widgets:
    // the overrides bind the ports to the fakes.
    container = ProviderContainer(overrides: overridesAs(lea));
  });

  tearDown(() => container.dispose());

  group('ports', () {
    final ports = <String, Provider<Object>>{
      'StreetRepository': streetRepositoryProvider,
      'AddressDirectory': addressDirectoryProvider,
      'CommuneSearch': communeSearchProvider,
      'StreetShapes': streetShapesProvider,
      'Clock': clockProvider,
      'IdGenerator': idGeneratorProvider,
      'IdentityProvider': identityProvider,
      'StreetViewPreferences': streetViewPreferencesProvider,
      'MemberAccount': memberAccountProvider,
      'MySectorsStore': mySectorsStoreProvider,
      'PhoneSettings': phoneSettingsProvider,
      'SectorDirectory': sectorDirectoryProvider,
      'SectorRepository': sectorRepositoryProvider,
      'phone StreetRepository': phoneStreetRepositoryProvider,
      'MovedStreetsLog': movedStreetsLogProvider,
      'PendingSync': pendingSyncProvider,
      'Random': randomProvider,
      'AdminStatus': adminStatusProvider,
      'StreetsDownload': streetsDownloadProvider,
      'OfflineMapStore': offlineMapStoreProvider,
      'SectorDownloads': sectorDownloadsProvider,
      'ServerConnection': serverConnectionProvider,
      'OpenRoundStore': openRoundStoreProvider,
      'RoundLedger': roundLedgerProvider,
    };
    ports.forEach((name, port) {
      test('should name $name when nobody bound it', () {
        final empty = ProviderContainer();
        addTearDown(empty.dispose);

        expect(
          () => empty.read(port),
          throwsA(predicate((Object error) => '$error'.contains(name))),
        );
      });
    });
  });

  group('use cases', () {
    test('should observe a street of the bound repository', () async {
      final street = await container.read(observeStreetProvider)(lilasId).first;

      expect(street, same(lilas));
    });

    test('should observe the streets of the bound repository', () async {
      final all = await container.read(observeStreetsProvider)().first;

      expect(all, [same(lilas)]);
    });

    test('should observe the streets the bound member covers', () async {
      valueOf(await container.read(takeStreetProvider)(lilasId));

      final streets = await container.read(observeMyStreetsProvider)().first;

      expect([for (final street in streets.mine) street.id], [lilasId]);
      expect(streets.others, isEmpty);
    });

    test('should set a detail of a house', () async {
      final change = valueOf(
        await container.read(setHouseDetailsProvider)(
          lilasId,
          n('7'),
          const StatusMark(VisitStatus.done),
        ),
      );

      expect(change.stamp, leaAtTwo);
      expect(streets.saved, hasLength(1));
    });

    test('should mark a door', () async {
      final change = valueOf(
        await container.read(markDwellingProvider)(
          lilasId,
          n('8'),
          rdc('02'),
          const StatusMark(VisitStatus.done),
        ),
      );

      expect(change.stamp, leaAtTwo);
    });

    test('should describe a building', () async {
      final change = valueOf(
        await container.read(describeBuildingProvider)(
          lilasId,
          n('8'),
          const BackToSingleHouse(),
        ),
      );

      expect(change.stamp, leaAtTwo);
    });

    test('should edit the numbers of a street', () async {
      valueOf(
        await container.read(editStreetNumbersProvider)(
          lilasId,
          const DeleteStreet(),
        ),
      );

      expect(streets[lilasId]!.deletion, leaAtTwo);
    });

    test('should undo a change', () async {
      final change = valueOf(
        await container.read(setHouseDetailsProvider)(
          lilasId,
          n('7'),
          const StatusMark(VisitStatus.done),
        ),
      );

      valueOf(await container.read(undoLastChangeProvider)(change));

      expect(houseOf(streets[lilasId]!, '7'), seven);
    });

    test('should take a street of the bound repository as the bound '
        'member', () async {
      valueOf(await container.read(takeStreetProvider)(lilasId));

      expect(streets[lilasId]!.assignees, {lea});
    });

    test('should release a street of the bound repository as the bound '
        'member', () async {
      valueOf(await container.read(takeStreetProvider)(lilasId));

      valueOf(await container.read(releaseStreetProvider)(lilasId));

      expect(streets[lilasId]!.assignees, isEmpty);
    });

    test('should look a street up in the bound directory and '
        'repository', () async {
      final found = valueOf(
        await container.read(lookUpStreetProvider)(
          FoundStreet(
            StreetMatch(
              id: lilas.banId!,
              name: lilas.name,
              commune: villefranche,
              position: townHallDoor,
            ),
          ),
        ),
      );

      expect((found as StreetOfTheSector).street, same(lilas));
    });

    test('should add a street from the map with the bound ids and '
        'member', () async {
      final street = valueOf(
        await container.read(addStreetFromMapProvider)(
          StreetNumbers(
            id: BanStreetId('69264_1460'),
            name: streetName('Rue Pierre Morin'),
            commune: villefranche,
            numbers: const [],
            invalidNumbers: 0,
            duplicateNumbers: 0,
          ),
          assignToMe: true,
        ),
      );

      expect(street.id, StreetId('street-1'));
      expect(street.assignees, {lea});
      expect(streets[StreetId('street-1')], same(street));
    });

    test('should look up the road of a street with the bound shapes', () async {
      final morinId = BanStreetId('69264_1460');
      valueOf(
        await container.read(lookUpStreetShapeProvider)(
          StreetToAdd(
            StreetMatch(
              id: morinId,
              name: streetName('Rue Pierre Morin'),
              commune: villefranche,
              position: townHallDoor,
            ),
            StreetNumbers(
              id: morinId,
              name: streetName('Rue Pierre Morin'),
              commune: villefranche,
              numbers: const [],
              invalidNumbers: 0,
              duplicateNumbers: 0,
            ),
          ),
        ),
      );

      expect(shapes.askedNames, ['Rue Pierre Morin']);
    });

    test('should fill the shape of a street with the bound shapes and '
        'repository', () async {
      final morin = valueOf(
        Street.create(
          id: StreetId('morin'),
          name: 'Rue Pierre Morin',
          commune: villefranche,
          houses: [House(number: n('1'), position: townHallDoor)],
        ),
      );
      await streets.add(morin);

      await container.read(fillStreetShapeProvider)(morin.id);

      expect(shapes.askedNames, ['Rue Pierre Morin']);
    });

    test('should add a street typed in by hand with the bound ids and '
        'member', () async {
      final street = await container.read(addManualStreetProvider)(
        name: streetName('Chemin des Vignes'),
        commune: villefranche,
        numbers: [n('1')],
        assignToMe: true,
      );

      expect(street.id, StreetId('street-1'));
      expect(street.assignees, {lea});
      expect(streets[StreetId('street-1')], same(street));
    });

    test('should search streets in the bound directory', () async {
      valueOf(
        await container.read(searchStreetProvider)(
          'morin',
          communes: [insee('69264')],
        ),
      );

      expect(directory.searchesAsked, [('morin', '69264')]);
    });

    test('should list the streets of a commune from the directory', () async {
      valueOf(await container.read(listCommuneStreetsProvider)(insee('69264')));

      expect(directory.communesAsked, ['69264']);
    });

    test('should import with the bound directory and ids', () async {
      final report = valueOf(
        await container.read(importReferenceAreaProvider)(insee('69264')),
      );

      expect(report, isA<ImportReport>());
      expect(report.commune, villefranche);
      expect(directory.communesAsked, ['69264']);
      expect(streets[StreetId('street-1')], isNull);
    });

    test('should search communes with the bound service', () async {
      final found = valueOf(
        await container.read(searchCommunesProvider)('Villef'),
      );

      expect(found.single.commune, villefranche);
      expect(communes.searched, ['Villef']);
    });

    test('should find the imported streets in the bound repository', () async {
      final imported = await container.read(findImportedStreetsProvider)([
        lilas.banId!,
      ]);

      expect(imported, {lilas.banId: ImportedStreetState.active});
    });

    test('should read « Masquer faits » from the bound preferences', () {
      expect(container.read(readHideDoneProvider)(lilasId), isTrue);
    });

    test('should save « Masquer faits » in the bound preferences', () async {
      await container.read(saveHideDoneProvider)(lilasId, hide: false);

      expect(preferences.writes, [(lilasId, false)]);
    });

    test('should read the member from the bound account', () {
      account.signedInMember = MemberId('uid-kept');

      expect(
        container.read(readSignedInMemberProvider)(),
        MemberId('uid-kept'),
      );
    });

    test('should sign in with the bound account', () async {
      final member = valueOf(await container.read(signInProvider)());

      expect(member, MemberId('uid-lea'));
      expect(account.signInCalls, 1);
    });

    test('should observe the sign-ins of the bound account', () async {
      final told = container.read(observeSignInProvider)().first;

      await account.signInIfNeeded();

      expect(await told, MemberId('uid-lea'));
    });

    test('should read the tournées of the bound store', () {
      expect(container.read(readMySectorsProvider)().sectors, [
        sector49,
        sector7,
      ]);
    });

    test('should observe the tournées of the bound store', () async {
      final next = container.read(observeMySectorsProvider)().first;
      await mySectors.save(MySectors.none);

      expect(await next, MySectors.none);
    });

    test('should open a tournée of the bound store', () async {
      valueOf(await container.read(openSectorProvider)(sector49.id));

      expect(mySectors.mySectors.current, sector49);
    });

    test('should watch a request in the bound directory as the bound '
        'account', () {
      account.signedInMember = MemberId('uid-kept');

      container.read(watchJoinRequestProvider)(sector7.id);

      expect(sectorDirectory.watched, [(sector7.id, MemberId('uid-kept'))]);
    });

    test('should settle a request in the bound store', () async {
      await container.read(settleJoinRequestProvider)(
        sector7.id,
        MemberStatus.active,
      );

      expect(mySectors.mySectors.find(sector7.id)!.isPending, isFalse);
    });

    test('should watch a membership in the bound directory as the bound '
        'account', () {
      account.signedInMember = MemberId('uid-kept');

      container.read(watchMembershipProvider)(sector49);

      expect(sectorDirectory.memberships, [(sector49, MemberId('uid-kept'))]);
    });

    test('should watch the own name in the bound directory as the bound '
        'account', () {
      account.signedInMember = MemberId('uid-kept');

      container.read(watchOwnNameProvider)(sector49.id);

      expect(sectorDirectory.ownNames, [(sector49.id, MemberId('uid-kept'))]);
    });

    test('should forget a lost tournée in the bound store', () async {
      await container.read(forgetLostSectorProvider)(
        sector49.id,
        SectorLoss.removed,
      );

      expect(mySectors.mySectors.find(sector49.id), isNull);
    });

    test('should read the bound settings', () {
      expect(container.read(readPhoneSettingsProvider)().name, nameOf('Léa'));
    });

    test('should change the name in the bound settings and in the bound '
        'tournées, as the bound member', () async {
      await asManu().read(changeMemberNameProvider)('Emmanuel');

      expect(settings.names, [nameOf('Emmanuel')]);
      expect(sectors[sectorId]!.memberOf(manuId)!.name, nameOf('Emmanuel'));
    });

    test('should catch up the name of the bound settings in the bound '
        'tournées, as the bound member', () async {
      await asManu().read(catchUpMemberNameProvider)(sectorId, nameOf('Manu'));

      expect(sectors[sectorId]!.memberOf(manuId)!.name, nameOf('Léa'));
    });

    test('should choose the theme in the bound settings', () async {
      await container.read(chooseThemeProvider)(ThemeChoice.dark);

      expect(settings.themes, [ThemeChoice.dark]);
    });

    test('should observe the Corbeille of the bound repository', () async {
      final (removed, change) = valueOf(
        lilas.removeNumber(n('7'), by: lea, at: twoPm),
      );
      await streets.save(removed, change);

      final items = await container.read(observeCorbeilleProvider)().first;

      expect((items.single as RemovedNumber).number, n('7'));
    });

    test('should observe what the bound pending sync has not sent', () async {
      final streets = await container.read(observePendingSyncProvider)().first;

      expect(streets, 2);
    });

    test('should observe whether the bound connection is offline', () async {
      final offline = await container.read(observeOfflineProvider)().first;

      expect(offline, isTrue);
    });

    test('should observe the team in the bound repository', () async {
      final sector = await container.read(observeTeamProvider)(sectorId).first;

      expect(sector, same(sectors[sectorId]));
    });

    test('should observe the communes in the bound repository', () async {
      sectors.put(team(communes: [villefrancheCommune]));

      final communes = await container
          .read(observeSectorCommunesProvider)(sectorId)
          .first;

      expect(communes, [villefrancheCommune]);
    });

    test('should add a commune as the bound member', () async {
      final change = valueOf(
        await asManu().read(addCommuneProvider)(sectorId, gleizeCommune),
      );

      expect(change.commune, gleizeCommune);
      expect(sectors[sectorId]!.communes, [gleizeCommune]);
    });

    test('should remove a commune as the bound member', () async {
      sectors.put(team(communes: [villefrancheCommune, gleizeCommune]));

      final change = valueOf(
        await asManu().read(removeCommuneProvider)(
          sectorId,
          villefrancheCommune.inseeCode,
        ),
      );

      expect(change.commune, villefrancheCommune);
    });

    test('should read the bound member', () {
      expect(container.read(readCurrentMemberProvider)(), lea);
    });

    test('should accept a request with the bound clock and member', () async {
      final manusPhone = asManu();

      final change = valueOf(
        await manusPhone.read(acceptMemberProvider)(sectorId, julieId),
      );

      expect(change.member.acceptance!.by, manuId);
      expect(change.member.acceptance!.at, twoPm);
    });

    test('should refuse a request as the bound member', () async {
      final change = valueOf(
        await asManu().read(refuseMemberProvider)(sectorId, julieId),
      );

      expect(change, isA<MemberRefused>());
    });

    test('should remove a member as the bound member', () async {
      final change = valueOf(
        await asManu().read(removeMemberProvider)(sectorId, leaId),
      );

      expect(change, isA<MemberRemoved>());
    });

    test('should leave the tournée and forget it in the bound store', () async {
      await mySectors.save(MySectors.none.remember(sector49));
      final phone = ProviderContainer(overrides: overridesAs(leaId));
      addTearDown(phone.dispose);

      valueOf(await phone.read(leaveSectorProvider)(sectorId));

      expect(mySectors.mySectors.sectors, isEmpty);
    });

    test('should draw a new code from the bound random source', () async {
      final code = valueOf(
        await asManu().read(regenerateJoinCodeProvider)(sectorId),
      );

      expect(code, codeOf('234567'));
    });

    test('should let an admin join with the bound name, clock and '
        'store', () async {
      final samsPhone = ProviderContainer(overrides: overridesAs(samId));
      addTearDown(samsPhone.dispose);
      await mySectors.save(
        MySectors.none.remember(
          summaryOf('t49', 49, status: MemberStatus.visiting),
        ),
      );

      final change = valueOf(
        await samsPhone.read(joinAsAdminProvider)(sectorId),
      );

      expect(change.member.name, nameOf('Léa'));
      expect(change.member.requestedAt, twoPm);
      expect(mySectors.mySectors.find(sectorId), sector49);
    });

    test('should forget a visited tournée in the bound store', () async {
      await container.read(forgetVisitedSectorProvider)(sector49.id);

      expect(mySectors.mySectors.find(sector49.id), isNull);
    });

    test('should follow the bound admin status', () async {
      expect(await container.read(observeAdminStatusProvider)().first, isTrue);
    });

    test('should ask the bound admin status about a member', () async {
      expect(await container.read(isMemberAdminProvider)(manuId), isTrue);
      expect(admins.asked, [manuId]);
    });

    test('should list every tournée from the bound directory as the bound '
        'account', () async {
      valueOf(await container.read(listAllSectorsProvider)());

      expect(sectorDirectory.allAsked, [MemberId('uid-lea')]);
    });

    test('should open a tournée as an admin in the bound store', () async {
      await container.read(openAsAdminProvider)(
        SectorOverview(
          id: sector12.id,
          number: sector12.number,
          centre: csVillefranche,
          campaign: campaign2026,
          activeMembers: 1,
          pendingRequests: 0,
          callerIsActive: true,
        ),
      );

      expect(mySectors.mySectors.current, sector12);
    });

    test(
      'should delete the tournée and forget it in the bound store',
      () async {
        valueOf(await asManu().read(deleteSectorProvider)(sectorId));

        expect(sectors.deleted, hasLength(1));
        expect(mySectors.mySectors.find(sectorId), isNull);
      },
    );

    test(
      'should count the phone streets for the bound tournées and member',
      () async {
        // Léa of the team (`uid-lea`): an active member of the 49.
        final leasPhone = ProviderContainer(overrides: overridesAs(leaId));
        addTearDown(leasPhone.dispose);

        expect(await leasPhone.read(countStreetsToMoveProvider)(sectorId), 1);
      },
    );

    test(
      'should move the phone streets into the bound repository and log',
      () async {
        final moved = await container.read(moveStreetsIntoSectorProvider)(
          sectorId,
        );

        expect(moved, const StreetsMoved(moved: 1, alreadyThere: 0));
        expect(
          streets[StreetId('morin')]?.name,
          streetName('Rue Pierre Morin'),
        );
        expect(movedStreets.remembered, [sectorId]);
      },
    );

    test(
      'should choose where to start from the bound store and phone streets',
      () async {
        // The phone holds Rue Pierre Morin: the start screen.
        expect(
          await container.read(chooseStartPointProvider)(),
          const StartOnStreets(),
        );
      },
    );

    test('should list the centres of the bound directory', () async {
      sectorDirectory.centres = [csVillefranche];

      expect(valueOf(await container.read(listRescueCentresProvider)()), [
        csVillefranche,
      ]);
    });

    test('should check a number in the bound directory', () async {
      sectorDirectory.taken.add((csVillefranche.key, number49));

      expect(
        valueOf(
          await container.read(checkSectorTakenProvider)(
            csVillefranche,
            number49,
          ),
        ),
        isTrue,
      );
    });

    test('should create with the bound repository, account, store, clock, ids '
        'and random source', () async {
      final created = valueOf(
        await container.read(createSectorProvider)(
          centre: csVillefranche,
          number: number49,
          campaign: campaign2026,
          creatorName: nameOf('Léa'),
          communes: [villefrancheCommune],
        ),
      );

      expect(sectors.added, [created]);
      expect(created.communes, [villefrancheCommune]);
      expect(created.id.value, 'street-1');
      expect(created.createdBy, MemberId('uid-lea'));
      expect(created.createdAt, twoPm);
      expect(created.joinCode, codeOf('234567'));
      expect(mySectors.mySectors.currentId, created.id);
    });

    test('should preview a code in the bound directory', () async {
      expect(
        failureOf(await container.read(previewJoinProvider)(codeOf('234567'))),
        JoinFailure.unknownCode,
      );
      expect(sectorDirectory.previewed, [codeOf('234567')]);
    });

    test('should request to join through the bound directory, account, store '
        'and clock', () async {
      final preview = JoinPreview(
        code: codeOf('234567'),
        sectorId: SectorId('t12'),
        number: sector12.number,
        centre: csVillefranche,
        campaign: campaign2026,
      );

      valueOf(
        await container.read(requestToJoinProvider)(preview, nameOf('Léa')),
      );

      final (_, request) = sectorDirectory.sent.single;
      expect(request.id, MemberId('uid-lea'));
      expect(request.requestedAt, twoPm);
      expect(mySectors.mySectors.find(SectorId('t12'))?.isPending, isTrue);
    });

    test(
      'should cancel a request through the bound directory and store',
      () async {
        account.signedInMember = MemberId('uid-lea');

        await container.read(cancelJoinRequestProvider)(sector7.id);

        expect(sectorDirectory.cancelled, [(sector7.id, MemberId('uid-lea'))]);
        expect(mySectors.mySectors.find(sector7.id), isNull);
      },
    );
  });

  group('tournées', () {
    /// The 49 open, a tournée of it on.
    void roundOnInThe49() {
      mySectors.mySectors = valueOf(mySectors.mySectors.open(sector49.id));
      rounds.openRound = newRound();
    }

    test('should start a tournée in the bound store with the bound clock '
        'and ids', () async {
      mySectors.mySectors = valueOf(mySectors.mySectors.open(sector49.id));

      final round = valueOf(await container.read(startRoundProvider)());

      expect(round.id.value, 'street-1');
      expect(round.sector, sector49.id);
      expect(round.startedAt, twoPm);
      expect(rounds.openRound, round);
    });

    test('should watch the tournée of the bound store', () async {
      roundOnInThe49();

      final round = await container
          .read(watchOpenRoundProvider)(sector49.id)
          .first;

      expect(round, newRound());
    });

    test('should add, change and remove a don in the bound store', () async {
      roundOnInThe49();

      valueOf(await container.read(addDonationProvider)(cash(1000)));
      valueOf(await container.read(addDonationProvider)(offered));
      valueOf(await container.read(changeDonationProvider)(0, cheque(2000)));
      valueOf(await container.read(removeDonationProvider)(1));

      expect(rounds.openRound!.donations, [cheque(2000)]);
    });

    test('should validate into the bound ledger at the bound time', () async {
      roundOnInThe49();

      final summary = valueOf(await container.read(validateRoundProvider)());

      expect(summary.endedAt, twoPm);
      expect(ledger.recorded.single.$3, summary);
      expect(rounds.openRound, isNull);
    });

    test(
      'should count a house and a door in the bound store, and an undo',
      () async {
        roundOnInThe49();

        final house = valueOf(
          await container.read(setHouseDetailsProvider)(
            lilasId,
            n('7'),
            const StatusMark(VisitStatus.done),
          ),
        );
        valueOf(
          await container.read(markDwellingProvider)(
            lilasId,
            n('8'),
            rdc('02'),
            const StatusMark(VisitStatus.refused),
          ),
        );
        valueOf(await container.read(undoLastChangeProvider)(house));

        expect(rounds.saves.map((round) => round.housesVisited), [1, 2, 1]);
      },
    );
  });

  group('offline download', () {
    late FakeOfflineMapStore maps;
    late FakeSectorDownloads downloads;
    late ProviderContainer offline;

    setUp(() {
      maps = FakeOfflineMapStore([
        OfflineMapRegion(
          id: 40,
          sector: sector49.id,
          bounds: GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)])!,
        ),
      ]);
      downloads = FakeSectorDownloads();
      offline = ProviderContainer(
        overrides: [
          ...overridesAs(lea),
          offlineMapStoreProvider.overrideWithValue(maps),
          sectorDownloadsProvider.overrideWithValue(downloads),
          streetsDownloadProvider.overrideWithValue(FakeStreetsDownload()),
        ],
      );
      addTearDown(offline.dispose);
    });

    test('should observe the downloads of the bound store', () async {
      expect(
        await offline.read(observeSectorDownloadsProvider)().first,
        isEmpty,
      );
    });

    test('should delete a download through the bound store and map', () async {
      await offline.read(deleteSectorDownloadProvider)(sector49.id);

      expect(maps.log, ['delete 40']);
    });
  });
}
