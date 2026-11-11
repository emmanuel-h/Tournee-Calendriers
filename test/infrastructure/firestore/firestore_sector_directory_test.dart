// What a newcomer and a creator ask of Firestore from outside a secteur,
// against an in-memory Firestore (fake_cloud_firestore, PLAN §11).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_sector_directory.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/sector_document_mapper.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/results.dart';

final preview = JoinPreview(
  code: firstCode,
  sectorId: sectorId,
  number: number49,
  centre: csVillefranche,
  campaign: campaign2026,
);

FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

RescueCentre centre(String name) => valueOf(RescueCentre.create(name));

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreSectorDirectory directory;

  setUp(() {
    db = FakeFirebaseFirestore();
    directory = FirestoreSectorDirectory(db);
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
    test('should show the secteur of an exact code', () async {
      await db.doc('joinCodes/K7P2QX').set(joinCodeDocument(team()));

      expect(valueOf(await directory.preview(firstCode)), preview);
    });

    test('should find nothing for a code no secteur has', () async {
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
      await directory.requestToJoin(julieRequest);
      await pumpEventQueue();

      expect(
        await stored('sectors/t49/members/uid-julie'),
        joinRequestDocument(julieRequest),
      );
    });

    test('should follow the request until it is accepted', () async {
      final seen = <MemberStatus?>[];
      final subscription = directory
          .watchRequest(sectorId, julieId)
          .listen(seen.add);
      await pumpEventQueue();

      await directory.requestToJoin(julieRequest);
      await pumpEventQueue();
      await db.doc('sectors/t49/members/uid-julie').update({
        'status': 'active',
        'acceptedBy': 'uid-manu',
        'acceptedAt': Timestamp.fromDate(leaAcceptedAt),
      });
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [null, MemberStatus.pending, MemberStatus.active]);
    });

    test('should give null once the request is refused', () async {
      await directory.requestToJoin(julieRequest);
      await pumpEventQueue();
      final seen = <MemberStatus?>[];
      final subscription = directory
          .watchRequest(sectorId, julieId)
          .listen(seen.add);
      await pumpEventQueue();

      await db.doc('sectors/t49/members/uid-julie').delete();
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [MemberStatus.pending, null]);
    });

    test('should pass on a request it cannot read', () async {
      await db.doc('sectors/t49/members/uid-julie').set({'status': 'pending'});

      await expectLater(
        directory.watchRequest(sectorId, julieId).first,
        throwsFormatException,
      );
    });

    test('should delete the request when it is cancelled', () async {
      await directory.requestToJoin(julieRequest);
      await pumpEventQueue();

      await directory.cancelRequest(sectorId, julieId, null);
      await pumpEventQueue();

      expect(await stored('sectors/t49/members/uid-julie'), isNull);
      // A request of before #148 held no name: nothing else is deleted.
      expect(await stored('sectors/t49/names/julie'), {'member': 'uid-julie'});
    });

    test('should free the name with the request cancelled', () async {
      await directory.requestToJoin(julieRequest);

      await directory.cancelRequest(sectorId, julieId, nameOf('JULIE'));
      await pumpEventQueue();

      expect(await stored('sectors/t49/members/uid-julie'), isNull);
      expect(await stored('sectors/t49/names/julie'), isNull);
    });
  });

  group('a request holding its name', () {
    test('should hold the name under its key with the request', () async {
      final sent = await directory.requestToJoin(julieRequest);

      expect(sent, isA<Ok<void, JoinRequestFailure>>());
      expect(await stored('sectors/t49/names/julie'), {'member': 'uid-julie'});
    });

    test('should send nothing when a member holds the name', () async {
      await db.doc('sectors/t49/names/julie').set({'member': 'uid-lea'});

      final sent = await directory.requestToJoin(julieRequest);

      expect(failureOf(sent), JoinRequestFailure.nameTaken);
      expect(await stored('sectors/t49/members/uid-julie'), isNull);
      expect(await stored('sectors/t49/names/julie'), {'member': 'uid-lea'});
    });

    test('should send the request when the name is already the '
        'newcomer\'s', () async {
      await db.doc('sectors/t49/names/julie').set({'member': 'uid-julie'});

      expect(
        await directory.requestToJoin(julieRequest),
        isA<Ok<void, JoinRequestFailure>>(),
      );

      expect(
        await stored('sectors/t49/members/uid-julie'),
        joinRequestDocument(julieRequest),
      );
    });

    test('should tell when the server cannot be reached', () async {
      offline(db.doc('sectors/t49/names/julie'));

      final sent = await directory.requestToJoin(julieRequest);

      expect(failureOf(sent), JoinRequestFailure.noNetwork);
      expect(await stored('sectors/t49/members/uid-julie'), isNull);
    });

    test('should tell the name is taken when the server refuses while the '
        'code still opens the secteur', () async {
      // The rules refuse a newcomer the entry of a name another member
      // holds.
      await db.doc('joinCodes/K7P2QX').set(joinCodeDocument(team()));
      offline(db.doc('sectors/t49/names/julie'), 'permission-denied');

      final sent = await directory.requestToJoin(julieRequest);

      expect(failureOf(sent), JoinRequestFailure.nameTaken);
    });

    test('should tell the code no longer works when the server refuses and '
        'the code opens nothing', () async {
      offline(db.doc('sectors/t49/names/julie'), 'permission-denied');

      final sent = await directory.requestToJoin(julieRequest);

      expect(failureOf(sent), JoinRequestFailure.unknownCode);
    });

    test('should tell the code no longer works when the server refuses and '
        'the code opens another secteur', () async {
      await db.doc('joinCodes/K7P2QX').set({
        ...joinCodeDocument(team()),
        'sectorId': 't12',
      });
      offline(db.doc('sectors/t49/names/julie'), 'permission-denied');

      final sent = await directory.requestToJoin(julieRequest);

      expect(failureOf(sent), JoinRequestFailure.unknownCode);
    });

    test('should tell when the server refuses and cannot be reached '
        'again', () async {
      offline(db.doc('sectors/t49/names/julie'), 'permission-denied');
      offline(db.doc('joinCodes/K7P2QX'));

      final sent = await directory.requestToJoin(julieRequest);

      expect(failureOf(sent), JoinRequestFailure.noNetwork);
    });

    test('should throw any other failure of the server', () async {
      offline(db.doc('sectors/t49/names/julie'), 'internal');

      await expectLater(
        directory.requestToJoin(julieRequest),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('membership', () {
    Future<List<SectorLoss>> lossesWhile(Future<void> Function() change) async {
      final seen = <SectorLoss>[];
      final subscription = directory
          .watchMembership(sector49, leaId)
          .listen(seen.add);
      await pumpEventQueue();
      await change();
      await pumpEventQueue();
      await subscription.cancel();
      return seen;
    }

    setUp(() async {
      await db.doc('sectors/t49').set(sectorToDocument(team()));
      await db.doc('sectors/t49/members/uid-lea').set(memberToDocument(lea));
    });

    test('should tell nothing while the member is in', () async {
      final seen = await lossesWhile(() async {});

      expect(seen, isEmpty);
    });

    test('should tell removed once the member document goes and the '
        'server refuses the secteur (#147)', () async {
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('sectors/t49'))
          .thenThrow(firestoreError('permission-denied'));

      final seen = await lossesWhile(
        () => db.doc('sectors/t49/members/uid-lea').delete(),
      );

      expect(seen, [SectorLoss.removed]);
    });

    test('should tell removed once the member document goes and the '
        'secteur stays readable (an admin)', () async {
      final seen = await lossesWhile(
        () => db.doc('sectors/t49/members/uid-lea').delete(),
      );

      expect(seen, [SectorLoss.removed]);
    });

    test('should tell deleted once the member document goes with the '
        'secteur', () async {
      // One batch, as the deletion makes it. Firestore applies a batch
      // at once; the fake applies it in order, so the secteur goes first.
      final seen = await lossesWhile(
        () async =>
            (db.batch()
                  ..delete(db.doc('sectors/t49'))
                  ..delete(db.doc('sectors/t49/members/uid-lea')))
                .commit(),
      );

      expect(seen, [SectorLoss.deleted]);
    });

    test('should ask the server, not the phone\'s copy, whether the '
        'secteur still exists', () async {
      offline(db.doc('sectors/t49'));
      final errors = <Object>[];
      final subscription = directory
          .watchMembership(sector49, leaId)
          .listen((_) {}, onError: errors.add);
      await pumpEventQueue();

      await db.doc('sectors/t49/members/uid-lea').delete();
      await pumpEventQueue();
      await subscription.cancel();

      expect(errors.single, isA<FirebaseException>());
    });
  });

  group('visit', () {
    // Sam, an admin, opened the 49 without being in its team (PLAN §5.12).
    final visited = summaryOf('t49', 49, status: MemberStatus.visiting);

    Future<List<SectorLoss>> lossesWhile(Future<void> Function() change) async {
      final seen = <SectorLoss>[];
      final subscription = directory
          .watchMembership(visited, samId)
          .listen(seen.add);
      await pumpEventQueue();
      await change();
      await pumpEventQueue();
      await subscription.cancel();
      return seen;
    }

    setUp(() async {
      await db.doc('admins/uid-sam').set(<String, Object?>{});
      await db.doc('sectorKeys/villefranche_49').set({'sectorId': 't49'});
      await db.doc('sectors/t49').set(sectorToDocument(team()));
    });

    test('should tell nothing while the secteur stays and the phone is an '
        'admin', () async {
      final seen = await lossesWhile(() async {});

      expect(seen, isEmpty);
    });

    test('should not take the missing member document for a '
        'removal', () async {
      // A visitor has none: following it would say « retiré » at once.
      final seen = await lossesWhile(
        () => db.doc('sectors/t49/members/uid-sam').delete(),
      );

      expect(seen, isEmpty);
    });

    test('should tell deleted once the secteur goes', () async {
      final seen = await lossesWhile(() => db.doc('sectors/t49').delete());

      expect(seen, [SectorLoss.deleted]);
    });

    test('should tell the admin was revoked once their admin document '
        'goes', () async {
      final seen = await lossesWhile(() => db.doc('admins/uid-sam').delete());

      expect(seen, [SectorLoss.adminRevoked]);
    });
  });

  group('allSectors', () {
    test('should list every secteur with its team counted for the '
        'caller', () async {
      await db.doc('sectors/t49').set(sectorToDocument(team()));
      for (final member in [manu, lea, julie]) {
        await db
            .doc('sectors/t49/members/${member.id.value}')
            .set(memberToDocument(member));
      }
      await db.doc('sectors/t12').set({
        ...sectorToDocument(team()),
        'number': 12,
      });

      final all = valueOf(await directory.allSectors(leaId));

      expect(all, [
        overviewOf(team(), leaId),
        overviewOf(
          valueOf(
            Sector.create(
              id: SectorId('t12'),
              number: valueOf(SectorNumber.create(12)),
              centre: csVillefranche,
              joinCode: firstCode,
              createdBy: manuId,
              createdAt: createdAt,
              currentCampaign: campaign2026,
              members: const [],
            ),
          ),
          leaId,
        ),
      ]);
    });

    test('should leave out a secteur it cannot read', () async {
      await db.doc('sectors/t49').set(sectorToDocument(team()));
      await db.doc('sectors/broken').set({'number': 'quarante'});

      final all = valueOf(await directory.allSectors(samId));

      expect(all.map((sector) => sector.id), [sectorId]);
    });

    test('should list nothing when the app has no secteur', () async {
      expect(valueOf(await directory.allSectors(samId)), isEmpty);
    });

    test('should tell when the server cannot be reached', () async {
      await db.doc('sectors/t49').set(sectorToDocument(team()));
      // The in-memory Firestore reads a collection document by document.
      offline(db.doc('sectors/t49'));

      final all = await directory.allSectors(samId);

      expect(failureOf(all), DirectoryFailure.noNetwork);
    });

    test(
      'should tell when the server says the caller is not an admin',
      () async {
        await db.doc('sectors/t49').set(sectorToDocument(team()));
        // What the security rules answer once `admins/{uid}` is gone.
        offline(db.doc('sectors/t49'), 'permission-denied');

        final all = await directory.allSectors(samId);

        expect(failureOf(all), DirectoryFailure.notAdmin);
      },
    );

    test('should throw any other failure of the server', () async {
      await db.doc('sectors/t49').set(sectorToDocument(team()));
      offline(db.doc('sectors/t49'), 'internal');

      await expectLater(
        directory.allSectors(samId),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('own name', () {
    Future<List<MemberName>> namesWhile(Future<void> Function() change) async {
      final seen = <MemberName>[];
      final subscription = directory
          .watchOwnName(sectorId, julieId)
          .listen(seen.add);
      await pumpEventQueue();
      await change();
      await pumpEventQueue();
      await subscription.cancel();
      return seen;
    }

    test('should tell the name once the request is accepted, then each '
        'new one', () async {
      await directory.requestToJoin(julieRequest);
      await pumpEventQueue();

      final seen = await namesWhile(() async {
        await db.doc('sectors/t49/members/uid-julie').update({
          'status': 'active',
          'acceptedBy': 'uid-manu',
          'acceptedAt': Timestamp.fromDate(leaAcceptedAt),
        });
        await pumpEventQueue();
        await db.doc('sectors/t49/members/uid-julie').update({
          'displayName': 'Juliette',
        });
      });

      expect(seen, [nameOf('Julie'), nameOf('Juliette')]);
    });

    test('should tell nothing while there is no member document', () async {
      final seen = await namesWhile(() async {});

      expect(seen, isEmpty);
    });
  });

  group('isTaken', () {
    test(
      'should say a number is taken in the same station however written',
      () async {
        await db.doc('sectorKeys/villefranche_49').set({'sectorId': 't49'});

        final taken = await directory.isTaken(
          centre('CIS Villefranche'),
          number49,
        );

        expect(valueOf(taken), isTrue);
      },
    );

    test('should say a number is free in another station', () async {
      await db.doc('sectorKeys/villefranche_49').set({'sectorId': 't49'});

      final taken = await directory.isTaken(
        centre('CS Villefranche Nord'),
        number49,
      );

      expect(valueOf(taken), isFalse);
    });

    test('should say another number is free in the same station', () async {
      await db.doc('sectorKeys/villefranche_49').set({'sectorId': 't49'});

      final taken = await directory.isTaken(
        csVillefranche,
        valueOf(SectorNumber.create(50)),
      );

      expect(valueOf(taken), isFalse);
    });

    test('should tell when the server cannot be reached', () async {
      offline(db.doc('sectorKeys/villefranche_49'));

      final taken = await directory.isTaken(csVillefranche, number49);

      expect(failureOf(taken), DirectoryFailure.noNetwork);
    });

    test('should tell when the server refuses: only an admin may ask '
        '(#147)', () async {
      offline(db.doc('sectorKeys/villefranche_49'), 'permission-denied');

      final taken = await directory.isTaken(csVillefranche, number49);

      expect(failureOf(taken), DirectoryFailure.notAdmin);
    });
  });

  group('other failures', () {
    test('should throw any other failure when checking a number', () async {
      offline(db.doc('sectorKeys/villefranche_49'), 'internal');

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
