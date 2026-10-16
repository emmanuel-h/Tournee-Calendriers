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
/// Play Store, so it uses the debug provider instead, with the token
/// registered in the Firebase console and passed at build time
/// ([_appCheckDebugToken]). Without it the provider makes a new token on
/// every install and prints it in the logs
/// (`adb logcat | grep DebugAppCheckProvider`).
Future<AnonymousAuth> startFirebase() async {
  // The instrumented suite starts the app several times in one process; the
  // project is connected once.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider(
              debugToken: _appCheckDebugToken.isEmpty
                  ? null
                  : _appCheckDebugToken,
            )
          : const AndroidPlayIntegrityProvider(),
    );
  }
  return FirebaseAnonymousAuth(FirebaseAuth.instance);
}

/// The App Check debug token, fixed so that a reinstall (the instrumented
/// suite reinstalls on every run) keeps passing once App Check is enforced.
/// It lets anyone holding it past App Check, so it never enters the
/// repository: it comes from
/// `--dart-define-from-file=$HOME/.config/tournee-calendriers/app_check_debug.json`.
/// `String.fromEnvironment` reads a `--dart-define` value at compile time;
/// it is empty when none is given.
const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

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
