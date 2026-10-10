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
import 'package:tournee_calendriers/application/ports/pending_sync.dart';
import 'package:tournee_calendriers/infrastructure/ban/ban_address_directory.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/anonymous_auth.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/firebase_identity.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_tournee_directory.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_tournee_repository.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geo_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_identity.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_moved_streets_log.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_my_tournees.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_phone_settings.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_view_preferences.dart';
import 'package:tournee_calendriers/infrastructure/system/random_id_generator.dart';
import 'package:tournee_calendriers/infrastructure/system/system_clock.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';

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
/// - [storage]: the folder of the phone storage. The streets of M1 go in
///   `streets/`, the id the phone made for itself in `member_id`, the
///   street screens' « Masquer faits » in `street_view.json`, « Mes
///   tournées » and the open one in `my_tournees.json`, the name and the
///   theme in `settings.json`, the tournées that received the streets of
///   M1 in `moved_streets.json`.
/// - [auth]: Firebase anonymous sign-in. Its uid is the member; until the
///   first sign-in succeeds, the phone's own id stands in for the marks,
///   and creating or joining a tournée signs in again (`MemberAccount`).
/// - [firestore]: gives the Firestore database, asked once, only when a
///   screen first needs it (following a request to join, the open
///   tournée's team and streets), so a phone with no tournée never touches
///   it. It serves the phone's copy first, so an offline cold start works.
///
/// The streets follow the open tournée: those of its current campaign in
/// Firestore while one is open, the phone's own (M1) while none is. So does
/// the pending sync: the Firestore streets' own count of unsent streets,
/// always 0 for the phone's streets.
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
  final movedStreets = await LocalMovedStreetsLog.load(
    fileOf('moved_streets.json'),
  );
  // One phone storage of the streets: it answers from memory and queues
  // its writes, so two instances of it must never run side by side.
  final phoneStreets = LocalStreetRepository(
    Directory('${storage.path}${Platform.pathSeparator}streets'),
  );
  const clock = SystemClock();
  // `late final` with a value: computed the first time it is read, then
  // kept. So Firestore is asked for once, by whichever adapter needs it
  // first, and never on a phone that does not.
  late final db = firestore();
  // The operating system's secure source: a join code drawn from the
  // plain `Random()` could be predicted (PLAN §5.2).
  final random = Random.secure();
  // The streets of the open tournée's current campaign in Firestore, null
  // while none is open. A provider of its own, made here because it needs
  // the database and the identity above, so that the street repository and
  // the pending sync share one adapter, hence one listener.
  //
  // Built again each time another tournée (or none) is opened, which
  // builds again every use case, and every screen, that watches it. The
  // old tournée's listener stops (`onDispose`, which Riverpod runs before
  // building again).
  final tourneeStreets = Provider<FirestoreStreetRepository?>((ref) {
    // `select`: only the tournée and its campaign name the streets; the
    // summary changing otherwise (a new centre name) keeps them.
    final open = ref.watch(
      currentTourneeProvider.select(
        (tournee) => tournee == null ? null : (tournee.id, tournee.campaign),
      ),
    );
    if (open == null) return null;
    final (tournee, campaign) = open;
    final streets = FirestoreStreetRepository(
      db,
      tournee: tournee,
      campaign: campaign,
      identity: identity,
      clock: clock,
    );
    ref.onDispose(() => unawaited(streets.close()));
    return streets;
  });
  return [
    phoneStreetRepositoryProvider.overrideWithValue(phoneStreets),
    streetRepositoryProvider.overrideWith(
      (ref) => ref.watch(tourneeStreets) ?? phoneStreets,
    ),
    // The same adapter as the streets: its one listener on the tournée
    // also tells which streets still have writes waiting. The phone's own
    // streets are never sent anywhere.
    pendingSyncProvider.overrideWith(
      (ref) => ref.watch(tourneeStreets) ?? const _NothingToSend(),
    ),
    movedStreetsLogProvider.overrideWithValue(movedStreets),
    addressDirectoryProvider.overrideWith(
      (ref) =>
          addressDirectory ??
          BanAddressDirectory(ref.watch(httpClientProvider)),
    ),
    communeSearchProvider.overrideWith(
      (ref) => communeSearch ?? GeoCommuneSearch(ref.watch(httpClientProvider)),
    ),
    clockProvider.overrideWithValue(clock),
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

/// The pending sync while no tournée is open: the phone's own streets (M1)
/// stay on the phone, so nothing ever waits to be sent.
final class _NothingToSend implements PendingSync {
  const _NothingToSend();

  @override
  Stream<int> watchUnsentStreets() => Stream.value(0);
}
