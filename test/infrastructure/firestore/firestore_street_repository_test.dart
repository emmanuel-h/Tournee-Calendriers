// The streets of a campaign in Firestore, against an in-memory Firestore
// (fake_cloud_firestore, PLAN §11): several phones share one database, each
// with its own repository.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';

import '../../domain/tournee/tournee_fixtures.dart' show campaign2026;
import '../../support/fakes/fake_ports.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../local_storage/stored_street_fixtures.dart';

const streetsPath = 'tournees/t49/campaigns/2026/streets';

Street _street(String id, {String? banId}) => valueOf(
  Street.create(
    id: StreetId(id),
    name: 'Rue $id',
    commune: villefranche,
    banId: banId == null ? null : BanStreetId(banId),
    houses: [
      House(number: n('1')),
      House(number: n('2')),
    ],
  ),
);

final lilas = _street('lilas', banId: '69264_0420');

final fourPm = DateTime.utc(2026, 11, 2, 16);

void main() {
  late FakeFirebaseFirestore db;
  final repositories = <FirestoreStreetRepository>[];

  /// The repository of one phone of the team, used by [member].
  FirestoreStreetRepository phone([String member = 'lea']) {
    final repository = FirestoreStreetRepository(
      db,
      tournee: TourneeId('t49'),
      campaign: campaign2026,
      identity: FakeIdentity(MemberId(member)),
      clock: FakeClock(fourPm),
    );
    repositories.add(repository);
    return repository;
  }

  /// The house [label] of the street [id] as stored now.
  Future<Map<String, dynamic>> storedHouse(String id, String label) async {
    final data = (await db.doc('$streetsPath/$id').get()).data()!;
    return (data['houses'] as Map<String, dynamic>)[label]
        as Map<String, dynamic>;
  }

  setUp(() => db = FakeFirebaseFirestore());

  tearDown(() async {
    for (final repository in repositories) {
      await repository.close();
    }
    repositories.clear();
  });

  group('add', () {
    test('should store a new street whole, for the other phones', () async {
      await phone().add(richStreet);
      await pumpEventQueue();

      final found = await phone('paul').find(richStreet.id);

      expectSameStreet(found!, richStreet);
    });

    test('should store the street under its id in the campaign', () async {
      await phone().add(lilas);
      await pumpEventQueue();

      final stored = await db.doc('$streetsPath/lilas').get();

      expect(stored.data(), streetToDocument(lilas));
    });
  });

  group('save', () {
    test('should keep two marks made at once on different houses', () async {
      await phone().add(lilas);
      await pumpEventQueue();
      final lea = phone('lea');
      final paul = phone('paul');
      // Both phones read the street before either marks it.
      final leaSees = (await lea.find(lilas.id))!;
      final paulSees = (await paul.find(lilas.id))!;

      final (leaMarked, leaChange) = valueOf(
        leaSees.markHouse(
          n('1'),
          VisitStatus.done,
          by: MemberId('lea'),
          at: twoPm,
        ),
      );
      final (paulMarked, paulChange) = valueOf(
        paulSees.markHouse(
          n('2'),
          VisitStatus.nobodyHome,
          by: MemberId('paul'),
          at: threePm,
        ),
      );
      await lea.save(leaMarked, leaChange);
      await paul.save(paulMarked, paulChange);
      await pumpEventQueue();

      final both = (await phone('manu').find(lilas.id))!;
      expect(both.houses.map((house) => house.status), [
        VisitStatus.done,
        VisitStatus.nobodyHome,
      ]);
      expect(both.houses.first.lastChange!.by, MemberId('lea'));
      expect(both.houses.last.lastChange!.by, MemberId('paul'));
    });

    test('should write only the fields the change names', () async {
      await phone().add(lilas);
      await pumpEventQueue();
      final streets = phone();
      final street = (await streets.find(lilas.id))!;
      // A field this version does not know, added by a later one: a write
      // of the whole street would wipe it.
      await db.doc('$streetsPath/lilas').update({
        'assignees': ['paul'],
      });

      final (marked, change) = valueOf(
        street.markHouse(
          n('1'),
          VisitStatus.done,
          by: MemberId('lea'),
          at: twoPm,
        ),
      );
      await streets.save(marked, change);
      await pumpEventQueue();

      final stored = (await db.doc('$streetsPath/lilas').get()).data()!;
      expect(stored['assignees'], ['paul']);
      expect(await storedHouse('lilas', '1'), {
        ...houseEntry(House(number: n('1'))),
        'status': 'DONE',
        'by': 'lea',
        'at': Timestamp.fromDate(twoPm),
      });
    });

    test(
      'should find the changed street at once, before Firestore answers',
      () async {
        await phone().add(lilas);
        await pumpEventQueue();
        final streets = phone();
        final street = (await streets.find(lilas.id))!;
        final (marked, change) = valueOf(
          street.markHouse(
            n('1'),
            VisitStatus.done,
            by: MemberId('lea'),
            at: twoPm,
          ),
        );

        // Not awaited: the next tap may come before the write completes.
        final saving = streets.save(marked, change);
        final found = await streets.find(lilas.id);
        await saving;

        expect(found!.houses.first.status, VisitStatus.done);
      },
    );

    test('should stamp an undo with who undoes and when', () async {
      await phone().add(lilas);
      await pumpEventQueue();
      final streets = phone('manu');
      final street = (await streets.find(lilas.id))!;
      final (marked, change) = valueOf(
        street.markHouse(
          n('1'),
          VisitStatus.done,
          by: MemberId('manu'),
          at: twoPm,
        ),
      );
      await streets.save(marked, change);
      final (undone, undo) = valueOf(marked.undo(change));

      await streets.save(undone, undo);
      await pumpEventQueue();

      final house = await storedHouse('lilas', '1');
      expect(house['status'], 'TO_DO');
      expect(house['by'], 'manu');
      expect(house['at'], Timestamp.fromDate(fourPm));
    });

    test(
      'should store new and restored numbers sent in several updates',
      () async {
        await phone().add(lilas);
        await pumpEventQueue();
        final streets = phone();
        final (removed, removal) = valueOf(
          (await streets.find(lilas.id))!
              .removeNumber(n('2'), by: MemberId('lea'), at: twoPm),
        );
        await streets.save(removed, removal);
        final (added, change) = valueOf(removed.addNumbers([n('2'), n('3')]));

        await streets.save(added, change);
        await pumpEventQueue();

        final found = (await phone('paul').find(lilas.id))!;
        expect(found.houses.map((house) => house.number.label), [
          '1',
          '2',
          '3',
        ]);
        expect(found.removedHouses, isEmpty);
      },
    );

    test('should not throw when Firestore refuses the write', () async {
      await phone().add(lilas);
      await pumpEventQueue();
      final streets = phone();
      final street = (await streets.find(lilas.id))!;
      whenCalling(Invocation.method(#update, null))
          .on(db.doc('$streetsPath/lilas'))
          .thenThrow(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );
      final (marked, change) = valueOf(
        street.markHouse(
          n('1'),
          VisitStatus.done,
          by: MemberId('lea'),
          at: twoPm,
        ),
      );

      await streets.save(marked, change);
      await pumpEventQueue();

      expect((await storedHouse('lilas', '1'))['status'], 'TO_DO');
    });
  });

  group('find', () {
    test('should find nothing in an empty campaign', () async {
      expect(await phone().find(lilas.id), isNull);
    });

    test('should find a street by its BAN id, in the Corbeille too', () async {
      final (deleted, _) = lilas.delete(by: MemberId('lea'), at: twoPm);
      await phone().add(deleted);
      await phone().add(_street('roses', banId: '69264_0680'));
      await pumpEventQueue();

      final streets = phone('paul');

      expect(
        (await streets.findByBanId(BanStreetId('69264_0420')))!.id,
        lilas.id,
      );
      expect(await streets.findByBanId(BanStreetId('69264_9999')), isNull);
    });

    test('should leave out a street it cannot read', () async {
      await db.doc('$streetsPath/broken').set({'name': 'Rue cassée'});
      await phone().add(lilas);
      await pumpEventQueue();

      final streets = phone('paul');

      expect(await streets.find(StreetId('broken')), isNull);
      expect(await streets.find(lilas.id), isNotNull);
    });
  });

  group('watch', () {
    test('should follow the marks of a teammate live', () async {
      await phone().add(lilas);
      await pumpEventQueue();
      final seen = <VisitStatus?>[];
      final subscription = phone('lea')
          .watch(lilas.id)
          .listen((street) => seen.add(street?.houses.first.status));
      await pumpEventQueue();

      final paul = phone('paul');
      final street = (await paul.find(lilas.id))!;
      final (marked, change) = valueOf(
        street.markHouse(
          n('1'),
          VisitStatus.done,
          by: MemberId('paul'),
          at: threePm,
        ),
      );
      await paul.save(marked, change);
      await pumpEventQueue();
      await db.doc('$streetsPath/lilas').delete();
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [VisitStatus.toDo, VisitStatus.done, null]);
    });

    test('should list the streets out of and in the Corbeille apart', () async {
      final streets = phone();
      await streets.add(lilas);
      await streets.add(_street('roses'));
      await pumpEventQueue();
      final (deleted, change) = lilas.delete(by: MemberId('lea'), at: twoPm);
      await streets.save(deleted, change);
      await pumpEventQueue();

      final other = phone('paul');
      final shown = await other.watchAll().first;
      final binned = await other.watchDeleted().first;

      expect(shown.map((street) => street.id.value), ['roses']);
      expect(binned.map((street) => street.id.value), ['lilas']);
      expect(shown.clear, throwsUnsupportedError);
      expect(binned.clear, throwsUnsupportedError);
    });

    test('should list the streets again after each change', () async {
      final streets = phone();
      await streets.add(lilas);
      await pumpEventQueue();
      final shown = <List<String>>[];
      final binned = <List<String>>[];
      final watching = [
        streets.watchAll().listen(
          (all) => shown.add([for (final street in all) street.id.value]),
        ),
        streets.watchDeleted().listen(
          (all) => binned.add([for (final street in all) street.id.value]),
        ),
      ];
      await pumpEventQueue();

      final (deleted, change) = lilas.delete(by: MemberId('lea'), at: twoPm);
      await streets.save(deleted, change);
      await pumpEventQueue();
      for (final subscription in watching) {
        await subscription.cancel();
      }

      expect(shown.first, ['lilas']);
      expect(shown.last, isEmpty);
      expect(binned.first, isEmpty);
      expect(binned.last, ['lilas']);
    });

    test(
      'should count no street waiting to be sent once all is sent',
      () async {
        final streets = phone();
        await streets.add(lilas);
        await pumpEventQueue();

        expect(await streets.watchUnsentStreets().first, 0);
      },
    );
  });
}
