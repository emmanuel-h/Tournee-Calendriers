import 'dart:async';

import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/observe_corbeille.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/corbeille.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

/// The Rue des Lilas with its number 7 removed by Léa at two o'clock.
Street lilasWithoutSeven() =>
    valueOf(lilas.removeNumber(n('7'), by: lea, at: twoPm)).$1;

/// Rue Gambetta, deleted by Paul at three o'clock.
Street gambettaDeleted() => valueOf(
  Street.create(
    id: StreetId('gambetta'),
    name: 'Rue Gambetta',
    commune: villefranche,
  ),
).delete(by: paul, at: threePm).$1;

/// A repository whose two streams are driven by the test, which closes
/// them ([close]).
final class ScriptedStreets implements StreetRepository {
  final all = StreamController<List<Street>>();
  final deleted = StreamController<List<Street>>();

  Future<void> close() async {
    await all.close();
    await deleted.close();
  }

  @override
  Stream<List<Street>> watchAll() => all.stream;

  @override
  Stream<List<Street>> watchDeleted() => deleted.stream;

  @override
  Future<Street?> find(StreetId id) => throw UnimplementedError();

  @override
  Future<Street?> findByBanId(BanStreetId banId) => throw UnimplementedError();

  @override
  Stream<Street?> watch(StreetId id) => throw UnimplementedError();

  @override
  Future<void> add(Street street) => throw UnimplementedError();

  @override
  Future<void> save(Street street, StreetChange change) =>
      throw UnimplementedError();
}

void main() {
  test('should give the deleted streets and the removed numbers, the latest '
      'first', () async {
    final streets = FakeStreetRepository([
      lilasWithoutSeven(),
      gambettaDeleted(),
    ]);

    final items = await ObserveCorbeille(streets)().first;

    expect(items, [
      DeletedStreet(
        streetId: StreetId('gambetta'),
        streetName: streetName('Rue Gambetta'),
        removal: ChangeStamp(by: paul, at: threePm),
        numberCount: 0,
      ),
      RemovedNumber(
        streetId: lilasId,
        streetName: streetName('Rue des Lilas'),
        removal: leaAtTwo,
        number: n('7'),
      ),
    ]);
  });

  test('should give the Corbeille again after each change', () async {
    final streets = FakeStreetRepository([lilas]);
    final seen = <List<CorbeilleItem>>[];
    final listening = ObserveCorbeille(streets)().listen(seen.add);
    addTearDown(listening.cancel);
    await pumpEventQueue();

    final (removed, change) = valueOf(
      lilas.removeNumber(n('7'), by: lea, at: twoPm),
    );
    await streets.save(removed, change);
    await pumpEventQueue();

    expect(seen.first, isEmpty);
    expect(seen.last.single, isA<RemovedNumber>());
  });

  test('should wait for both kinds of streets before giving any', () async {
    final streets = ScriptedStreets();
    addTearDown(streets.close);
    final seen = <List<CorbeilleItem>>[];
    final listening = ObserveCorbeille(streets)().listen(seen.add);
    addTearDown(listening.cancel);

    streets.deleted.add([gambettaDeleted()]);
    await pumpEventQueue();
    expect(seen, isEmpty);

    streets.all.add([lilasWithoutSeven()]);
    await pumpEventQueue();
    expect(seen.single, hasLength(2));
  });

  test('should pass on a failure of either stream', () async {
    final streets = ScriptedStreets();
    addTearDown(streets.close);
    final errors = <Object>[];
    final listening = ObserveCorbeille(
      streets,
    )().listen((_) {}, onError: errors.add);
    addTearDown(listening.cancel);

    streets.all.addError(StateError('all'));
    streets.deleted.addError(StateError('deleted'));
    await pumpEventQueue();

    expect(errors.map((error) => (error as StateError).message), [
      'all',
      'deleted',
    ]);
  });

  test('should stop listening to the streets when nobody listens any '
      'more', () async {
    final streets = ScriptedStreets();
    addTearDown(streets.close);
    final listening = ObserveCorbeille(streets)().listen((_) {});
    await pumpEventQueue();
    expect(streets.all.hasListener, isTrue);
    expect(streets.deleted.hasListener, isTrue);

    await listening.cancel();

    expect(streets.all.hasListener, isFalse);
    expect(streets.deleted.hasListener, isFalse);
  });
}
