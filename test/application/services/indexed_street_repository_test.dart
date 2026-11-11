import 'dart:async';

import 'package:test/test.dart';
import 'package:tournee_calendriers/application/services/indexed_street_repository.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/fakes/fake_street_part_index.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../use_cases/street_fixtures.dart';

final _lilasBan = BanStreetId('69264_0420');
final _oddSide = part(odd: SidePart.all, even: SidePart.none);

/// A street typed by hand: no BAN id, so no entry in the index.
final _manual = valueOf(
  Street.create(
    id: StreetId('chemin-a-la-main'),
    name: 'Chemin à la main',
    commune: villefranche,
    houses: [seven],
  ),
);

void main() {
  late FakeStreetRepository inner;
  late FakeStreetPartIndex index;
  late IndexedStreetRepository streets;

  /// The label of each index write handed to the reporter, in order.
  late List<String> reported;

  /// Each reported write that failed: its label and its error.
  late List<(String, Object)> failed;

  // The app's reporter (`sendInBackground`) logs a failure; this one keeps
  // it for the test to look at.
  void report(String what, Future<void> write) {
    reported.add(what);
    unawaited(
      write.then<void>(
        (_) {},
        onError: (Object error) => failed.add((what, error)),
      ),
    );
  }

  IndexedStreetRepository indexed(FakeStreetRepository inner) =>
      IndexedStreetRepository(inner, index, report: report);

  setUp(() {
    reported = [];
    failed = [];
    inner = repositoryWithLilas();
    index = FakeStreetPartIndex();
    streets = indexed(inner);
  });

  group('add', () {
    test('should store the street, then say the secteur holds its part', () {
      final cut = valueOf(
        Street.create(
          id: StreetId('rue-nationale'),
          name: 'Rue Nationale',
          commune: villefranche,
          banId: BanStreetId('69264_0001'),
          part: _oddSide,
          houses: [five],
        ),
      );

      return streets.add(cut).then((_) {
        expect(inner.added, [cut]);
        expect(index.writes, [Held(BanStreetId('69264_0001'), _oddSide)]);
      });
    });

    test('should tell the index only once the street is stored', () async {
      inner = FakeStreetRepository();
      streets = indexed(inner);
      inner.holdAdds = Completer<void>();

      final adding = streets.add(lilas);
      await Future<void>.delayed(Duration.zero);
      expect(index.writes, isEmpty);
      inner.holdAdds!.complete();
      await adding;

      expect(index.writes, [Held(_lilasBan, StreetPart.whole)]);
    });

    test('should leave the index alone for a street typed by hand', () async {
      await streets.add(_manual);

      expect(inner.added, [_manual]);
      expect(index.writes, isEmpty);
    });
  });

  group('save', () {
    test('should say the secteur holds the new part when it changed', () async {
      final (changed, change) = valueOf(
        lilas.changePart(_oddSide, by: lea, at: twoPm),
      );

      await streets.save(changed, change);

      expect(inner.saved, [(changed, change)]);
      expect(index.writes, [Held(_lilasBan, _oddSide)]);
    });

    test('should say the secteur holds none of a street sent to the '
        'Corbeille', () async {
      final (deleted, change) = lilas.delete(by: lea, at: twoPm);

      await streets.save(deleted, change);

      expect(inner.saved, [(deleted, change)]);
      expect(index.writes, [Released(_lilasBan)]);
    });

    test('should say the secteur holds its part again once restored', () async {
      final cut = valueOf(lilas.changePart(_oddSide, by: lea, at: twoPm)).$1;
      final (restored, change) = cut.delete(by: lea, at: twoPm).$1.restore();

      await streets.save(restored, change);

      expect(index.writes, [Held(_lilasBan, _oddSide)]);
    });

    test('should leave the index alone for a mark', () async {
      final (marked, change) = valueOf(
        lilas.markHouse(n('7'), VisitStatus.done, by: lea, at: twoPm),
      );

      await streets.save(marked, change);

      expect(inner.saved, [(marked, change)]);
      expect(index.writes, isEmpty);
    });

    // Every other kind of change, built as storage receives it: none
    // changes what the secteur holds.
    final removedSeven = RemovedHouse(house: seven, removal: leaAtTwo);
    for (final change in <StreetChange>[
      DwellingMarked(
        streetId: lilasId,
        number: n('8'),
        staircase: escA,
        level: 0,
        before: doorOne,
        stamp: leaAtTwo,
        status: VisitStatus.done,
      ),
      StreetShapeFilled(streetId: lilasId, shape: StreetShape.none),
      NumbersAdded(
        streetId: lilasId,
        added: [seven],
        restored: const [],
        alreadyThere: const [],
      ),
      NumberRemoved(streetId: lilasId, removed: removedSeven),
      NumberRestored(streetId: lilasId, removed: removedSeven),
      NumbersPurged(streetId: lilasId, purged: [removedSeven]),
      StreetRenamed(
        streetId: lilasId,
        before: streetName('Rue des Lilas'),
        name: streetName('Rue des Lys'),
      ),
      HouseReverted(
        streetId: lilasId,
        replaced: seven,
        house: seven,
        stamp: leaAtTwo,
      ),
      DwellingReverted(
        streetId: lilasId,
        number: n('8'),
        staircase: escA,
        level: 0,
        replaced: doorOne,
        dwelling: doorOne,
        stamp: leaAtTwo,
      ),
    ]) {
      test('should leave the index alone for ${change.runtimeType}', () async {
        await streets.save(lilas, change);

        expect(inner.saved, [(lilas, change)]);
        expect(index.writes, isEmpty);
      });
    }

    test('should leave the index alone for a street typed by hand sent to '
        'the Corbeille', () async {
      final (deleted, change) = _manual.delete(by: lea, at: twoPm);

      await streets.save(deleted, change);

      expect(inner.saved, [(deleted, change)]);
      expect(index.writes, isEmpty);
    });
  });

  group('purge', () {
    test('should purge the street, then release its entry', () async {
      await streets.purge(lilasId);

      expect(inner.purged, [lilasId]);
      expect(await inner.find(lilasId), isNull);
      expect(index.writes, [Released(_lilasBan)]);
    });

    test(
      'should release nothing for a street typed by hand, or one gone',
      () async {
        inner = FakeStreetRepository([_manual]);
        streets = indexed(inner);

        await streets.purge(_manual.id);
        await streets.purge(StreetId('gone'));

        expect(inner.purged, [_manual.id, StreetId('gone')]);
        expect(index.writes, isEmpty);
      },
    );
  });

  group('reporting', () {
    test('should hand the hold of an added street to the reporter, named '
        'after its BAN id', () async {
      inner = FakeStreetRepository();
      streets = indexed(inner);

      await streets.add(_manual);
      await streets.add(lilas);

      expect(reported, ['index hold 69264_0420']);
    });

    test('should hand a hold and a release to the reporter, named after '
        'the street\'s BAN id', () async {
      final (cut, cutting) = valueOf(
        lilas.changePart(_oddSide, by: lea, at: twoPm),
      );
      final (deleted, deleting) = cut.delete(by: lea, at: twoPm);

      await streets.save(cut, cutting);
      await streets.save(deleted, deleting);

      expect(reported, ['index hold 69264_0420', 'index release 69264_0420']);
    });

    test(
      'should hand the release of a purged street to the reporter',
      () async {
        await streets.purge(lilasId);

        expect(reported, ['index release 69264_0420']);
      },
    );

    test('should end the street write without waiting for the index write '
        'to reach the server', () async {
      index.holdWrites = Completer<void>();
      final (deleted, change) = lilas.delete(by: lea, at: twoPm);

      await streets.save(deleted, change);

      expect(inner.saved, [(deleted, change)]);
      expect(index.writes, [Released(_lilasBan)]);
      index.holdWrites!.complete();
    });

    test('should report a refused index write, the street write still '
        'done', () async {
      final refusal = StateError('refused');
      index.writeError = refusal;
      final (deleted, change) = lilas.delete(by: lea, at: twoPm);

      await streets.save(deleted, change);
      await pumpEventQueue();

      expect(inner.saved, [(deleted, change)]);
      expect(failed, [('index release 69264_0420', refusal)]);
    });
  });

  group('reads', () {
    test('should answer from the streets it wraps', () async {
      final (deleted, change) = valueOf(
        lilas.markHouse(n('7'), VisitStatus.done, by: lea, at: twoPm),
      ).$1.delete(by: lea, at: twoPm);
      final watched = streets.watch(lilasId).first;
      final all = streets.watchAll().first;
      final corbeille = streets.watchDeleted().first;

      expect(await streets.find(lilasId), lilas);
      expect(await streets.findByBanId(_lilasBan), lilas);
      expect(await watched, lilas);
      expect(await all, [lilas]);
      expect(await corbeille, isEmpty);
      await inner.save(deleted, change);
      expect(await streets.watchDeleted().first, [deleted]);
      expect(index.asked, isEmpty);
    });
  });
}
