// What a newcomer and a creator ask of Firestore from outside a tournée,
// against an in-memory Firestore (fake_cloud_firestore, PLAN §11).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_tournee_directory.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/tournee_document_mapper.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/results.dart';

final preview = JoinPreview(
  code: firstCode,
  tourneeId: tourneeId,
  number: number49,
  centre: csVillefranche,
  campaign: campaign2026,
);

FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

RescueCentre centre(String name) => valueOf(RescueCentre.create(name));

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreTourneeDirectory directory;

  setUp(() {
    db = FakeFirebaseFirestore();
    directory = FirestoreTourneeDirectory(db);
  });

  Future<Map<String, dynamic>?> stored(String path) async =>
      (await db.doc(path).get()).data();

  void offline(
    DocumentReference<Object?> reference, [
    String code = 'unavailable',
  ]) {
    whenCalling(Invocation.method(#get, null))
        .on(reference)
        .thenThrow(firestoreError(code));
  }

  group('preview', () {
    test('should show the tournée of an exact code', () async {
      await db.doc('joinCodes/K7P2QX').set(joinCodeDocument(team()));

      expect(valueOf(await directory.preview(firstCode)), preview);
    });

    test('should find nothing for a code no tournée has', () async {
      await db.doc('joinCodes/K7P2QX').set(joinCodeDocument(team()));

      final result = await directory.preview(codeOf('234567'));

      expect(failureOf(result), JoinFailure.unknownCode);
    });

    test('should tell when the server cannot be reached', () async {
      offline(db.doc('joinCodes/K7P2QX'));

      expect(
        failureOf(await directory.preview(firstCode)),
        JoinFailure.noNetwork,
      );
    });

    test('should throw any other failure of the server', () async {
      offline(db.doc('joinCodes/K7P2QX'), 'permission-denied');

      await expectLater(
        directory.preview(firstCode),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('request', () {
    test('should store a pending member with the code it used', () async {
      await directory.requestToJoin(preview, julie);
      await pumpEventQueue();

      expect(
        await stored('tournees/t49/members/uid-julie'),
        joinRequestDocument(julie, firstCode),
      );
    });

    test('should refuse to send a member already accepted', () {
      expect(() => directory.requestToJoin(preview, lea), throwsArgumentError);
    });

    test('should follow the request until it is accepted', () async {
      final seen = <MemberStatus?>[];
      final subscription = directory
          .watchRequest(tourneeId, julieId)
          .listen(seen.add);
      await pumpEventQueue();

      await directory.requestToJoin(preview, julie);
      await pumpEventQueue();
      await db.doc('tournees/t49/members/uid-julie').update({
        'status': 'active',
        'acceptedBy': 'uid-manu',
        'acceptedAt': Timestamp.fromDate(leaAcceptedAt),
      });
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [null, MemberStatus.pending, MemberStatus.active]);
    });

    test('should give null once the request is refused', () async {
      await directory.requestToJoin(preview, julie);
      await pumpEventQueue();
      final seen = <MemberStatus?>[];
      final subscription = directory
          .watchRequest(tourneeId, julieId)
          .listen(seen.add);
      await pumpEventQueue();

      await db.doc('tournees/t49/members/uid-julie').delete();
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [MemberStatus.pending, null]);
    });

    test('should pass on a request it cannot read', () async {
      await db.doc('tournees/t49/members/uid-julie').set({'status': 'pending'});

      await expectLater(
        directory.watchRequest(tourneeId, julieId).first,
        throwsFormatException,
      );
    });

    test('should delete the request when it is cancelled', () async {
      await directory.requestToJoin(preview, julie);
      await pumpEventQueue();

      await directory.cancelRequest(tourneeId, julieId);
      await pumpEventQueue();

      expect(await stored('tournees/t49/members/uid-julie'), isNull);
    });
  });

  group('isTaken', () {
    test(
      'should say a number is taken in the same station however written',
      () async {
        await db.doc('tourneeKeys/villefranche_49').set({'tourneeId': 't49'});

        final taken = await directory.isTaken(
          centre('CIS Villefranche'),
          number49,
        );

        expect(valueOf(taken), isTrue);
      },
    );

    test('should say a number is free in another station', () async {
      await db.doc('tourneeKeys/villefranche_49').set({'tourneeId': 't49'});

      final taken = await directory.isTaken(
        centre('CS Villefranche Nord'),
        number49,
      );

      expect(valueOf(taken), isFalse);
    });

    test('should say another number is free in the same station', () async {
      await db.doc('tourneeKeys/villefranche_49').set({'tourneeId': 't49'});

      final taken = await directory.isTaken(
        csVillefranche,
        valueOf(TourneeNumber.create(50)),
      );

      expect(valueOf(taken), isFalse);
    });

    test('should tell when the server cannot be reached', () async {
      offline(db.doc('tourneeKeys/villefranche_49'));

      final taken = await directory.isTaken(csVillefranche, number49);

      expect(failureOf(taken), DirectoryFailure.noNetwork);
    });
  });

  group('other failures', () {
    test('should throw any other failure when checking a number', () async {
      offline(db.doc('tourneeKeys/villefranche_49'), 'permission-denied');

      await expectLater(
        directory.isTaken(csVillefranche, number49),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('should throw any other failure when listing the stations', () async {
      await db.doc('rescueCentres/villefranche').set({
        'name': 'CS Villefranche',
      });
      offline(db.doc('rescueCentres/villefranche'), 'permission-denied');

      await expectLater(
        directory.rescueCentres(),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('rescueCentres', () {
    test('should list the known stations by name', () async {
      await db.doc('rescueCentres/villefranche-nord').set({
        'name': 'CS Villefranche Nord',
      });
      await db.doc('rescueCentres/villefranche').set({
        'name': 'CS Villefranche',
      });
      await db.doc('rescueCentres/villefranche-est').set({
        'name': 'CIS Villefranche Est',
      });

      final centres = valueOf(await directory.rescueCentres());

      expect(centres.map((centre) => centre.name), [
        'CIS Villefranche Est',
        'CS Villefranche',
        'CS Villefranche Nord',
      ]);
    });

    test('should leave out a station it cannot read', () async {
      await db.doc('rescueCentres/villefranche').set({
        'name': 'CS Villefranche',
      });
      await db.doc('rescueCentres/broken').set({'label': 'CS ?'});

      final centres = valueOf(await directory.rescueCentres());

      expect(centres, [csVillefranche]);
    });

    test('should tell when the server cannot be reached', () async {
      await db.doc('rescueCentres/villefranche').set({
        'name': 'CS Villefranche',
      });
      // The in-memory Firestore reads a collection document by document.
      offline(db.doc('rescueCentres/villefranche'));

      final centres = await directory.rescueCentres();

      expect(failureOf(centres), DirectoryFailure.noNetwork);
    });
  });
}
