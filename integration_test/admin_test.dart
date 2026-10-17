// Instrumented admin flows (PLAN §5.12, §11), run inside the real app on the
// Android emulator against the LOCAL Firebase emulators (Auth + Firestore
// with the real `firebase/firestore.rules`), never the real project:
//
//   tool/admin_e2e.sh
//
// The script starts the emulators, runs this file, and stops them. Run
// alone (`flutter test integration_test/admin_test.dart`) without the
// emulators, it fails at once: nothing answers on 10.0.2.2.
//
// Why emulators: an admin is an `admins/{uid}` document added by hand, and
// the app gets a new anonymous uid at each install. Here the test plays the
// console: it adds and removes `admins/{uid}` itself, bypassing the rules
// (« Bearer owner », which only the emulator accepts).
//
// Each file of `integration_test/` runs in its own app process, so this one
// can point Firebase at the emulators without touching `app_test.dart`.
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/bootstrap/bootstrap.dart';
import 'package:tournee_calendriers/bootstrap/firebase.dart';
import 'package:tournee_calendriers/bootstrap/firebase_options.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

import '../test/support/fakes/fake_commune_search.dart';

/// The value of [result], which the test data guarantees.
T _ok<T, F>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('$failure'),
};

final _villefranche = _ok(
  Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
);
final _villefrancheCentre = _ok(
  GeoPoint.create(latitude: 45.9837, longitude: 4.726),
);

/// How the Android emulator reaches the computer it runs on, where the
/// Firebase emulators listen (`firebase/firebase.json`).
const _host = '10.0.2.2';
const _authPort = 9099;
const _firestorePort = 8080;

/// The project the app's options name. The emulators run with
/// `singleProjectMode: false`, so they serve it like any other project id,
/// with the same rules; nothing reaches the real one.
String get _project => Firebase.app().options.projectId;

/// The Firestore emulator's REST API for the document at [path], as the
/// project owner: the security rules are bypassed, as the console does.
Future<int> _asOwner(String method, String path, [Object? body]) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse(
        'http://$_host:$_firestorePort/v1/projects/$_project'
        '/databases/(default)/documents/$path',
      ),
    );
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer owner')
      ..contentType = ContentType.json;
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    final status = response.statusCode;
    await response.drain<void>();
    return status;
  } finally {
    client.close();
  }
}

/// Writes the document at [path] with [fields] in the REST API's typed
/// form (`{'stringValue': 'Léa'}`), as the owner.
Future<void> _put(String path, Map<String, Object?> fields) async {
  final status = await _asOwner('PATCH', path, {'fields': fields});
  expect(status, 200, reason: 'writing $path on the emulator');
}

Map<String, Object?> _text(String value) => {'stringValue': value};
Map<String, Object?> _int(int value) => {'integerValue': '$value'};
Map<String, Object?> _time(String value) => {'timestampValue': value};

/// Tournée 12 of the CS Villefranche, created by Léa, who is its only
/// member: one the admin on the phone is not in. Its centre is then known
/// to « Nouvelle tournée ». Shaped as the Firestore
/// mappers write it (PLAN §6.2).
Future<void> _seedTournee12() async {
  const id = 'e2eTournee12';
  const at = '2026-10-01T08:00:00Z';
  await _put('tournees/$id', {
    'number': _int(12),
    'centreKey': _text('villefranche'),
    'centreName': _text('CS Villefranche'),
    'joinCode': _text('K7P2QX'),
    'createdBy': _text('uidLea'),
    'createdAt': _time(at),
    'currentCampaign': _int(2026),
  });
  await _put('tournees/$id/members/uidLea', {
    'displayName': _text('Léa'),
    'status': _text('active'),
    'requestedAt': _time(at),
    'acceptedBy': _text('uidLea'),
    'acceptedAt': _time(at),
  });
  await _put('rescueCentres/villefranche', {'name': _text('CS Villefranche')});
  await _put('tourneeKeys/villefranche_12', {'tourneeId': _text(id)});
  await _put('joinCodes/K7P2QX', {
    'tourneeId': _text(id),
    'number': _int(12),
    'centreName': _text('CS Villefranche'),
    'campaign': _int(2026),
  });
}

/// Pumps frames until [finder] finds something: the emulators answer in
/// real time, not in the test's fake time. Fails after [timeout].
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) fail('Nothing found for $finder');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

/// Taps [key] once it is in sight.
Future<void> _tap(WidgetTester tester, Key key) async {
  final button = find.byKey(key);
  await _waitFor(tester, button);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Firebase is connected here, before the app does it: `startFirebase`
    // then finds it connected and skips App Check, which only the real
    // project knows (the emulators do not ask for it).
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Both must come before anything asks Auth or Firestore anything.
    await FirebaseAuth.instance.useAuthEmulator(_host, _authPort);
    offlineFirestore().useFirestoreEmulator(_host, _firestorePort);
    // Nothing kept from an earlier run (an account, a cached document)
    // may leak into this one.
    await offlineFirestore().clearPersistence();
    await FirebaseAuth.instance.signOut();
  });

  // The next start of the app (`app_test.dart`, the developer) signs in
  // again on the real project rather than reusing the emulator's account.
  tearDownAll(() => FirebaseAuth.instance.signOut());

  testWidgets(
    'should let an admin create a tournée, visit and join another one, and '
    'say « Vous n\'êtes plus administrateur. » once admins/{uid} is removed',
    (tester) async {
      final storage = await Directory.systemTemp.createTemp('admin_flow');
      addTearDown(() => storage.delete(recursive: true));

      // geo.api.gouv.fr played by a fake: the commune of « Nouvelle
      // tournée » needs no network outside the emulators.
      await bootstrap(
        storage: storage,
        communeSearch: FakeCommuneSearch(
          answers: {
            'Villef': Ok([
              CommuneMatch(
                commune: _villefranche,
                postcodes: const ['69400'],
                centre: _villefrancheCentre,
              ),
            ]),
          },
        ),
      );
      await tester.pumpAndSettle();
      // The anonymous sign-in runs in the background, against the Auth
      // emulator.
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (FirebaseAuth.instance.currentUser == null) {
        if (DateTime.now().isAfter(end)) fail('No sign-in on the emulator');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // The console makes the phone an admin's: « Bienvenue » offers
      // « Créer une tournée ».
      await _put('admins/$uid', {});
      await _seedTournee12();
      await tester.enterText(find.byKey(const Key('welcome.name')), 'Sam');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await _tap(tester, const Key('welcome.create'));

      // « Nouvelle tournée »: the CS Villefranche (known to the server
      // since the 12), number 49, the year as given, « Créer ».
      await tester.enterText(find.byKey(const Key('create.centre')), 'villef');
      await _tap(tester, const ValueKey('create.centre.villefranche'));
      await tester.enterText(find.byKey(const Key('communes.field')), 'Villef');
      await tester.pumpAndSettle();
      await _tap(tester, const ValueKey('communes.suggestion.69264'));
      await tester.enterText(find.byKey(const Key('create.number')), '49');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await _tap(tester, const Key('create.create'));
      await _waitFor(tester, find.byKey(const Key('create.code')));
      await _tap(tester, const Key('create.continue'));
      expect(find.text('Tournée 49 · 2026'), findsOneWidget);

      // Équipe: the creator is in the team, as an admin.
      await _tap(tester, const Key('home.team'));
      await _waitFor(tester, find.text('Sam (vous) · admin'));
      // The commune went with the tournée, through the rules (#78).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('team.commune.69264')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      // « Toutes les tournées » → the 12, which Sam is not in: the banner
      // « Administrateur · pas membre », then « Rejoindre ».
      await _tap(tester, const Key('home.tournee'));
      await _tap(tester, const Key('myTournees.all'));
      await _tap(tester, const ValueKey('allTournees.e2eTournee12'));
      expect(find.text('Tournée 12 · 2026'), findsOneWidget);
      await _waitFor(tester, find.byKey(const Key('home.adminBanner')));
      await _tap(tester, const Key('home.adminJoin'));
      expect(find.byKey(const Key('home.adminBanner')), findsNothing);

      // A new tournée is started, then the console removes admins/{uid}
      // before « Créer »: the server refuses, the screen says why.
      await _tap(tester, const Key('home.tournee'));
      await _tap(tester, const Key('myTournees.create'));
      await tester.enterText(find.byKey(const Key('create.centre')), 'villef');
      await _tap(tester, const ValueKey('create.centre.villefranche'));
      await tester.enterText(find.byKey(const Key('communes.field')), 'Villef');
      await tester.pumpAndSettle();
      await _tap(tester, const ValueKey('communes.suggestion.69264'));
      await tester.enterText(find.byKey(const Key('create.number')), '50');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(await _asOwner('DELETE', 'admins/$uid'), 200);
      await _tap(tester, const Key('create.create'));
      await _waitFor(tester, find.byKey(const Key('create.notAdmin')));
      expect(find.text("Vous n'êtes plus administrateur."), findsOneWidget);

      // Back on Accueil, « Mes tournées » no longer offers « Créer ».
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await _tap(tester, const Key('home.tournee'));
      expect(find.byKey(const Key('myTournees.create')), findsNothing);
      expect(find.byKey(const Key('myTournees.all')), findsNothing);
    },
  );
}
