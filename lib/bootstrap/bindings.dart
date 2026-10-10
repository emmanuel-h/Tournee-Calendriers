import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (the type of a ProviderScope's overrides) lives in misc.dart.
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/infrastructure/ban/ban_address_directory.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/anonymous_auth.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/firebase_identity.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_tournee_directory.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_tournee_repository.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geo_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_identity.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_my_tournees.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_phone_settings.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_view_preferences.dart';
import 'package:tournee_calendriers/infrastructure/system/random_id_generator.dart';
import 'package:tournee_calendriers/infrastructure/system/system_clock.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// The one HTTP client of the app, shared by the services that need the
/// network (the BAN and geo.api.gouv.fr). Riverpod calls `onDispose` when the
/// `ProviderScope` goes away, which closes the client and its connections.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Binds every port of `presentation/dependencies.dart` to its adapter, as
/// the overrides of the app's `ProviderScope`.
///
/// - [storage]: the folder of the phone storage. The streets go in
///   `streets/`, the id the phone made for itself in `member_id`, the
///   street screens' « Masquer faits » in `street_view.json`, « Mes
///   tournées » and the open one in `my_tournees.json`, the name and the
///   theme in `settings.json`.
/// - [auth]: Firebase anonymous sign-in. Its uid is the member; until the
///   first sign-in succeeds, the phone's own id stands in for the marks,
///   and creating or joining a tournée signs in again (`MemberAccount`).
/// - [firestore]: gives the Firestore database, asked once, only when a
///   screen first needs it (following a request to join, the open
///   tournée's team), so a phone with no tournée never touches it. It
///   serves the phone's copy first, so an offline cold start works.
/// - [addressDirectory]: replaces the BAN, so the instrumented suite can
///   import streets without the network.
/// - [communeSearch]: replaces geo.api.gouv.fr, for the same reason.
///
/// Async because the member id, the street view preferences, « Mes
/// tournées » and the settings are read from the phone before the first
/// screen, so reading them later never waits.
Future<List<Override>> bindAdapters({
  required Directory storage,
  required AnonymousAuth auth,
  required FirebaseFirestore Function() firestore,
  AddressDirectory? addressDirectory,
  CommuneSearch? communeSearch,
}) async {
  final ids = RandomIdGenerator();
  final phoneIdentity = await LocalIdentity.load(
    File('${storage.path}${Platform.pathSeparator}member_id'),
    ids,
  );
  final identity = FirebaseIdentity(auth, beforeSignIn: phoneIdentity);
  // Not awaited: the first screen must not wait for the network. After an
  // offline first start, creating or joining a tournée tries again.
  unawaited(identity.signInIfNeeded());
  File fileOf(String name) =>
      File('${storage.path}${Platform.pathSeparator}$name');
  final streetView = await LocalStreetViewPreferences.load(
    fileOf('street_view.json'),
  );
  final myTournees = await LocalMyTournees.load(fileOf('my_tournees.json'));
  final settings = await LocalPhoneSettings.load(fileOf('settings.json'));
  // `late final` with a value: computed the first time it is read, then
  // kept. So Firestore is asked for once, by whichever adapter needs it
  // first, and never on a phone that does not.
  late final db = firestore();
  // The operating system's secure source: a join code drawn from the
  // plain `Random()` could be predicted (PLAN §5.2).
  final random = Random.secure();
  return [
    streetRepositoryProvider.overrideWithValue(
      LocalStreetRepository(
        Directory('${storage.path}${Platform.pathSeparator}streets'),
      ),
    ),
    addressDirectoryProvider.overrideWith(
      (ref) =>
          addressDirectory ??
          BanAddressDirectory(ref.watch(httpClientProvider)),
    ),
    communeSearchProvider.overrideWith(
      (ref) => communeSearch ?? GeoCommuneSearch(ref.watch(httpClientProvider)),
    ),
    clockProvider.overrideWithValue(const SystemClock()),
    idGeneratorProvider.overrideWithValue(ids),
    identityProvider.overrideWithValue(identity),
    memberAccountProvider.overrideWithValue(identity),
    streetViewPreferencesProvider.overrideWithValue(streetView),
    myTourneesStoreProvider.overrideWithValue(myTournees),
    phoneSettingsProvider.overrideWithValue(settings),
    // `overrideWith`: built the first time it is read, not at start-up.
    tourneeDirectoryProvider.overrideWith(
      (ref) => FirestoreTourneeDirectory(db),
    ),
    tourneeRepositoryProvider.overrideWith(
      (ref) => FirestoreTourneeRepository(db, random: random),
    ),
    randomProvider.overrideWithValue(random),
  ];
}
