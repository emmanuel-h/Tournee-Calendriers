import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/manual_street/manual_street_notifier.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' hide lea;
import '../../support/street_fixtures.dart' as street_fixtures show lea;

final _me = street_fixtures.lea;

final _gleize = gleizeCommune.commune;

/// Rue du Bourg, in Gleizé.
final _bourg = valueOf(
  Street.create(id: StreetId('bourg'), name: 'Rue du Bourg', commune: _gleize),
);

void main() {
  late FakeStreetRepository streets;
  late FakeTourneeRepository tournees;

  ProviderContainer phone({bool open = true}) {
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        tourneeRepositoryProvider.overrideWithValue(tournees),
        identityProvider.overrideWithValue(FakeIdentity(_me)),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
        myTourneesStoreProvider.overrideWithValue(
          FakeMyTourneesStore(
            open
                ? valueOf(MyTournees.none.remember(tournee49).open(tourneeId))
                : MyTournees.none,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(manualStreetProvider, (_, _) {});
    return container;
  }

  ManualStreetState stateOf(ProviderContainer container) =>
      container.read(manualStreetProvider);

  ManualStreetNotifier notifierOf(ProviderContainer container) =>
      container.read(manualStreetProvider.notifier);

  /// The form filled with a name and the numbers 1 to 3.
  ManualStreetNotifier filled(ProviderContainer container) =>
      notifierOf(container)
        ..setName('Chemin des Vignes')
        ..setFrom('1')
        ..setTo('3');

  setUp(() {
    streets = FakeStreetRepository([_bourg]);
    tournees = FakeTourneeRepository([
      team(communes: [villefrancheCommune, gleizeCommune]),
    ]);
  });

  group('communes', () {
    test('should offer the tournée\'s communes, the first chosen', () async {
      final container = phone();
      await pumpEventQueue();

      final state = stateOf(container);

      expect(state.communes, [villefranche, _gleize]);
      expect(state.commune, villefranche);
    });

    test('should keep the commune chosen', () async {
      final container = phone();
      await pumpEventQueue();

      notifierOf(container).chooseCommune(_gleize.inseeCode);

      expect(stateOf(container).commune, _gleize);
    });

    test('should offer the communes of the streets for a tournée without '
        'commune', () async {
      tournees.put(team());
      streets = FakeStreetRepository([
        _bourg,
        valueOf(
          Street.create(
            id: StreetId('eglise'),
            name: 'Place de l\'Église',
            commune: _gleize,
          ),
        ),
      ]);
      final container = phone();
      await pumpEventQueue();

      expect(stateOf(container).communes, [_gleize]);
    });

    test('should know no commune without communes nor streets, until one '
        'is found', () async {
      tournees.put(team());
      streets = FakeStreetRepository();
      final container = phone();
      await pumpEventQueue();
      expect(stateOf(container).communes, isEmpty);
      expect(stateOf(container).commune, isNull);

      notifierOf(container).pickCommune(villefranche);

      expect(stateOf(container).commune, villefranche);
    });

    test('should know no commune while the streets cannot be read, with no '
        'tournée open', () async {
      streets.watchError = StateError('removed');
      final container = phone(open: false);
      await pumpEventQueue();

      expect(stateOf(container).communes, isEmpty);
      expect(tournees.watched, isEmpty);
    });
  });

  test('should offer the communes of the streets when the tournée can no '
      'longer be read', () async {
    tournees.watchError = StateError('removed');
    final container = phone();
    await pumpEventQueue();

    expect(stateOf(container).communes, [_gleize]);
  });

  group('preview', () {
    test('should show nothing typed at first', () async {
      final container = phone();
      await pumpEventQueue();

      final state = stateOf(container);

      expect(state.preview, isA<NothingTyped>());
      expect(state.sides, Sides.both);
      expect(state.nameProblem, isNull);
      expect(state.adding, isFalse);
      expect(state.canAdd, isFalse);
    });

    test('should list the numbers of the range, on the sides chosen, with '
        'the extras', () async {
      final container = phone();
      await pumpEventQueue();

      notifierOf(container)
        ..setFrom('1')
        ..setTo('5')
        ..setSides(Sides.odd)
        ..setExtras('2bis');

      final state = stateOf(container);
      expect(state.sides, Sides.odd);
      expect((state.preview as NumbersPreviewed).numbers, [
        n('1'),
        n('2bis'),
        n('3'),
        n('5'),
      ]);
    });

    test('should name the field that is wrong', () async {
      final container = phone();
      await pumpEventQueue();

      notifierOf(container).setTo('5a');

      expect(
        (stateOf(container).preview as NumbersRefused).failure,
        const InvalidBound(Bound.to, '5a'),
      );
    });

    test('should say a name is too long', () async {
      final container = phone();
      await pumpEventQueue();

      notifierOf(container).setName('a' * (StreetName.maxLength + 1));

      expect(stateOf(container).nameProblem, StreetNameFailure.tooLong);
    });

    test('should allow adding with a name, a commune and a number', () async {
      final container = phone();
      await pumpEventQueue();

      filled(container);

      expect(stateOf(container).canAdd, isTrue);
    });

    test('should not allow adding with a blank name, without saying '
        'so', () async {
      final container = phone();
      await pumpEventQueue();

      filled(container).setName('  ');

      expect(stateOf(container).canAdd, isFalse);
      expect(stateOf(container).nameProblem, isNull);
    });

    test('should not allow adding without a number', () async {
      final container = phone();
      await pumpEventQueue();

      filled(container)
        ..setFrom('')
        ..setTo('');

      expect(stateOf(container).canAdd, isFalse);
    });

    test('should not allow adding without a commune', () async {
      tournees.put(team());
      streets = FakeStreetRepository();
      final container = phone();
      await pumpEventQueue();

      filled(container);

      expect(stateOf(container).canAdd, isFalse);
    });
  });

  group('add', () {
    test('should add the street for the member and name it', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = filled(container)
        ..chooseCommune(_gleize.inseeCode)
        ..setExtras('2bis');

      final name = await notifier.add();

      expect(name, 'Chemin des Vignes');
      final street = streets.added.single;
      expect(street.name, streetName('Chemin des Vignes'));
      expect(street.commune, _gleize);
      expect(street.assignees, {_me});
      expect(street.banId, isNull);
      expect(
        [for (final house in street.houses) house.number],
        [n('1'), n('2'), n('2bis'), n('3')],
      );
      expect(stateOf(container).adding, isFalse);
    });

    test('should show the street being added', () async {
      streets.holdAdds = Completer();
      final container = phone();
      await pumpEventQueue();
      final notifier = filled(container);

      final adding = notifier.add();

      expect(stateOf(container).adding, isTrue);
      expect(stateOf(container).canAdd, isFalse);
      streets.holdAdds!.complete();
      await adding;
    });

    test('should add nothing while the form cannot', () async {
      final container = phone();
      await pumpEventQueue();

      final name = await notifierOf(container).add();

      expect(name, isNull);
      expect(streets.added, isEmpty);
    });

    test('should still add the street when the screen closes', () async {
      streets.holdAdds = Completer();
      final container = phone();
      await pumpEventQueue();
      final adding = filled(container).add();

      container.dispose();
      streets.holdAdds!.complete();

      expect(await adding, 'Chemin des Vignes');
      expect(streets.added, hasLength(1));
    });
  });
}
