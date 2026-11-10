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
import 'package:tournee_calendriers/application/ports/server_connection.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/infrastructure/ban/ban_address_directory.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/anonymous_auth.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/firebase_identity.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_admin_status.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_round_ledger.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_sector_directory.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_sector_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_streets_download.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geo_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_identity.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_my_sectors.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_open_round.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_phone_settings.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_sector_downloads.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_view_preferences.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_unfinished_streets.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/retired_files.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/openfreemap_street_shapes.dart';
import 'package:tournee_calendriers/infrastructure/maplibre_offline/maplibre_offline_map_store.dart';
import 'package:tournee_calendriers/infrastructure/system/random_id_generator.dart';
import 'package:tournee_calendriers/infrastructure/system/system_clock.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/ui/map/map_style.dart';

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
/// - [storage]: the folder of the phone storage. The id the phone made for
///   itself goes in `member_id`, the street screens' « Masquer faits » in
///   `street_view.json`, « Mes secteurs » and the open one in
///   `my_tournees.json`, the name and the theme in `settings.json`, the
///   secteurs downloaded for offline use in `tournee_downloads.json`, the
///   new streets of a campaign not yet all handed to Firestore in
///   `unfinished_streets/<secteur>/<year>/` (#104), and the tournée on
///   (one outing, #63) in `open_round.json`. The file names that say
///   « tournee » date from before the code said « sector » (#116); they
///   stay, so an updated phone keeps its data. What older versions kept
///   and nothing reads any more (the streets of a phone with no secteur
///   open, #119) is deleted first.
/// - [auth]: Firebase anonymous sign-in. Its uid is the member; until the
///   first sign-in succeeds, the phone's own id stands in for the marks,
///   and creating or joining a tournée signs in again (`MemberAccount`).
/// - [firestore]: gives the Firestore database, asked once, only when a
///   screen first needs it (following a request to join, the open
///   tournée's team and streets, whether the phone is an admin, a
///   validated tournée), so a phone that shows none of them never touches
///   it. It serves the phone's copy first, so an offline cold start works.
/// - [addressDirectory]: replaces the BAN, so the instrumented suite can
///   import streets without the network.
/// - [communeSearch]: replaces geo.api.gouv.fr, for the same reason.
/// - [streetShapes]: replaces the OpenFreeMap tiles' roads, for the same
///   reason (a zone drawn on « Ajouter des rues »).
///
/// The streets follow the open secteur: those of its current campaign in
/// Firestore while one is open, none while none is (streets only live in a
/// secteur, PLAN §5.0). So does the pending sync: the Firestore streets'
/// own count of unsent streets, 0 with none open; and so does whether the
/// phone is offline, from the same listener.
///
/// Async because the member id, the street view preferences, « Mes
/// tournées », the settings and the tournée on are read from the phone before the first
/// screen, so reading them later never waits.
Future<List<Override>> bindAdapters({
  required Directory storage,
  required AnonymousAuth auth,
  required FirebaseFirestore Function() firestore,
  AddressDirectory? addressDirectory,
  CommuneSearch? communeSearch,
  StreetShapes? streetShapes,
}) async {
  await deleteRetiredFiles(storage);
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
  final mySectors = await LocalMySectors.load(fileOf('my_tournees.json'));
  final settings = await LocalPhoneSettings.load(fileOf('settings.json'));
  final sectorDownloads = await LocalSectorDownloads.load(
    fileOf('tournee_downloads.json'),
  );
  final openRound = await LocalOpenRound.load(fileOf('open_round.json'));
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
  final sectorStreets = Provider<FirestoreStreetRepository?>((ref) {
    // `select`: only the tournée and its campaign name the streets; the
    // summary changing otherwise (a new centre name) keeps them.
    final open = ref.watch(
      currentSectorProvider.select(
        (sector) => sector == null ? null : (sector.id, sector.campaign),
      ),
    );
    if (open == null) return null;
    final (sector, campaign) = open;
    final streets = FirestoreStreetRepository(
      db,
      sector: sector,
      campaign: campaign,
      identity: identity,
      clock: clock,
      unfinished: LocalUnfinishedStreets(
        Directory(
          [
            storage.path,
            'unfinished_streets',
            // Percent-encoded: whatever the id holds, it stays one folder.
            Uri.encodeComponent(sector.value),
            '${campaign.value}',
          ].join(Platform.pathSeparator),
        ),
      ),
    );
    ref.onDispose(() => unawaited(streets.close()));
    return streets;
  });
  return [
    streetRepositoryProvider.overrideWith(
      (ref) => ref.watch(sectorStreets) ?? const _NoStreets(),
    ),
    // The same adapter as the streets: its one listener on the secteur
    // also tells which streets still have writes waiting.
    pendingSyncProvider.overrideWith(
      (ref) => ref.watch(sectorStreets) ?? const _NothingToSend(),
    ),
    // The same adapter again: whether its listener answers from the
    // phone's copy says whether the phone is offline (PLAN §5.3). With no
    // tournée open no listener runs, so nothing says offline.
    serverConnectionProvider.overrideWith(
      (ref) => ref.watch(sectorStreets) ?? const _NothingToTell(),
    ),
    addressDirectoryProvider.overrideWith(
      (ref) =>
          addressDirectory ??
          BanAddressDirectory(ref.watch(httpClientProvider)),
    ),
    communeSearchProvider.overrideWith(
      (ref) => communeSearch ?? GeoCommuneSearch(ref.watch(httpClientProvider)),
    ),
    streetShapesProvider.overrideWith(
      (ref) =>
          streetShapes ??
          OpenFreeMapStreetShapes(ref.watch(httpClientProvider)),
    ),
    clockProvider.overrideWithValue(clock),
    idGeneratorProvider.overrideWithValue(ids),
    identityProvider.overrideWithValue(identity),
    memberAccountProvider.overrideWithValue(identity),
    streetViewPreferencesProvider.overrideWithValue(streetView),
    mySectorsStoreProvider.overrideWithValue(mySectors),
    phoneSettingsProvider.overrideWithValue(settings),
    // The tournée on and its dons stay on the phone (PLAN §6.3); once
    // validated, only its summary goes to the secteur, in Firestore
    // (#110), whose offline queue sends it later.
    openRoundStoreProvider.overrideWithValue(openRound),
    roundLedgerProvider.overrideWith((ref) => FirestoreRoundLedger(db)),
    // `overrideWith`: built the first time it is read, not at start-up.
    sectorDirectoryProvider.overrideWith((ref) => FirestoreSectorDirectory(db)),
    sectorRepositoryProvider.overrideWith(
      (ref) => FirestoreSectorRepository(db, random: random),
    ),
    randomProvider.overrideWithValue(random),
    // The offline download (PLAN §7): the streets read from the server,
    // the map regions of the map library over the very style the map
    // shows, and what was downloaded, kept on the phone.
    streetsDownloadProvider.overrideWith((ref) => FirestoreStreetsDownload(db)),
    offlineMapStoreProvider.overrideWithValue(
      const MapLibreOfflineMapStore(styleUrl: openFreeMapStyle),
    ),
    sectorDownloadsProvider.overrideWithValue(sectorDownloads),
    // Whether the phone, or a member, is an admin (PLAN §5.12): the
    // phone's own `admins/{uid}` once it has an account.
    adminStatusProvider.overrideWith(
      (ref) => FirestoreAdminStatus(db, identity),
    ),
  ];
}

/// The pending sync while no secteur is open: there is no street, so
/// nothing ever waits to be sent.
final class _NothingToSend implements PendingSync {
  const _NothingToSend();

  @override
  Stream<int> watchUnsentStreets() => Stream.value(0);
}

/// Whether the phone is offline while no secteur is open: no listener runs
/// to tell, so it says online, which leaves « Mes secteurs » as it is.
final class _NothingToTell implements ServerConnection {
  const _NothingToTell();

  @override
  Stream<bool> watchOffline() => Stream.value(false);
}

/// The streets while no secteur is open (PLAN §5.0): none. Streets only
/// live in a secteur, and no screen offers to add one with none open; the
/// reads answer « nothing » at once, so a screen still on its way out (a
/// secteur lost while a street showed) shows nothing rather than failing.
///
/// A write would have nowhere to go: it fails with a [StateError], a bug,
/// since no screen sends one with no secteur open.
final class _NoStreets implements StreetRepository {
  const _NoStreets();

  @override
  Future<Street?> find(StreetId id) async => null;

  @override
  Future<Street?> findByBanId(BanStreetId banId) async => null;

  @override
  Stream<Street?> watch(StreetId id) => Stream.value(null);

  @override
  Stream<List<Street>> watchAll() => Stream.value(const []);

  @override
  Stream<List<Street>> watchDeleted() => Stream.value(const []);

  @override
  Future<void> add(Street street) => _nowhere();

  @override
  Future<void> save(Street street, StreetChange change) => _nowhere();

  @override
  Future<void> purge(StreetId id) => _nowhere();

  static Future<void> _nowhere() => Future.error(
    StateError('No secteur is open: a street has nowhere to go.'),
  );
}
