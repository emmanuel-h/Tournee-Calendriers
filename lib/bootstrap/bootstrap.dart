/// Composition root: the only layer that sees every other one. It connects
/// Firebase (`firebase.dart`), binds each port to its adapter
/// (`bindings.dart`) and starts the app.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/bootstrap/bindings.dart';
import 'package:tournee_calendriers/bootstrap/cache_reset.dart';
import 'package:tournee_calendriers/bootstrap/firebase.dart';
import 'package:tournee_calendriers/bootstrap/offline_upkeep.dart';
import 'package:tournee_calendriers/bootstrap/uncaught_errors.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/components/save_failed_alert.dart';
import 'package:tournee_calendriers/ui/map/started_map_channel.dart';
import 'package:tournee_calendriers/ui/theme/font_licenses.dart';

/// Starts the app.
///
/// `ProviderScope` is the Riverpod container: every provider's state lives in
/// it, and its `overrides` bind the ports to their adapters.
///
/// The instrumented suite starts the real app through here, replacing what
/// it must: [addressDirectory] (a fake BAN, so no network is needed),
/// [communeSearch] (a fake commune search, for the same reason),
/// [streetShapes] (the roads of IGN and of the map, for the same reason)
/// and [storage] (a fresh folder, so each test starts with no street). By default the storage is the app's support folder: private to the app,
/// kept across updates, removed with the app.
Future<void> bootstrap({
  AddressDirectory? addressDirectory,
  CommuneSearch? communeSearch,
  StreetShapes? streetShapes,
  Directory? storage,
}) async {
  // `path_provider` and Firebase talk to the platform through channels,
  // which need Flutter's binding before `runApp` creates it.
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  StartedMapChannel.install();
  // A failed save surfaces as an error nothing caught; the dialog that
  // tells the user reaches the screens through the navigator's key.
  final navigatorKey = GlobalKey<NavigatorState>();
  final saveFailed = SaveFailedAlert(navigatorKey);
  WidgetsBinding.instance.platformDispatcher.onError = (error, _) =>
      handleUncaughtError(error, onSaveFailed: saveFailed.show);
  final folder = storage ?? await getApplicationSupportDirectory();
  final auth = await startFirebase();
  final overrides = await bindAdapters(
    storage: folder,
    // Before anything asks Firestore anything: its copy on the phone can
    // only be emptied before it starts.
    cacheReset: await startCacheReset(
      storage: folder,
      firestore: offlineFirestore,
    ),
    auth: auth,
    // A function, not the instance: `startFirebase` has connected the
    // project, but nothing asks Firestore anything until a screen needs it,
    // and its offline settings come first (`offlineFirestore`).
    firestore: offlineFirestore,
    addressDirectory: addressDirectory,
    communeSearch: communeSearch,
    streetShapes: streetShapes,
  );
  runApp(
    ProviderScope(
      overrides: overrides,
      // The open secteur downloads itself for offline use, unseen.
      child: OfflineUpkeep(child: TourneeApp(navigatorKey: navigatorKey)),
    ),
  );
}
