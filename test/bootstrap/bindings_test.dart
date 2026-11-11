import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/services/indexed_street_repository.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/bootstrap/bindings.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/infrastructure/ban/ban_address_directory.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/firebase_identity.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_admin_status.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_round_ledger.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_sector_directory.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_sector_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_streets_download.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/fallback_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geo_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geopf_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_my_sectors.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_open_round.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_phone_settings.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_sector_downloads.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_view_preferences.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/openfreemap_street_shapes.dart';
import 'package:tournee_calendriers/infrastructure/maplibre_offline/maplibre_offline_map_store.dart';
import 'package:tournee_calendriers/infrastructure/system/random_id_generator.dart';
import 'package:tournee_calendriers/infrastructure/system/system_clock.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../domain/round/round_fixtures.dart' show cash;
import '../domain/sector/my_sectors_fixtures.dart';
import '../domain/sector/sector_fixtures.dart' show nameOf;
import '../support/fakes/fake_address_directory.dart';
import '../support/fakes/fake_anonymous_auth.dart';
import '../support/fakes/fake_commune_search.dart';
import '../support/results.dart';
import '../support/street_fixtures.dart' show lea, n, twoPm, villefranche;

void main() {
  late Directory storage;
  var firestoreAsked = 0;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('bindings_test');
    firestoreAsked = 0;
  });

  tearDown(() => storage.delete(recursive: true));

  Future<ProviderContainer> containerWith({
    FakeAddressDirectory? directory,
    FakeCommuneSearch? communes,
    FakeAnonymousAuth? auth,
    FakeFirebaseFirestore? db,
    Directory? folder,
  }) async {
    final container = ProviderContainer(
      overrides: await bindAdapters(
        storage: folder ?? storage,
        // By default a phone that never signed in and is offline.
        auth: auth ?? FakeAnonymousAuth(),
        firestore: () {
          firestoreAsked++;
          return db ?? FakeFirebaseFirestore();
        },
        addressDirectory: directory,
        communeSearch: communes,
      ),
    );
    addTearDown(container.dispose);
    return container;
  }

  test('should bind each port to the adapter of the phone', () async {
    final container = await containerWith();

    expect(
      container.read(addressDirectoryProvider),
      isA<BanAddressDirectory>(),
    );
    expect(
      container.read(communeSearchProvider),
      isA<FallbackCommuneSearch>()
          .having((search) => search.first, 'first', isA<GeoCommuneSearch>())
          .having((search) => search.then, 'then', isA<GeopfCommuneSearch>()),
    );
    expect(
      container.read(streetShapesProvider),
      isA<OpenFreeMapStreetShapes>(),
    );
    expect(container.read(clockProvider), isA<SystemClock>());
    expect(container.read(idGeneratorProvider), isA<RandomIdGenerator>());
    expect(
      container.read(streetViewPreferencesProvider),
      isA<LocalStreetViewPreferences>(),
    );
    expect(container.read(identityProvider), isA<FirebaseIdentity>());
    expect(container.read(mySectorsStoreProvider), isA<LocalMySectors>());
    expect(container.read(phoneSettingsProvider), isA<LocalPhoneSettings>());
    expect(container.read(openRoundStoreProvider), isA<LocalOpenRound>());
    expect(firestoreAsked, 0);
    expect(
      container.read(sectorDirectoryProvider),
      isA<FirestoreSectorDirectory>(),
    );
    expect(firestoreAsked, 1);
    expect(
      container.read(sectorRepositoryProvider),
      isA<FirestoreSectorRepository>(),
    );
    expect(container.read(adminStatusProvider), isA<FirestoreAdminStatus>());
    expect(container.read(roundLedgerProvider), isA<FirestoreRoundLedger>());
    expect(
      container.read(streetsDownloadProvider),
      isA<FirestoreStreetsDownload>(),
    );
    expect(
      container.read(offlineMapStoreProvider),
      isA<MapLibreOfflineMapStore>().having(
        (store) => store.styleUrl,
        'styleUrl',
        'https://tiles.openfreemap.org/styles/liberty',
      ),
    );
    expect(
      container.read(sectorDownloadsProvider),
      isA<LocalSectorDownloads>(),
    );
    // One database for every Firestore adapter.
    expect(firestoreAsked, 1);
    expect(container.read(randomProvider), isA<Random>());
    expect(
      container.read(randomProvider).runtimeType,
      Random.secure().runtimeType,
    );
    // One adapter for both ports: the account the screens wait for is the
    // one whose uid stamps the marks.
    expect(
      container.read(memberAccountProvider),
      same(container.read(identityProvider)),
    );
  });

  test('should delete the streets of a phone with no secteur open, kept by '
      'older versions', () async {
    File('${storage.path}/streets/lilas.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    File('${storage.path}/moved_streets.json').writeAsStringSync('{}');

    await containerWith();

    expect(Directory('${storage.path}/streets').existsSync(), isFalse);
    expect(File('${storage.path}/moved_streets.json').existsSync(), isFalse);
  });

  test('should stamp with the uid when the phone signed in before', () async {
    final auth = FakeAnonymousAuth(currentUid: 'uid-kept', nextUid: 'uid-new');

    final container = await containerWith(auth: auth);

    expect(
      container.read(identityProvider).currentMember,
      MemberId('uid-kept'),
    );
    expect(auth.signInCalls, 0);
  });

  test('should start without waiting for the first sign-in', () async {
    final auth = FakeAnonymousAuth(nextUid: 'uid-new')
      ..gate = Completer<void>();

    final container = await containerWith(auth: auth);
    final identity = container.read(identityProvider);

    expect(auth.signInCalls, 1);
    expect(
      identity.currentMember.value,
      File('${storage.path}/member_id').readAsStringSync(),
    );
    auth.gate.complete();
    await auth.gate.future;
    // Lets the sign-in's `await` resume (a microtask) before looking again.
    await Future<void>.delayed(Duration.zero);
    expect(identity.currentMember, MemberId('uid-new'));
  });

  test('should keep « Masquer faits » across starts', () async {
    final street = StreetId('nationale');
    await (await containerWith())
        .read(streetViewPreferencesProvider)
        .setHidesDone(street, hide: true);

    final second = await containerWith();

    expect(
      second.read(streetViewPreferencesProvider).hidesDone(street),
      isTrue,
    );
    expect(File('${storage.path}/street_view.json').existsSync(), isTrue);
  });

  test('should keep the phone id across starts when never signed in', () async {
    final first = (await containerWith()).read(identityProvider);
    final second = (await containerWith()).read(identityProvider);

    expect(second.currentMember, first.currentMember);
    expect(
      File('${storage.path}/member_id').readAsStringSync(),
      first.currentMember.value,
    );
  });

  test('should use the directory given instead of the BAN', () async {
    final directory = FakeAddressDirectory();

    final container = await containerWith(directory: directory);

    expect(container.read(addressDirectoryProvider), same(directory));
  });

  test('should use the commune search given instead of geo.api', () async {
    final communes = FakeCommuneSearch();

    final container = await containerWith(communes: communes);

    expect(container.read(communeSearchProvider), same(communes));
  });

  test('should make one HTTP client for the app', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(httpClientProvider),
      same(container.read(httpClientProvider)),
    );
  });

  test('should sign in on demand when the first start was offline', () async {
    final auth = FakeAnonymousAuth();
    final container = await containerWith(auth: auth);
    final account = container.read(memberAccountProvider);
    // The sign-in started at launch fails: no network.
    await Future<void>.delayed(Duration.zero);
    expect(account.signedInMember, isNull);

    auth.nextUid = 'uid-new';
    final member = valueOf(await account.signInIfNeeded());

    expect(member, MemberId('uid-new'));
    expect(auth.signInCalls, 2);
    expect(container.read(identityProvider).currentMember, member);
  });

  test('should reopen the last tournée across starts', () async {
    final opened = valueOf(
      MySectors.none.remember(sector49).remember(sector12).open(sector12.id),
    );
    await (await containerWith()).read(mySectorsStoreProvider).save(opened);

    final second = await containerWith();

    expect(second.read(mySectorsStoreProvider).mySectors, opened);
    expect(File('${storage.path}/my_tournees.json').existsSync(), isTrue);
  });

  test('should keep the tournée on and its dons across starts', () async {
    final first = await containerWith();
    await first
        .read(mySectorsStoreProvider)
        .save(valueOf(MySectors.none.remember(sector49).open(sector49.id)));
    valueOf(await first.read(startRoundProvider)());
    valueOf(await first.read(addDonationProvider)(cash(1000)));

    final second = await containerWith();
    final round = second.read(openRoundStoreProvider).openRound!;

    expect(round.sector, sector49.id);
    expect(round.donations, [cash(1000)]);
    expect(File('${storage.path}/open_round.json').existsSync(), isTrue);
  });

  test('should keep the name and the theme across starts', () async {
    final first = (await containerWith()).read(phoneSettingsProvider);
    await first.setMemberName(nameOf('Manu'));
    await first.setTheme(ThemeChoice.dark);

    final second = (await containerWith()).read(phoneSettingsProvider);

    expect(second.memberName, nameOf('Manu'));
    expect(second.theme, ThemeChoice.dark);
    expect(File('${storage.path}/settings.json').existsSync(), isTrue);
  });

  group('streets', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    /// The phone of [uid] (Léa by default, signed in before) knowing the
    /// 49 and the 12, the 49 open; with [noSector], knowing no tournée
    /// (one that knows tournées follows them in Firestore, open or not).
    Future<ProviderContainer> leasPhone({
      bool noSector = false,
      Directory? folder,
      String uid = 'uid-lea',
    }) async {
      final container = await containerWith(
        auth: FakeAnonymousAuth(currentUid: uid),
        db: db,
        folder: folder,
      );
      final mine = MySectors.none.remember(sector49).remember(sector12);
      await container
          .read(mySectorsStoreProvider)
          .save(noSector ? MySectors.none : valueOf(mine.open(sector49.id)));
      return container;
    }

    Future<void> openSector(ProviderContainer container, SectorId id) async {
      final store = container.read(mySectorsStoreProvider);
      await store.save(valueOf(store.mySectors.open(id)));
    }

    final morin = valueOf(
      Street.create(
        id: StreetId('morin'),
        name: 'Rue Pierre Morin',
        commune: villefranche,
        banId: BanStreetId('69264_1460'),
        houses: [
          House(number: n('32')),
          House(number: n('33')),
        ],
      ),
    );

    test('should write the open secteur\'s entry in the shared index when '
        'a street is added, and read the others\'', () async {
      final container = await leasPhone();
      await db.doc('streetParts/69264_1460').set({
        'sector': 't12',
        'parts': {
          't12': {
            'number': 12,
            'centreName': 'CS Villefranche',
            'odd': [19, 41],
            'even': 'none',
          },
        },
      });

      await container.read(streetRepositoryProvider).add(morin);
      await pumpEventQueue();
      final others = await container
          .read(streetPartIndexProvider)
          .othersOf(morin.banId!);

      final stored = await db.doc('streetParts/69264_1460').get();
      expect((stored.data()!['parts'] as Map)['t49'], {
        'number': 49,
        'centreName': 'CS Villefranche',
        'odd': 'all',
        'even': 'all',
      });
      expect(others.map((other) => other.sector.value), [12]);
    });

    Future<Map<String, dynamic>?> openSectorOf(String uid) async =>
        (await db.doc('openSectors/$uid').get()).data();

    test('should tell the rules which secteur the member reads the index '
        'as, and follow the one opened (#147)', () async {
      final container = await leasPhone();

      container.read(streetPartIndexProvider);
      await pumpEventQueue();
      expect(await openSectorOf('uid-lea'), {'sectorId': 't49'});

      await openSector(container, sector12.id);
      container.read(streetPartIndexProvider);
      await pumpEventQueue();
      expect(await openSectorOf('uid-lea'), {'sectorId': 't12'});
    });

    test('should tell no secteur for an admin who only visits it', () async {
      final container = await leasPhone(uid: 'uid-sam');
      final store = container.read(mySectorsStoreProvider);
      await store.save(
        valueOf(MySectors.none.remember(sector12Visited).open(sector12.id)),
      );

      container.read(streetPartIndexProvider);
      await pumpEventQueue();

      expect(await openSectorOf('uid-sam'), isNull);
    });

    test('should tell no secteur before the phone has an account', () async {
      final container = await containerWith(db: db);
      final store = container.read(mySectorsStoreProvider);
      await store.save(
        valueOf(MySectors.none.remember(sector49).open(sector49.id)),
      );

      container.read(streetPartIndexProvider);
      await pumpEventQueue();

      expect((await db.collection('openSectors').get()).docs, isEmpty);
    });

    test('should have no index while no secteur is open', () async {
      final container = await leasPhone(noSector: true);
      final index = container.read(streetPartIndexProvider);

      await index.hold(morin.banId!, StreetPart.whole);
      await index.release(morin.banId!);

      expect(await index.othersOf(morin.banId!), isEmpty);
      expect(firestoreAsked, 0);
    });

    test('should hold no street while no secteur is open', () async {
      final container = await leasPhone(noSector: true);

      final streets = container.read(streetRepositoryProvider);

      expect(streets, isNot(isA<FirestoreStreetRepository>()));
      expect(await streets.watchAll().first, isEmpty);
      expect(await streets.watchDeleted().first, isEmpty);
      expect(await streets.watch(morin.id).first, isNull);
      expect(await streets.find(morin.id), isNull);
      expect(await streets.findByBanId(morin.banId!), isNull);
      expect(firestoreAsked, 0);
    });

    test('should refuse every write while no secteur is open', () async {
      final container = await leasPhone(noSector: true);
      final streets = container.read(streetRepositoryProvider);
      final (marked, change) = valueOf(
        morin.markHouse(n('32'), VisitStatus.done, by: lea, at: twoPm),
      );

      await expectLater(streets.add(morin), throwsStateError);
      await expectLater(streets.save(marked, change), throwsStateError);
      await expectLater(streets.purge(morin.id), throwsStateError);
      expect(firestoreAsked, 0);
    });

    test('should be the open tournée\'s campaign in Firestore', () async {
      final container = await leasPhone();

      final streets = container.read(streetRepositoryProvider);
      await streets.add(morin);
      await pumpEventQueue();

      expect(streets, isA<IndexedStreetRepository>());
      final stored = await db
          .doc('sectors/t49/campaigns/2026/streets/morin')
          .get();
      expect(stored.data()?['name'], 'Rue Pierre Morin');
      // Nothing of it in the folder the phone kept its own streets in.
      expect(Directory('${storage.path}/streets').existsSync(), isFalse);
    });

    test(
      'should follow the tournée opened and stop following the one left',
      () async {
        final container = await leasPhone();
        final streets49 = container.read(streetRepositoryProvider);
        final seenIn49 = <int>[];
        final listening = streets49.watchAll().listen(
          (streets) => seenIn49.add(streets.length),
        );
        addTearDown(listening.cancel);
        await pumpEventQueue();

        await openSector(container, sector12.id);
        final streets12 = container.read(streetRepositoryProvider);
        await streets12.add(morin);
        // A teammate adds a street to the 49, which is no longer followed.
        await db
            .doc('sectors/t49/campaigns/2026/streets/morin')
            .set(streetToDocument(morin));
        await pumpEventQueue();

        expect(streets12, isNot(same(streets49)));
        expect(streets12, isA<IndexedStreetRepository>());
        expect(
          (await db.doc('sectors/t12/campaigns/2026/streets/morin').get())
              .exists,
          isTrue,
        );
        expect(seenIn49, [0]);
      },
    );

    test('should hold no street again once no secteur is open', () async {
      final container = await leasPhone();
      await container.read(streetRepositoryProvider).add(morin);
      await pumpEventQueue();

      final store = container.read(mySectorsStoreProvider);
      await store.save(store.mySectors.forget(sector49.id));

      final streets = container.read(streetRepositoryProvider);
      expect(streets, isNot(isA<FirestoreStreetRepository>()));
      expect(await streets.watchAll().first, isEmpty);
    });

    test(
      'should keep the storage when the open tournée is saved again',
      () async {
        final container = await leasPhone();
        final streets = container.read(streetRepositoryProvider);

        final store = container.read(mySectorsStoreProvider);
        await store.save(store.mySectors.remember(sector49));

        expect(container.read(streetRepositoryProvider), same(streets));
      },
    );

    test('should have nothing to send while no tournée is open', () async {
      final container = await leasPhone(noSector: true);

      final unsent = await container
          .read(pendingSyncProvider)
          .watchUnsentStreets()
          .first;

      expect(unsent, 0);
      expect(firestoreAsked, 0);
    });

    test(
      'should count the unsent streets with the storage of the open tournée',
      () async {
        final container = await leasPhone();
        final streets49 = container.read(streetRepositoryProvider);
        final pending49 = container.read(pendingSyncProvider);

        // The adapter the streets wrap, so one Firestore listener serves
        // both.
        expect(pending49, isA<FirestoreStreetRepository>());
        expect(streets49, isA<IndexedStreetRepository>());

        await openSector(container, sector12.id);

        final streets12 = container.read(streetRepositoryProvider);
        expect(streets12, isNot(same(streets49)));
        expect(container.read(pendingSyncProvider), isNot(same(pending49)));
        expect(
          container.read(pendingSyncProvider),
          isA<FirestoreStreetRepository>(),
        );
      },
    );

    test('should have nothing to send once no tournée is open', () async {
      final container = await leasPhone();
      container.read(pendingSyncProvider);

      final store = container.read(mySectorsStoreProvider);
      await store.save(store.mySectors.forget(sector49.id));

      final pending = container.read(pendingSyncProvider);
      expect(pending, isNot(isA<FirestoreStreetRepository>()));
      expect(await pending.watchUnsentStreets().first, 0);
    });

    test('should tell offline from the storage of the open tournée', () async {
      final container = await leasPhone();
      final pending49 = container.read(pendingSyncProvider);

      // The same adapter as the pending sync, the one the streets wrap, so
      // its one Firestore listener also says it.
      expect(container.read(serverConnectionProvider), same(pending49));

      await openSector(container, sector12.id);

      expect(
        container.read(serverConnectionProvider),
        same(container.read(pendingSyncProvider)),
      );
      expect(container.read(serverConnectionProvider), isNot(same(pending49)));
    });

    test('should say online while no tournée is open', () async {
      final container = await leasPhone(noSector: true);

      final offline = await container
          .read(serverConnectionProvider)
          .watchOffline()
          .first;

      expect(offline, isFalse);
      expect(firestoreAsked, 0);
    });

    test('should show a teammate the marks of another phone', () async {
      final paulsFolder = await Directory.systemTemp.createTemp('paul');
      addTearDown(() => paulsFolder.delete(recursive: true));
      final lea = await leasPhone();
      final paul = await leasPhone(folder: paulsFolder, uid: 'uid-paul');
      await lea.read(streetRepositoryProvider).add(morin);
      await pumpEventQueue();
      final seenByPaul = <VisitStatus?>[];
      final listening = paul
          .read(observeStreetProvider)(morin.id)
          .listen((street) => seenByPaul.add(street?.houses.first.status));
      addTearDown(listening.cancel);
      await pumpEventQueue();

      valueOf(
        await lea.read(setHouseDetailsProvider)(
          morin.id,
          n('32'),
          const StatusMark(VisitStatus.done),
        ),
      );
      await pumpEventQueue();

      expect(seenByPaul, [VisitStatus.toDo, VisitStatus.done]);
      final stored = await db
          .doc('sectors/t49/campaigns/2026/streets/morin')
          .get();
      final houses = stored.data()!['houses'] as Map<String, dynamic>;
      expect((houses['32'] as Map<String, dynamic>)['by'], 'uid-lea');
    });
  });
}
