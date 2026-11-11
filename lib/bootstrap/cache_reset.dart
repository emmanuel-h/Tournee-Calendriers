import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_cache_reset.dart';
import 'package:tournee_calendriers/infrastructure/http/host_reachable.dart';

/// The file of the secteurs downloaded for offline use (`SectorDownloads`,
/// PLAN §6.3), in the storage folder. Its name dates from before the code
/// said « sector » (#116).
const sectorDownloadsFile = 'tournee_downloads.json';

/// Follows the app going to the background for the [FirestoreCacheReset]
/// of the last start; one at a time, since the instrumented suite starts
/// the app several times in one process.
AppLifecycleListener? _hidden;

/// Starts the [FirestoreCacheReset] of the app (PLAN §8.3), before
/// anything else asks Firestore anything: when a forgotten secteur made a
/// reset due and the phone is [online], Firestore's copy is emptied now,
/// and so is the list of downloaded secteurs in [storage]
/// ([sectorDownloadsFile]), since their streets left with the copy: the
/// open one is then downloaded again by itself (PLAN §7), the others when
/// they are opened.
///
/// [firestore] gives the database, with its offline settings, only when
/// the reset needs it, so a phone with nothing to reset does not start it
/// here. [online] tells whether the phone has a network; Firestore's server
/// name looked up by default.
///
/// Then each time the app is hidden the reset is told
/// ([FirestoreCacheReset.appHidden]). Needs Flutter's binding.
Future<FirestoreCacheReset> startCacheReset({
  required Directory storage,
  required FirebaseFirestore Function() firestore,
  Future<bool> Function()? online,
}) async {
  File fileOf(String name) =>
      File('${storage.path}${Platform.pathSeparator}$name');
  final reset = await FirestoreCacheReset.load(
    fileOf('cache_reset.json'),
    waitForPendingWrites: () => firestore().waitForPendingWrites(),
    clearPersistence: () => firestore().clearPersistence(),
  );
  await reset.resetIfDue(
    online: online ?? () => hostReachable(firestoreHost),
    afterReset: () async {
      final downloads = fileOf(sectorDownloadsFile);
      if (downloads.existsSync()) await downloads.delete();
    },
  );
  _hidden?.dispose();
  _hidden = AppLifecycleListener(onHide: reset.appHidden);
  return reset;
}
