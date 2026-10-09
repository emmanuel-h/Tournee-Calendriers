// The streets the Firestore adapter holds in memory: what the listener
// gives, and this phone's own changes at once (memory first).
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
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
}
