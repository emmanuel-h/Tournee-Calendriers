import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/bootstrap/bindings.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/ban/ban_address_directory.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/firebase_identity.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geo_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_view_preferences.dart';
import 'package:tournee_calendriers/infrastructure/system/random_id_generator.dart';
import 'package:tournee_calendriers/infrastructure/system/system_clock.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../support/fakes/fake_address_directory.dart';
import '../support/fakes/fake_anonymous_auth.dart';
import '../support/fakes/fake_commune_search.dart';

void main() {
  late Directory storage;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('bindings_test');
  });

  tearDown(() => storage.delete(recursive: true));

  Future<ProviderContainer> containerWith({
    FakeAddressDirectory? directory,
    FakeCommuneSearch? communes,
    FakeAnonymousAuth? auth,
  }) async {
    final container = ProviderContainer(
      overrides: await bindAdapters(
        storage: storage,
        // By default a phone that never signed in and is offline.
        auth: auth ?? FakeAnonymousAuth(),
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
}
