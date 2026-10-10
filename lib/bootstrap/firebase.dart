import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/bootstrap/firebase_options.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/anonymous_auth.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/firebase_anonymous_auth.dart';

/// Connects the app to its Firebase project and gives the sign-in service.
///
/// Nothing here needs the network: `initializeApp` reads the project's
/// settings compiled into the app (`firebase_options.dart`, written by
/// `flutterfire configure`, kept out of the public repository), and App
/// Check only fetches a token when Firebase is first called. An offline
/// cold start goes straight through (PLAN §7).
///
/// App Check proves to Firebase that the caller is this app (PLAN §8.1):
/// Play Integrity in release builds. A debug build is not signed by the
/// Play Store, so it uses the debug provider instead: it prints a token in
/// the logs (`adb logcat | grep DebugAppCheckProvider`) to register in the
/// Firebase console.
Future<AnonymousAuth> startFirebase() async {
  // The instrumented suite starts the app several times in one process; the
  // project is connected once.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  }
  return FirebaseAnonymousAuth(FirebaseAuth.instance);
}

/// The app's Firestore database, with the settings of PLAN §7 applied
/// before anything asks it anything (Firestore refuses settings once it has
/// started): the phone keeps everything it has read or written
/// (`persistenceEnabled`), with no size limit, so nothing of a downloaded
/// tournée is ever evicted (`CACHE_SIZE_UNLIMITED`).
///
/// Call it only after [startFirebase]. The settings are applied once per
/// process: a top-level `final` is computed the first time it is read, and
/// the instrumented suite starts the app several times in one process.
FirebaseFirestore offlineFirestore() => _offlineFirestore;

final FirebaseFirestore _offlineFirestore = FirebaseFirestore.instance
  ..settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
