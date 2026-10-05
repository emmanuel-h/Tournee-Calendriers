import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/edit_street/add_numbers_notifier.dart';
import 'package:tournee_calendriers/presentation/edit_street/add_numbers_state.dart';

import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// 1 and 2 shown; 3, done, in the Corbeille.
final _removedThree = RemovedHouse(
  house: House(number: n('3'), status: VisitStatus.done),
  removal: paulAtThree,
);

Street _street({bool deleted = false}) => valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('1')),
      House(number: n('2')),
    ],
    removedHouses: [_removedThree],
    deletion: deleted ? paulAtThree : null,
  ),
);

List<HouseNumber> _numbers(List<String> labels) => [
  for (final label in labels) n(label),
];

void main() {
  late FakeStreetRepository streets;
  late ProviderContainer container;

  void phoneWith(Street? street) {
    streets = FakeStreetRepository([?street]);
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        clockProvider.overrideWithValue(FakeClock(twoPm)),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(addNumbersProvider(_id), (_, _) {});
  }

  AddNumbersNotifier sheet() =>
      container.read(addNumbersProvider(_id).notifier);

  Future<AddNumbersState> settled() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(addNumbersProvider(_id));
  }

  Future<NumbersPreview> previewOf(String text) async {
    sheet().type(text);
    return ((await settled()) as AddNumbersShown).preview;
  }

  group('view', () {
    test('should be loading before the street is read', () {
      phoneWith(_street());

      expect(container.read(addNumbersProvider(_id)), isA<AddNumbersLoading>());
    });

    test('should show the street with nothing typed yet', () async {
      phoneWith(_street());

      final state = (await settled()) as AddNumbersShown;

      expect(state.streetName, 'Rue des Lilas');
      expect(state.preview, isA<NothingTyped>());
    });

    test('should say the street is gone when it is not on the phone', () async {
      phoneWith(null);

      expect(await settled(), isA<AddNumbersGone>());
    });

    test('should say the street is gone when it is in the Corbeille', () async {
      phoneWith(_street(deleted: true));

      expect(await settled(), isA<AddNumbersGone>());
    });
  });

  group('preview', () {
    test('should list every number of the list and the range', () async {
      phoneWith(_street());
      await settled();

      final preview = (await previewOf('12bis, 21-25')) as NumbersPreviewed;

      expect(
        preview.numbers,
        _numbers(['12bis', '21', '22', '23', '24', '25']),
      );
      expect(preview.alreadyThere, isEmpty);
      expect(preview.fromCorbeille, isEmpty);
      expect(preview.newCount, 6);
      expect(preview.canAdd, isTrue);
    });

    test('should say which numbers the street already shows', () async {
      phoneWith(_street());
      await settled();

      final preview = (await previewOf('2, 4, 1')) as NumbersPreviewed;

      expect(preview.numbers, _numbers(['1', '2', '4']));
      expect(preview.alreadyThere, _numbers(['1', '2']));
      expect(preview.newCount, 1);
      expect(preview.canAdd, isTrue);
    });

    test('should say which numbers come back from the Corbeille', () async {
      phoneWith(_street());
      await settled();

      final preview = (await previewOf('3')) as NumbersPreviewed;

      expect(preview.fromCorbeille, _numbers(['3']));
      expect(preview.alreadyThere, isEmpty);
      expect(preview.newCount, 1);
      expect(preview.canAdd, isTrue);
    });

    test('should have nothing to add when every number is shown', () async {
      phoneWith(_street());
      await settled();

      final preview = (await previewOf('1-2')) as NumbersPreviewed;

      expect(preview.alreadyThere, _numbers(['1', '2']));
      expect(preview.newCount, 0);
      expect(preview.canAdd, isFalse);
    });

    test('should show nothing when only separators are typed', () async {
      phoneWith(_street());
      await settled();

      expect(await previewOf(' , ;'), isA<NothingTyped>());
    });

    test('should name the wrong item when one is not a number', () async {
      phoneWith(_street());
      await settled();

      final preview = (await previewOf('12, 1 2, 14')) as NumbersRefused;

      expect(
        preview.failure,
        const InvalidNumber('1 2', HouseNumberFailure.invalidSuffix),
      );
    });

    test('should name the wrong range', () async {
      phoneWith(_street());
      await settled();

      final preview = (await previewOf('21-')) as NumbersRefused;

      expect(preview.failure, const InvalidRange('21-'));
    });

    test('should follow the street when it changes', () async {
      phoneWith(_street());
      await settled();
      sheet().type('4');

      await container
          .read(editStreetNumbersProvider)
          .call(_id, AddNumbers([n('4')]));
      final state = (await settled()) as AddNumbersShown;

      expect((state.preview as NumbersPreviewed).alreadyThere, _numbers(['4']));
    });
  });

  group('Ajouter', () {
    test('should add the numbers and say so', () async {
      phoneWith(_street());
      await settled();
      sheet().type('3, 21-22, 1');

      expect(await sheet().add(), isTrue);
      final (_, change) = streets.saved.single;
      expect(
        change,
        NumbersAdded(
          streetId: _id,
          added: [
            House(number: n('21')),
            House(number: n('22')),
          ],
          restored: [_removedThree],
          alreadyThere: [n('1')],
        ),
      );
    });

    test('should add nothing when every number is shown', () async {
      phoneWith(_street());
      await settled();
      sheet().type('1, 2');

      expect(await sheet().add(), isFalse);
      expect(streets.saved, isEmpty);
    });

    test('should add nothing when nothing is typed', () async {
      phoneWith(_street());
      await settled();

      expect(await sheet().add(), isFalse);
      expect(streets.saved, isEmpty);
    });

    test('should add nothing when the street is not on the phone', () async {
      phoneWith(null);
      await settled();
      sheet().type('21');

      expect(await sheet().add(), isFalse);
      expect(streets.saved, isEmpty);
    });

    test('should add nothing when an item is wrong', () async {
      phoneWith(_street());
      await settled();
      sheet().type('21, x');

      expect(await sheet().add(), isFalse);
      expect(streets.saved, isEmpty);
    });
  });
}
