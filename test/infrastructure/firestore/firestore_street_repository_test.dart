// The streets of a campaign in Firestore, against an in-memory Firestore
// (fake_cloud_firestore, PLAN §11): several phones share one database, each
// with its own repository.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_writes.dart';
import 'package:tournee_calendriers/infrastructure/firestore/unfinished_streets.dart';

import '../../domain/sector/sector_fixtures.dart' show campaign2026;
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_unfinished_streets.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../local_storage/stored_street_fixtures.dart';

const streetsPath = 'sectors/t49/campaigns/2026/streets';

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

/// Rue de la Paix with the houses 1 to [count], each unmarked.
Street _paixOf(int count) => valueOf(
  Street.create(
    id: StreetId('paix'),
    name: 'Rue de la Paix',
    commune: villefranche,
    houses: [for (var i = 1; i <= count; i++) House(number: n('$i'))],
  ),
);

/// Lets the writes in the background run until [isDone], for at most a
/// few hundred turns of the event queue: a street of many houses is
/// written one update after the other, each after the phone's copy shows
/// the one before.
Future<void> _settle(Future<bool> Function() isDone) async {
  for (var turn = 0; turn < 500 && !await isDone(); turn++) {
    await pumpEventQueue();
  }
}

/// The entry of the house [label] of [street], as its document holds it.
Object? houseEntryOf(Street street, String label) =>
    (streetToDocument(street)['houses']! as Map<String, Object?>)[label];

void main() {
  late FakeFirebaseFirestore db;
  final repositories = <FirestoreStreetRepository>[];

  /// The repository of one phone of the team, used by [member], with
  /// [unfinished] as its phone storage of the streets being written.
  FirestoreStreetRepository phone([
    String member = 'lea',
    UnfinishedStreets? unfinished,
    FakeFirebaseFirestore? on,
  ]) {
    final repository = FirestoreStreetRepository(
      on ?? db,
      sector: SectorId('t49'),
      campaign: campaign2026,
      identity: FakeIdentity(MemberId(member)),
      clock: FakeClock(fourPm),
      unfinished: unfinished ?? FakeUnfinishedStreets(),
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

    test('should store a street of more houses than one write holds '
        'whole', () async {
      final paix = valueOf(
        Street.create(
          id: StreetId('paix'),
          name: 'Rue de la Paix',
          commune: villefranche,
          houses: [
            for (var i = 1; i <= 2 * housesPerWrite + 1; i++)
              House(number: n('$i')),
          ],
        ),
      );
      await phone().add(paix);
      await pumpEventQueue();

      final stored = await db.doc('$streetsPath/paix').get();
      // The order of the writes is newStreetWrites' (its tests): the
      // in-memory Firestore gives a listener only the last version.
      expect(stored.data(), streetToDocument(paix));
    });

    test('should store a street of a hundred numbers whole, for the other '
        'phones', () async {
      final paix = _paixOf(101);

      await phone().add(paix);
      await _settle(() async {
        final stored = (await db.doc('$streetsPath/paix').get()).data();
        return (stored?['houses'] as Map<String, dynamic>?)?.length == 101;
      });

      final stored = await db.doc('$streetsPath/paix').get();
      expect(stored.data(), streetToDocument(paix));
      expectSameStreet((await phone('paul').find(paix.id))!, paix);
    });

    test('should have the whole street on this phone as soon as it is '
        'added', () async {
      final paix = _paixOf(101);
      final streets = phone();

      await streets.add(paix);

      expectSameStreet((await streets.find(paix.id))!, paix);
    });

    test('should keep a mark made on a house not yet sent', () async {
      final paix = _paixOf(101);
      final streets = phone();
      await streets.add(paix);
      final (marked, change) = valueOf(
        paix.markHouse(
          n('101'),
          VisitStatus.done,
          by: MemberId('lea'),
          at: twoPm,
        ),
      );

      // At once: the last houses are not written yet.
      await streets.save(marked, change);
      await _settle(() async {
        final stored = (await db.doc('$streetsPath/paix').get()).data();
        final houses = stored?['houses'] as Map<String, dynamic>?;
        return (houses?['101'] as Map<String, dynamic>?)?['status'] == 'DONE';
      });

      expect(await storedHouse('paix', '101'), houseEntryOf(marked, '101'));
    });
  });

  group('killed in the middle (#104)', () {
    /// How many houses the stored street [id] of [on] holds; null when it
    /// is not stored.
    Future<int?> storedHouses(FakeFirebaseFirestore on, String id) async {
      final stored = (await on.doc('$streetsPath/$id').get()).data();
      return (stored?['houses'] as Map<String, dynamic>?)?.length;
    }

    test('should keep a street of more houses than one write holds on the '
        'phone before its first write', () async {
      final unfinished = FakeUnfinishedStreets()..slowDisk = Completer();
      final paix = _paixOf(housesPerWrite + 1);

      await phone('lea', unfinished).add(paix);
      await pumpEventQueue();

      expect(unfinished.keptEver, [paix.id]);
      expect(await storedHouses(db, 'paix'), isNull);

      unfinished.slowDisk!.complete();
      await _settle(() async => unfinished.forgotten.isNotEmpty);

      expect(await storedHouses(db, 'paix'), housesPerWrite + 1);
    });

    test('should not keep a street that one write holds', () async {
      final unfinished = FakeUnfinishedStreets();

      await phone('lea', unfinished).add(_paixOf(housesPerWrite));
      await pumpEventQueue();

      expect(await storedHouses(db, 'paix'), housesPerWrite);
      expect(unfinished.keptEver, isEmpty);
      expect(unfinished.forgotten, isEmpty);
    });

    test('should hold back a mark made while the street is being kept '
        'until after its writes', () async {
      final unfinished = FakeUnfinishedStreets()..slowDisk = Completer();
      final paix = _paixOf(5);
      final streets = phone('lea', unfinished);
      await streets.add(paix);
      final (marked, change) = valueOf(
        paix.markHouse(
          n('5'),
          VisitStatus.done,
          by: MemberId('lea'),
          at: twoPm,
        ),
      );

      await streets.save(marked, change);
      unfinished.slowDisk!.complete();
      await _settle(() async => unfinished.forgotten.isNotEmpty);
      await pumpEventQueue();

      expect(await storedHouse('paix', '5'), houseEntryOf(marked, '5'));
      expect(await storedHouses(db, 'paix'), 5);
    });

    test('should forget the street once its writes are all handed to '
        'Firestore', () async {
      final unfinished = FakeUnfinishedStreets();
      final paix = _paixOf(101);

      await phone('lea', unfinished).add(paix);
      await _settle(() async => unfinished.forgotten.isNotEmpty);

      expect(await storedHouses(db, 'paix'), 101);
      expect(unfinished.forgotten, [paix.id]);
      expect(unfinished.kept, isEmpty);
    });

    test('should write the street all the same when the phone cannot keep '
        'it', () async {
      final unfinished = FakeUnfinishedStreets()..keepFails = true;
      final paix = _paixOf(11);

      await phone('lea', unfinished).add(paix);
      await _settle(() async => await storedHouses(db, 'paix') == 11);

      expect(
        (await db.doc('$streetsPath/paix').get()).data(),
        streetToDocument(paix),
      );
    });

    test('should show the street whole on this phone while its writes '
        'go', () async {
      final paix = _paixOf(101);
      final streets = phone();
      final counts = <int>[];
      final watching = streets
          .watch(paix.id)
          .listen((street) => counts.add(street?.houses.length ?? 0));
      await pumpEventQueue();

      await streets.add(paix);
      await _settle(() async => await storedHouses(db, 'paix') == 101);
      await watching.cancel();

      // Firestore told this phone of the street growing many times; it
      // never showed less than the whole street.
      expect(counts.first, 0);
      expect(counts.skip(1), isNotEmpty);
      expect(counts.skip(1).toSet(), {101});
    });

    test('should find the street whole after a restart, when the app was '
        'killed halfway through its writes', () async {
      final unfinished = FakeUnfinishedStreets();
      final paix = _paixOf(101);
      // The kill: what Firestore's copy on the phone and the phone storage
      // hold the moment the copy first shows half the street is all a
      // restart finds. Taken in the listener itself, before the next write.
      Map<String, dynamic>? copy;
      FakeUnfinishedStreets? kept;
      final killing = db.doc('$streetsPath/paix').snapshots().listen((
        snapshot,
      ) {
        final houses = snapshot.data()?['houses'] as Map<String, dynamic>?;
        if (copy == null && (houses?.length ?? 0) >= 50) {
          copy = snapshot.data();
          kept = unfinished.copy();
        }
      });
      await phone('lea', unfinished).add(paix);
      await _settle(() async => copy != null);
      await killing.cancel();
      final afterKill = FakeFirebaseFirestore();
      await afterKill.doc('$streetsPath/paix').set(copy!);
      expect((copy!['houses'] as Map<String, dynamic>).length, lessThan(101));
      expect(kept!.kept.keys, [paix.id]);

      final restarted = phone('lea', kept, afterKill);
      await restarted.find(paix.id);
      await _settle(() async => kept!.kept.isEmpty);

      expect(
        (await afterKill.doc('$streetsPath/paix').get()).data(),
        streetToDocument(paix),
      );
      expectSameStreet((await restarted.find(paix.id))!, paix);
      expectSameStreet(
        (await phone('paul', null, afterKill).find(paix.id))!,
        paix,
      );
    });

    test('should leave the houses a teammate marked since the kill as they '
        'are', () async {
      final paix = _paixOf(5);
      final partial = streetToDocument(paix);
      final houses = partial['houses']! as Map<String, Object?>;
      await db.doc('$streetsPath/paix').set({
        ...partial,
        'houses': {
          '1': {
            ...houses['1']! as Map<String, Object?>,
            'status': 'DONE',
            'by': 'paul',
            'at': Timestamp.fromDate(twoPm),
          },
          '2': houses['2'],
        },
      });
      final kept = FakeUnfinishedStreets([paix]);

      await phone('lea', kept).find(paix.id);
      await _settle(() async => kept.kept.isEmpty);

      expect((await storedHouse('paix', '1'))['by'], 'paul');
      expect(await storedHouse('paix', '5'), houseEntryOf(paix, '5'));
      expect(await storedHouses(db, 'paix'), 5);
    });

    test('should write the street again whole when not even its document '
        'reached Firestore', () async {
      final paix = _paixOf(5);
      final kept = FakeUnfinishedStreets([paix]);
      final streets = phone('lea', kept);

      await streets.watchAll().first;
      expectSameStreet((await streets.find(paix.id))!, paix);
      await _settle(() async => kept.kept.isEmpty);

      expect(
        (await db.doc('$streetsPath/paix').get()).data(),
        streetToDocument(paix),
      );
    });

    test('should only forget a street whose writes all reached Firestore '
        'before the kill', () async {
      await db.doc('$streetsPath/lilas').set(streetToDocument(lilas));
      final kept = FakeUnfinishedStreets([lilas]);
      final updates = <Object?>[];
      final following = db
          .doc('$streetsPath/lilas')
          .snapshots()
          .listen((snapshot) => updates.add(snapshot.data()));
      await pumpEventQueue();

      await phone('lea', kept).find(lilas.id);
      await _settle(() async => kept.kept.isEmpty);
      await following.cancel();

      expect(kept.forgotten, [lilas.id]);
      expect(updates, hasLength(1));
    });

    test('should still answer when the phone storage cannot be read', () async {
      await phone().add(lilas);
      await pumpEventQueue();
      final unreadable = FakeUnfinishedStreets()..loadFails = true;

      final found = await phone('lea', unreadable).find(lilas.id);
      await pumpEventQueue();

      expectSameStreet(found!, lilas);
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

    test('should keep two members taking the street at once', () async {
      await phone().add(lilas);
      await pumpEventQueue();
      final lea = phone('lea');
      final paul = phone('paul');
      final leaSees = (await lea.find(lilas.id))!;
      final paulSees = (await paul.find(lilas.id))!;

      final (leaTook, leaChange) = valueOf(leaSees.take(MemberId('lea')));
      final (paulTook, paulChange) = valueOf(paulSees.take(MemberId('paul')));
      await lea.save(leaTook, leaChange);
      await paul.save(paulTook, paulChange);
      await pumpEventQueue();

      final both = (await phone('manu').find(lilas.id))!;
      expect(both.assignees, {MemberId('lea'), MemberId('paul')});
    });

    test('should keep a teammate covering the street when one releases '
        'it', () async {
      final (shared, _) = valueOf(lilas.take(MemberId('lea')));
      await phone().add(valueOf(shared.take(MemberId('paul'))).$1);
      await pumpEventQueue();
      final lea = phone('lea');
      final leaSees = (await lea.find(lilas.id))!;

      final (released, change) = valueOf(leaSees.release(MemberId('lea')));
      await lea.save(released, change);
      await pumpEventQueue();

      final stored = (await db.doc('$streetsPath/lilas').get()).data()!;
      expect(stored['assignees'], ['paul']);
    });

    test('should store the shape found for a street without one', () async {
      await phone().add(lilas);
      await pumpEventQueue();
      final streets = phone();
      final shape = StreetShape([
        [at(45.98915, 4.71862), at(45.99210, 4.71705)],
      ]);

      final (filled, change) = valueOf(
        (await streets.find(lilas.id))!.fillShape(shape),
      );
      await streets.save(filled, change);
      await pumpEventQueue();

      final stored = (await db.doc('$streetsPath/lilas').get()).data()!;
      expect(stored['shape'], shape.encode());
      expect((await phone('paul').find(lilas.id))!.shape, shape);
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
        'calendars': 1,
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

    test(
      'should store the tries of a house and drop them when to do again',
      () async {
        await phone().add(lilas);
        await pumpEventQueue();
        final streets = phone();
        final lea = MemberId('lea');
        var street = (await streets.find(lilas.id))!;
        final (nobody, first) = valueOf(
          street.markHouse(n('1'), VisitStatus.nobodyHome, by: lea, at: twoPm),
        );
        await streets.save(nobody, first);
        final (again, second) = valueOf(
          nobody.markNobodyHomeAgain(n('1'), by: lea, at: twoPm),
        );
        await streets.save(again, second);
        await pumpEventQueue();

        expect((await storedHouse('lilas', '1'))['tries'], 2);

        street = (await streets.find(lilas.id))!;
        final (toDo, reset) = valueOf(
          street.markHouse(n('1'), VisitStatus.toDo, by: lea, at: twoPm),
        );
        await streets.save(toDo, reset);
        await pumpEventQueue();

        expect((await storedHouse('lilas', '1')).containsKey('tries'), isFalse);
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

  group('purge', () {
    test('should forget the street on this phone at once', () async {
      final streets = phone();
      await streets.add(lilas);
      await pumpEventQueue();

      await streets.purge(lilas.id);

      expect(await streets.find(lilas.id), isNull);
    });

    test('should delete the street document for the whole team', () async {
      await phone().add(lilas);
      await phone().add(_street('roses'));
      await pumpEventQueue();

      await phone().purge(lilas.id);
      await pumpEventQueue();

      expect((await db.doc('$streetsPath/lilas').get()).exists, isFalse);
      expect((await db.doc('$streetsPath/roses').get()).exists, isTrue);
      expect(await phone('paul').find(lilas.id), isNull);
    });

    test('should drop the purged numbers from the street document', () async {
      final street = valueOf(
        lilas.removeNumber(n('1'), by: MemberId('paul'), at: twoPm),
      ).$1;
      await phone().add(street);
      await pumpEventQueue();
      final streets = phone();
      final (purged, change) = (await streets.find(lilas.id))!
          .purgeNumbers(now: twoPm.add(const Duration(days: 31)))!;

      await streets.save(purged, change);
      await pumpEventQueue();

      final data = (await db.doc('$streetsPath/lilas').get()).data()!;
      expect((data['houses'] as Map<String, dynamic>).keys, ['2']);
      final seen = (await phone('paul').find(lilas.id))!;
      expect(seen.removedHouses, isEmpty);
      expect(seen.houses.map((house) => house.number), [n('2')]);
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

    test(
      'should say online once the listener answers from the server',
      () async {
        final streets = phone();
        await streets.add(lilas);
        await pumpEventQueue();

        expect(await streets.watchOffline().first, isFalse);
      },
    );
  });
}
