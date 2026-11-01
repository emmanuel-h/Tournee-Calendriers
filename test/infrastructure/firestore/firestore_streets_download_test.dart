// Reading every street of a tournée from the server, for its download
// (PLAN §7), against an in-memory Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/application/ports/streets_download.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_streets_download.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';

import '../../domain/tournee/tournee_fixtures.dart' show campaign2026;
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

const _streets = 'tournees/t49/campaigns/2026/streets';

Street _street(String id) => valueOf(
  Street.create(
    id: StreetId(id),
    name: 'Rue $id',
    commune: villefranche,
    houses: [House(number: n('1'), position: at(45.989, 4.718))],
  ),
);

FirebaseException _error(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreStreetsDownload download;

  setUp(() {
    db = FakeFirebaseFirestore();
    download = FirestoreStreetsDownload(db);
  });

  /// The in-memory Firestore cannot fail a whole collection: it reads each
  /// of its documents, and one of them fails with [code].
  Future<void> serverFails(String code) async {
    final paix = db.doc('$_streets/paix');
    await paix.set(streetToDocument(_street('paix')));
    whenCalling(Invocation.method(#get, null)).on(paix).thenThrow(_error(code));
  }

  test('should give every street of the campaign', () async {
    final nationale = _street('nationale');
    final paix = _street('paix');
    await db.doc('$_streets/nationale').set(streetToDocument(nationale));
    await db.doc('$_streets/paix').set(streetToDocument(paix));
    await db
        .doc('tournees/t49/campaigns/2025/streets/old')
        .set(streetToDocument(_street('old')));

    final streets = valueOf(
      await download.fromServer(TourneeId('t49'), campaign2026),
    );

    expect([
      for (final street in streets) street.id,
    ], unorderedEquals([nationale.id, paix.id]));
    expect(streets.first.houses.single.position, at(45.989, 4.718));
  });

  test('should leave out a street it cannot read', () async {
    final paix = _street('paix');
    await db.doc('$_streets/paix').set(streetToDocument(paix));
    await db.doc('$_streets/broken').set({'name': 12});

    final streets = valueOf(
      await download.fromServer(TourneeId('t49'), campaign2026),
    );

    expect([for (final street in streets) street.id], [paix.id]);
  });

  test('should tell when the server cannot be reached', () async {
    await serverFails('unavailable');

    final result = await download.fromServer(TourneeId('t49'), campaign2026);

    expect(failureOf(result), StreetsDownloadFailure.noNetwork);
  });

  test('should tell when the server refuses', () async {
    await serverFails('permission-denied');

    final result = await download.fromServer(TourneeId('t49'), campaign2026);

    expect(failureOf(result), StreetsDownloadFailure.serviceError);
  });
}
