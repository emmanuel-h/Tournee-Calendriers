/// Composition root: the only layer that sees every other one. It binds
/// each port to its adapter (`bindings.dart`) and starts the app; from M2 it
/// also initialises Firebase here.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/bootstrap/bindings.dart';
import 'package:tournee_calendriers/bootstrap/uncaught_errors.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/components/save_failed_alert.dart';
import 'package:tournee_calendriers/ui/theme/font_licenses.dart';

/// Starts the app.
///
/// `ProviderScope` is the Riverpod container: every provider's state lives in
/// it, and its `overrides` bind the ports to their adapters.
///
/// The instrumented suite starts the real app through here, replacing what
/// it must: [addressDirectory] (a fake BAN, so no network is needed),
/// [communeSearch] (a fake commune search, for the same reason) and
/// [storage] (a fresh folder, so each test starts with no street). By
/// default the storage is the app's support folder: private to the app,
/// kept across updates, removed with the app.
Future<void> bootstrap({
  AddressDirectory? addressDirectory,
  CommuneSearch? communeSearch,
  Directory? storage,
}) async {
  // `path_provider` asks the platform for the folder through a channel,
  // which needs Flutter's binding before `runApp` creates it.
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // A failed save surfaces as an error nothing caught; the dialog that
  // tells the user reaches the screens through the navigator's key.
  final navigatorKey = GlobalKey<NavigatorState>();
  final saveFailed = SaveFailedAlert(navigatorKey);
  WidgetsBinding.instance.platformDispatcher.onError = (error, _) =>
      handleUncaughtError(error, onSaveFailed: saveFailed.show);
  final overrides = await bindAdapters(
    storage: storage ?? await getApplicationSupportDirectory(),
    addressDirectory: addressDirectory,
    communeSearch: communeSearch,
  );
  runApp(
    ProviderScope(
      overrides: overrides,
      child: TourneeApp(navigatorKey: navigatorKey),
    ),
  );
}
