// The streets the Firestore adapter holds in memory: what the listener
// gives, and this phone's own changes at once (memory first).
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/unreadable_street.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/infrastructure/firestore/street_memory.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

Street street(String id, {bool deleted = false}) {
  final made = valueOf(
    Street.create(
      id: StreetId(id),
      name: 'Rue $id',
      commune: villefranche,
      houses: [House(number: n('1'))],
    ),
  );
  return deleted ? made.delete(by: lea, at: twoPm).$1 : made;
}

final lilas = street('lilas');
final roses = street('roses');

/// Rue Pasteur, whose document cannot be read (#149).
final pasteur = UnreadableStreet(id: StreetId('pasteur'));

/// Rue des Lilas once its document can no longer be read.
final lilasUnreadable = UnreadableStreet(id: lilas.id);

/// The ids of [streets], sorted.
List<String> ids(Iterable<Street> streets) =>
    [for (final street in streets) street.id.value]..sort();

void main() {
  late StreetMemory memory;

  setUp(() => memory = StreetMemory());

  group('streets', () {
    test('should wait for the first answer of the listener', () async {
      var answered = false;
      final streets = memory.streets().then((all) {
        answered = true;
        return all;
      });
      await pumpEventQueue();
      expect(answered, isFalse);

      memory.receive({lilas.id: lilas}, const {});

      expect(ids((await streets).values), ['lilas']);
    });

    test('should take a change of this phone at once', () async {
      memory.receive({lilas.id: lilas}, const {});
      final marked = valueOf(
        lilas.markHouse(n('1'), VisitStatus.done, by: lea, at: twoPm),
      ).$1;

      memory.put(marked);

      expect((await memory.streets())[lilas.id], same(marked));
    });

    test('should forget a street the listener says is gone', () async {
      memory.receive({lilas.id: lilas, roses.id: roses}, const {});

      memory.receive({lilas.id: null}, const {});

      expect(ids((await memory.streets()).values), ['roses']);
    });

    test('should forget a street this phone purges at once', () async {
      memory.receive({lilas.id: lilas, roses.id: roses}, const {});
      final seen = <List<String>>[];
      final subscription = memory
          .observe(
            (streets) => ids(streets.values),
            (changed) => changed.contains(lilas.id),
          )
          .listen(seen.add);
      await pumpEventQueue();

      memory.remove(lilas.id);
      await pumpEventQueue();
      await subscription.cancel();

      expect(ids((await memory.streets()).values), ['roses']);
      expect(seen, [
        ['lilas', 'roses'],
        ['roses'],
      ]);
    });

    test('should throw what made the listener fail', () async {
      memory.fail(StateError('permission-denied'), StackTrace.current);

      await expectLater(memory.streets(), throwsStateError);
    });
  });

  group('observe', () {
    test(
      'should give the value now, then after each change it concerns',
      () async {
        memory.receive({lilas.id: lilas}, const {});
        final seen = <String?>[];
        final subscription = memory
            .observe(
              (streets) => streets[lilas.id]?.houses.single.status.name,
              (changed) => changed.contains(lilas.id),
            )
            .listen(seen.add);
        await pumpEventQueue();

        memory.put(
          valueOf(lilas.markHouse(n('1'), VisitStatus.done, by: lea, at: twoPm))
              .$1,
        );
        memory.receive({roses.id: roses}, const {});
        memory.receive({lilas.id: null}, const {});
        await pumpEventQueue();
        await subscription.cancel();

        expect(seen, ['toDo', 'done', null]);
      },
    );

    test('should pass on a failure of the listener', () async {
      memory.receive({lilas.id: lilas}, const {});
      final errors = <Object>[];
      final subscription = memory
          .observe((streets) => streets.length, (_) => true)
          .listen((_) {}, onError: errors.add);
      await pumpEventQueue();

      final failure = StateError('permission-denied');
      memory.fail(failure, StackTrace.current);
      await pumpEventQueue();
      await subscription.cancel();

      expect(errors, [failure]);
    });

    test('should pass on a failure before the first answer', () async {
      final stream = memory.observe((streets) => streets.length, (_) => true);
      final first = stream.first;

      memory.fail(StateError('permission-denied'), StackTrace.current);

      await expectLater(first, throwsStateError);
    });

    test(
      'should give nothing when the listener leaves before the answer',
      () async {
        final seen = <int>[];
        final subscription = memory
            .observe((streets) => streets.length, (_) => true)
            .listen(seen.add);
        await subscription.cancel();

        memory.receive({lilas.id: lilas}, const {});
        await pumpEventQueue();

        expect(seen, isEmpty);
      },
    );
  });

  group('watchUnsent', () {
    test(
      'should count the streets with writes waiting, each time it changes',
      () async {
        memory.receive({lilas.id: lilas, roses.id: roses}, const {});
        final seen = <int>[];
        final subscription = memory.watchUnsent().listen(seen.add);
        await pumpEventQueue();

        memory.receive({lilas.id: lilas}, {lilas.id});
        memory.receive({roses.id: roses}, {lilas.id, roses.id});
        // Metadata only: the same count is not given again.
        memory.receive({roses.id: roses}, {lilas.id, roses.id});
        memory.receive({lilas.id: lilas, roses.id: roses}, const {});
        await pumpEventQueue();
        await subscription.cancel();

        expect(seen, [0, 1, 2, 0]);
      },
    );
  });

  group('watchOffline', () {
    test(
      'should tell whether the listener answers from the phone\'s copy, each '
      'time it changes',
      () async {
        memory.receive({lilas.id: lilas}, const {}, fromCache: true);
        final seen = <bool>[];
        final subscription = memory.watchOffline().listen(seen.add);
        await pumpEventQueue();

        // Metadata only: still from the phone's copy, not given again.
        memory.receive(const {}, const {}, fromCache: true);
        memory.receive(const {}, const {}, fromCache: false);
        memory.receive({roses.id: roses}, const {}, fromCache: false);
        memory.receive(const {}, const {}, fromCache: true);
        await pumpEventQueue();
        await subscription.cancel();

        expect(seen, [true, false, true]);
      },
    );

    test('should say online when the listener does not tell', () async {
      memory.receive({lilas.id: lilas}, const {});

      expect(await memory.watchOffline().first, isFalse);
    });

    test('should give nothing before the first answer', () async {
      final seen = <bool>[];
      final subscription = memory.watchOffline().listen(seen.add);
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, isEmpty);
    });
  });

  group('unreadable (#149)', () {
    test('should list a street the listener cannot read apart from the '
        'streets', () async {
      memory.receive(
        {lilas.id: lilas},
        const {},
        unreadable: {pasteur.id: pasteur},
      );

      expect(await memory.watchUnreadable().first, [pasteur]);
      expect(ids((await memory.streets()).values), ['lilas']);
    });

    test('should take a street out of the streets once it no longer '
        'reads', () async {
      memory.receive({lilas.id: lilas, roses.id: roses}, const {});

      memory.receive(
        const {},
        const {},
        unreadable: {lilas.id: lilasUnreadable},
      );

      expect(ids((await memory.streets()).values), ['roses']);
      expect(await memory.watchUnreadable().first, [lilasUnreadable]);
    });

    test('should forget an unreadable street once it reads again', () async {
      memory.receive(
        const {},
        const {},
        unreadable: {lilas.id: lilasUnreadable},
      );

      memory.receive({lilas.id: lilas}, const {});

      expect(await memory.watchUnreadable().first, isEmpty);
      expect(ids((await memory.streets()).values), ['lilas']);
    });

    test(
      'should forget an unreadable street the listener says is gone',
      () async {
        memory.receive(const {}, const {}, unreadable: {pasteur.id: pasteur});

        memory.receive({pasteur.id: null}, const {});

        expect(await memory.watchUnreadable().first, isEmpty);
      },
    );

    test(
      'should forget an unreadable street this phone deletes at once',
      () async {
        memory.receive(
          {lilas.id: lilas},
          const {},
          unreadable: {pasteur.id: pasteur},
        );

        memory.remove(pasteur.id);

        expect(await memory.watchUnreadable().first, isEmpty);
        expect(ids((await memory.streets()).values), ['lilas']);
      },
    );

    test(
      'should tell the observers of a street that it no longer reads',
      () async {
        memory.receive({lilas.id: lilas}, const {});
        final seen = <bool>[];
        final subscription = memory
            .observe(
              (streets) => streets.containsKey(lilas.id),
              (changed) => changed.contains(lilas.id),
            )
            .listen(seen.add);
        await pumpEventQueue();

        memory.receive(
          const {},
          const {},
          unreadable: {lilas.id: lilasUnreadable},
        );
        await pumpEventQueue();
        await subscription.cancel();

        expect(seen, [true, false]);
      },
    );

    test(
      'should give the unreadable streets again only when they change',
      () async {
        memory.receive({lilas.id: lilas}, const {});
        final seen = <List<UnreadableStreet>>[];
        final subscription = memory.watchUnreadable().listen(seen.add);
        await pumpEventQueue();

        memory.receive(const {}, const {}, unreadable: {pasteur.id: pasteur});
        // A mark on another street: the same unreadable streets.
        memory.put(
          valueOf(lilas.markHouse(n('1'), VisitStatus.done, by: lea, at: twoPm))
              .$1,
        );
        memory.remove(pasteur.id);
        await pumpEventQueue();
        await subscription.cancel();

        expect(seen, [
          <UnreadableStreet>[],
          [pasteur],
          <UnreadableStreet>[],
        ]);
      },
    );
  });
}
