import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/bootstrap/bindings.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/ban/ban_address_directory.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/firebase_identity.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_tournee_directory.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_tournee_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geo_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_moved_streets_log.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_my_tournees.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_phone_settings.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_view_preferences.dart';
import 'package:tournee_calendriers/infrastructure/system/random_id_generator.dart';
import 'package:tournee_calendriers/infrastructure/system/system_clock.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../domain/tournee/my_tournees_fixtures.dart';
import '../domain/tournee/tournee_fixtures.dart' show nameOf;
import '../support/fakes/fake_address_directory.dart';
import '../support/fakes/fake_anonymous_auth.dart';
import '../support/fakes/fake_commune_search.dart';
import '../support/results.dart';
import '../support/street_fixtures.dart' show n, villefranche;

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

    final streets = container.read(streetRepositoryProvider);
    expect(streets, isA<LocalStreetRepository>());
    expect(
      (streets as LocalStreetRepository).directory.path,
      '${storage.path}/streets',
    );
    expect(
      container.read(addressDirectoryProvider),
      isA<BanAddressDirectory>(),
    );
    expect(container.read(communeSearchProvider), isA<GeoCommuneSearch>());
    expect(container.read(clockProvider), isA<SystemClock>());
    expect(container.read(idGeneratorProvider), isA<RandomIdGenerator>());
    expect(
      container.read(streetViewPreferencesProvider),
      isA<LocalStreetViewPreferences>(),
    );
    expect(container.read(identityProvider), isA<FirebaseIdentity>());
    expect(container.read(myTourneesStoreProvider), isA<LocalMyTournees>());
    expect(container.read(phoneSettingsProvider), isA<LocalPhoneSettings>());
    expect(firestoreAsked, 0);
    expect(
      container.read(tourneeDirectoryProvider),
      isA<FirestoreTourneeDirectory>(),
    );
    expect(firestoreAsked, 1);
    expect(
      container.read(tourneeRepositoryProvider),
      isA<FirestoreTourneeRepository>(),
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
      MyTournees.none
          .remember(tournee49)
          .remember(tournee12)
          .open(tournee12.id),
    );
    await (await containerWith()).read(myTourneesStoreProvider).save(opened);

    final second = await containerWith();

    expect(second.read(myTourneesStoreProvider).myTournees, opened);
    expect(File('${storage.path}/my_tournees.json').existsSync(), isTrue);
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
    /// 49 and the 12, the 49 open unless [noTournee].
    Future<ProviderContainer> leasPhone({
      bool noTournee = false,
      Directory? folder,
      String uid = 'uid-lea',
    }) async {
      final container = await containerWith(
        auth: FakeAnonymousAuth(currentUid: uid),
        db: db,
        folder: folder,
      );
      final mine = MyTournees.none.remember(tournee49).remember(tournee12);
      await container
          .read(myTourneesStoreProvider)
          .save(noTournee ? mine : valueOf(mine.open(tournee49.id)));
      return container;
    }

    Future<void> openTournee(ProviderContainer container, TourneeId id) async {
      final store = container.read(myTourneesStoreProvider);
      await store.save(valueOf(store.myTournees.open(id)));
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

    test('should be the phone storage while no tournée is open', () async {
      final container = await leasPhone(noTournee: true);

      final streets = container.read(streetRepositoryProvider);

      expect(streets, same(container.read(phoneStreetRepositoryProvider)));
      expect(streets, isA<LocalStreetRepository>());
      expect(firestoreAsked, 0);
      expect(
        container.read(movedStreetsLogProvider),
        isA<LocalMovedStreetsLog>(),
      );
    });

    test('should be the open tournée\'s campaign in Firestore', () async {
      final container = await leasPhone();

      final streets = container.read(streetRepositoryProvider);
      await streets.add(morin);
      await pumpEventQueue();

      expect(streets, isA<FirestoreStreetRepository>());
      expect(
        container.read(phoneStreetRepositoryProvider),
        isA<LocalStreetRepository>(),
      );
      final stored = await db
          .doc('tournees/t49/campaigns/2026/streets/morin')
          .get();
      expect(stored.data()?['name'], 'Rue Pierre Morin');
      expect(
        await container.read(phoneStreetRepositoryProvider).find(morin.id),
        isNull,
      );
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

        await openTournee(container, tournee12.id);
        final streets12 = container.read(streetRepositoryProvider);
        await streets12.add(morin);
        // A teammate adds a street to the 49, which is no longer followed.
        await db
            .doc('tournees/t49/campaigns/2026/streets/morin')
            .set(streetToDocument(morin));
        await pumpEventQueue();

        expect(streets12, isNot(same(streets49)));
        expect(streets12, isA<FirestoreStreetRepository>());
        expect(
          (await db.doc('tournees/t12/campaigns/2026/streets/morin').get())
              .exists,
          isTrue,
        );
        expect(seenIn49, [0]);
      },
    );

    test('should be the phone storage again once no tournée is open', () async {
      final container = await leasPhone();
      container.read(streetRepositoryProvider);

      final store = container.read(myTourneesStoreProvider);
      await store.save(store.myTournees.forget(tournee49.id));

      expect(
        container.read(streetRepositoryProvider),
        same(container.read(phoneStreetRepositoryProvider)),
      );
    });

    test(
      'should keep the storage when the open tournée is saved again',
      () async {
        final container = await leasPhone();
        final streets = container.read(streetRepositoryProvider);

        final store = container.read(myTourneesStoreProvider);
        await store.save(store.myTournees.remember(tournee49));

        expect(container.read(streetRepositoryProvider), same(streets));
      },
    );

    test('should have nothing to send while no tournée is open', () async {
      final container = await leasPhone(noTournee: true);

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

        // The same adapter, so one Firestore listener serves both.
        expect(container.read(pendingSyncProvider), same(streets49));
        expect(streets49, isA<FirestoreStreetRepository>());

        await openTournee(container, tournee12.id);

        final streets12 = container.read(streetRepositoryProvider);
        expect(streets12, isNot(same(streets49)));
        expect(container.read(pendingSyncProvider), same(streets12));
      },
    );

    test('should have nothing to send once no tournée is open', () async {
      final container = await leasPhone();
      container.read(pendingSyncProvider);

      final store = container.read(myTourneesStoreProvider);
      await store.save(store.myTournees.forget(tournee49.id));

      final pending = container.read(pendingSyncProvider);
      expect(pending, isNot(isA<FirestoreStreetRepository>()));
      expect(await pending.watchUnsentStreets().first, 0);
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
        await lea.read(markHouseProvider)(morin.id, n('32'), VisitStatus.done),
      );
      await pumpEventQueue();

      expect(seenByPaul, [VisitStatus.toDo, VisitStatus.done]);
      final stored = await db
          .doc('tournees/t49/campaigns/2026/streets/morin')
          .get();
      final houses = stored.data()!['houses'] as Map<String, dynamic>;
      expect((houses['32'] as Map<String, dynamic>)['by'], 'uid-lea');
    });

    test(
      'should keep the tournées the streets went into across starts',
      () async {
        await (await containerWith())
            .read(movedStreetsLogProvider)
            .rememberMovedInto(tournee49.id);

        final second = await containerWith();

        expect(
          second.read(movedStreetsLogProvider).wereMovedInto(tournee49.id),
          isTrue,
        );
        expect(File('${storage.path}/moved_streets.json').existsSync(), isTrue);
      },
    );
  });
}
