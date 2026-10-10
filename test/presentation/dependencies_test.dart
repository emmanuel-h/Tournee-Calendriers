// The providers wire each use case to the ports bound in the container: a
// call through a provider must reach the fakes given as overrides.
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override`, the type of a container's overrides.
import 'package:flutter_riverpod/misc.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/application/use_cases/find_imported_streets.dart';
import 'package:tournee_calendriers/application/use_cases/import_reference_area.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/move_streets_into_tournee.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/corbeille.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../application/use_cases/street_fixtures.dart';
import '../domain/tournee/my_tournees_fixtures.dart';
import '../domain/tournee/tournee_fixtures.dart'
    show codeOf, julieId, leaId, manuId, nameOf, team, tourneeId;
import '../support/fakes/fake_address_directory.dart';
import '../support/fakes/fake_commune_search.dart';
import '../support/fakes/fake_member_account.dart';
import '../support/fakes/fake_moved_streets_log.dart';
import '../support/fakes/fake_my_tournees_store.dart';
import '../support/fakes/fake_pending_sync.dart';
import '../support/fakes/fake_phone_settings.dart';
import '../support/fakes/fake_ports.dart';
import '../support/fakes/fake_street_repository.dart';
import '../support/fakes/fake_street_view_preferences.dart';
import '../support/fakes/fake_tournee_directory.dart';
import '../support/fakes/fake_tournee_repository.dart';
import '../support/results.dart';
import '../support/scripted_random.dart';
import '../support/street_fixtures.dart';

void main() {
  late FakeStreetRepository streets;
  late FakeStreetRepository phoneStreets;
  late FakeMovedStreetsLog movedStreets;
  late FakeAddressDirectory directory;
  late FakeCommuneSearch communes;
  late FakeStreetViewPreferences preferences;
  late FakeMemberAccount account;
  late FakeMyTourneesStore myTournees;
  late FakePhoneSettings settings;
  late FakeTourneeDirectory tourneeDirectory;
  late FakeTourneeRepository tournees;
  late FakePendingSync pending;
  late ProviderContainer container;

  /// Every port bound to the fakes, the member on the phone being
  /// [member].
  List<Override> overridesAs(MemberId member) => [
    streetRepositoryProvider.overrideWithValue(streets),
    phoneStreetRepositoryProvider.overrideWithValue(phoneStreets),
    movedStreetsLogProvider.overrideWithValue(movedStreets),
    pendingSyncProvider.overrideWithValue(pending),
    addressDirectoryProvider.overrideWithValue(directory),
    communeSearchProvider.overrideWithValue(communes),
    clockProvider.overrideWithValue(FakeClock(twoPm)),
    idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
    identityProvider.overrideWithValue(FakeIdentity(member)),
    streetViewPreferencesProvider.overrideWithValue(preferences),
    memberAccountProvider.overrideWithValue(account),
    myTourneesStoreProvider.overrideWithValue(myTournees),
    phoneSettingsProvider.overrideWithValue(settings),
    tourneeDirectoryProvider.overrideWithValue(tourneeDirectory),
    tourneeRepositoryProvider.overrideWithValue(tournees),
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
    communes = FakeCommuneSearch(
      answers: {
        'Villef': Ok([
          CommuneMatch(commune: villefranche, postcodes: const ['69400']),
        ]),
      },
    );
    preferences = FakeStreetViewPreferences([lilasId]);
    account = FakeMemberAccount(nextMember: MemberId('uid-lea'));
    myTournees = FakeMyTourneesStore(
      MyTournees.none.remember(tournee49).remember(tournee7),
    );
    settings = FakePhoneSettings(memberName: nameOf('Léa'));
    tourneeDirectory = FakeTourneeDirectory();
    tournees = FakeTourneeRepository([team()]);
    pending = FakePendingSync(2);
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
      'Clock': clockProvider,
      'IdGenerator': idGeneratorProvider,
      'IdentityProvider': identityProvider,
      'StreetViewPreferences': streetViewPreferencesProvider,
      'MemberAccount': memberAccountProvider,
      'MyTourneesStore': myTourneesStoreProvider,
      'PhoneSettings': phoneSettingsProvider,
      'TourneeDirectory': tourneeDirectoryProvider,
      'TourneeRepository': tourneeRepositoryProvider,
      'phone StreetRepository': phoneStreetRepositoryProvider,
      'MovedStreetsLog': movedStreetsLogProvider,
      'PendingSync': pendingSyncProvider,
      'Random': randomProvider,
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

    test('should mark a house with the bound clock and member', () async {
      final change = valueOf(
        await container.read(markHouseProvider)(
          lilasId,
          n('7'),
          VisitStatus.done,
        ),
      );

      expect(change.stamp, leaAtTwo);
      expect(streets.saved, hasLength(1));
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
        await container.read(markHouseProvider)(
          lilasId,
          n('7'),
          VisitStatus.done,
        ),
      );

      valueOf(await container.read(undoLastChangeProvider)(change));

      expect(houseOf(streets[lilasId]!, '7'), seven);
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

    test('should read the tournées of the bound store', () {
      expect(container.read(readMyTourneesProvider)().tournees, [
        tournee49,
        tournee7,
      ]);
    });

    test('should observe the tournées of the bound store', () async {
      final next = container.read(observeMyTourneesProvider)().first;
      await myTournees.save(MyTournees.none);

      expect(await next, MyTournees.none);
    });

    test('should open a tournée of the bound store', () async {
      valueOf(await container.read(openTourneeProvider)(tournee49.id));

      expect(myTournees.myTournees.current, tournee49);
    });

    test('should watch a request in the bound directory as the bound '
        'account', () {
      account.signedInMember = MemberId('uid-kept');

      container.read(watchJoinRequestProvider)(tournee7.id);

      expect(tourneeDirectory.watched, [(tournee7.id, MemberId('uid-kept'))]);
    });

    test('should settle a request in the bound store', () async {
      await container.read(settleJoinRequestProvider)(
        tournee7.id,
        MemberStatus.active,
      );

      expect(myTournees.myTournees.find(tournee7.id)!.isPending, isFalse);
    });

    test('should read the bound settings', () {
      expect(container.read(readPhoneSettingsProvider)().name, nameOf('Léa'));
    });

    test('should change the name in the bound settings', () async {
      await container.read(changeMemberNameProvider)('Julie');

      expect(settings.names, [nameOf('Julie')]);
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

    test('should observe the team in the bound repository', () async {
      final tournee = await container
          .read(observeTeamProvider)(tourneeId)
          .first;

      expect(tournee, same(tournees[tourneeId]));
    });

    test('should read the bound member', () {
      expect(container.read(readCurrentMemberProvider)(), lea);
    });

    test('should accept a request with the bound clock and member', () async {
      final manusPhone = asManu();

      final change = valueOf(
        await manusPhone.read(acceptMemberProvider)(tourneeId, julieId),
      );

      expect(change.member.acceptance!.by, manuId);
      expect(change.member.acceptance!.at, twoPm);
    });

    test('should refuse a request as the bound member', () async {
      final change = valueOf(
        await asManu().read(refuseMemberProvider)(tourneeId, julieId),
      );

      expect(change, isA<MemberRefused>());
    });

    test('should remove a member as the bound member', () async {
      final change = valueOf(
        await asManu().read(removeMemberProvider)(tourneeId, leaId),
      );

      expect(change, isA<MemberRemoved>());
    });

    test('should leave the tournée and forget it in the bound store', () async {
      await myTournees.save(MyTournees.none.remember(tournee49));
      final phone = ProviderContainer(overrides: overridesAs(leaId));
      addTearDown(phone.dispose);

      valueOf(await phone.read(leaveTourneeProvider)(tourneeId));

      expect(myTournees.myTournees.tournees, isEmpty);
    });

    test('should draw a new code from the bound random source', () async {
      final code = valueOf(
        await asManu().read(regenerateJoinCodeProvider)(tourneeId),
      );

      expect(code, codeOf('234567'));
    });

    test(
      'should delete the tournée and forget it in the bound store',
      () async {
        valueOf(await asManu().read(deleteTourneeProvider)(tourneeId));

        expect(tournees.deleted, hasLength(1));
        expect(myTournees.myTournees.find(tourneeId), isNull);
      },
    );

    test(
      'should count the phone streets for the bound tournées and member',
      () async {
        // Léa of the team (`uid-lea`): an active member of the 49.
        final leasPhone = ProviderContainer(overrides: overridesAs(leaId));
        addTearDown(leasPhone.dispose);

        expect(await leasPhone.read(countStreetsToMoveProvider)(tourneeId), 1);
      },
    );

    test(
      'should move the phone streets into the bound repository and log',
      () async {
        final moved = await container.read(moveStreetsIntoTourneeProvider)(
          tourneeId,
        );

        expect(moved, const StreetsMoved(moved: 1, alreadyThere: 0));
        expect(
          streets[StreetId('morin')]?.name,
          streetName('Rue Pierre Morin'),
        );
        expect(movedStreets.remembered, [tourneeId]);
      },
    );
  });
}
