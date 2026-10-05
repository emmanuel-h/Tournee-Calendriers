import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/edit_street/edit_street_notifier.dart';
import 'package:tournee_calendriers/presentation/edit_street/edit_street_state.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// The Edit mockup in short: 1 and 3bis to do, 3 done, 5 with a note; 2
/// to do, 8 a building nobody marked, 10 a building with one door done.
final _three = House(number: n('3'), status: VisitStatus.done);
final _eight = House(number: n('8'), building: building(topFloor: 0, doors: 2));
final _ten = House(
  number: n('10'),
  building: building(
    topFloor: 0,
    doors: 2,
  ).withDwelling(escA, 0, Dwelling(label: d('01'), status: VisitStatus.done)),
);
final _houses = [
  House(number: n('1')),
  _three,
  House(number: n('3bis')),
  House(number: n('5'), note: note('chien')),
  House(number: n('2')),
  _eight,
  _ten,
];

Street _street({
  List<House>? houses,
  List<RemovedHouse> removed = const [],
  ChangeStamp? deletion,
}) => valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: houses ?? _houses,
    removedHouses: removed,
    deletion: deletion,
  ),
);

EditTile _tile(String number, {bool isBuilding = false}) =>
    EditTile(number: n(number), isBuilding: isBuilding);

void main() {
  late FakeStreetRepository streets;
  late ProviderContainer container;

  /// A container whose phone holds [street] (none when null).
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
    // Keeps the auto-disposed provider alive, as the screen does.
    container.listen(editStreetProvider(_id), (_, _) {});
  }

  EditStreetNotifier edit() => container.read(editStreetProvider(_id).notifier);

  Future<EditStreetState> settled() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(editStreetProvider(_id));
  }

  Future<EditStreetShown> shown() async => (await settled()) as EditStreetShown;

  /// The street as stored now.
  Street stored() => streets[_id]!;

  List<String> storedNumbers() => [
    for (final house in stored().houses) house.number.label,
  ];

  group('view', () {
    test('should be loading before the street is read', () {
      phoneWith(_street());

      expect(container.read(editStreetProvider(_id)), isA<EditStreetLoading>());
    });

    test('should show the name and both sides in order when the street is '
        'read', () async {
      phoneWith(_street());

      final state = await shown();

      expect(state.name, 'Rue des Lilas');
      expect(state.columns, StreetColumns.both);
      expect(state.odd, [_tile('1'), _tile('3'), _tile('3bis'), _tile('5')]);
      expect(state.even, [
        _tile('2'),
        _tile('8', isBuilding: true),
        _tile('10', isBuilding: true),
      ]);
    });

    test(
      'should show one column when the street has odd numbers only',
      () async {
        phoneWith(_street(houses: [House(number: n('1'))]));

        expect((await shown()).columns, StreetColumns.oddOnly);
      },
    );

    test(
      'should show one column when the street has even numbers only',
      () async {
        phoneWith(_street(houses: [House(number: n('2'))]));

        expect((await shown()).columns, StreetColumns.evenOnly);
      },
    );

    test('should say the street is gone when it is not on the phone', () async {
      phoneWith(null);

      expect(await settled(), isA<EditStreetGone>());
    });

    test('should say the street is gone when it is in the Corbeille', () async {
      phoneWith(_street(deletion: paulAtThree));

      expect(await settled(), isA<EditStreetGone>());
    });
  });

  group('✕', () {
    test('should remove a number at once when it has no mark', () async {
      phoneWith(_street());
      await settled();

      final outcome = await edit().remove(n('3bis'));

      expect(outcome, const EditApplied());
      final (_, change) = streets.saved.single;
      expect(
        change,
        NumberRemoved(
          streetId: _id,
          removed: RemovedHouse(
            house: House(number: n('3bis')),
            removal: leaAtTwo,
          ),
        ),
      );
      expect((await shown()).odd, [_tile('1'), _tile('3'), _tile('5')]);
    });

    test('should ask first when the number has a mark', () async {
      phoneWith(_street());
      await settled();

      final outcome = await edit().remove(n('3'));

      expect(outcome, const EditNeedsConfirmation());
      expect(streets.saved, isEmpty);
    });

    test('should ask first when a door of the building has a mark', () async {
      phoneWith(_street());
      await settled();

      expect(await edit().remove(n('10')), const EditNeedsConfirmation());
      expect(streets.saved, isEmpty);
    });

    test(
      'should remove a marked number with its marks when confirmed',
      () async {
        phoneWith(_street());
        await settled();

        final outcome = await edit().remove(n('3'), confirmed: true);

        expect(outcome, const EditApplied());
        expect(stored().removedHouses, [
          RemovedHouse(house: _three, removal: leaAtTwo),
        ]);
      },
    );

    test('should fail when the number is no longer shown', () async {
      phoneWith(_street());
      await settled();

      expect(await edit().remove(n('7')), const EditFailed());
      expect(streets.saved, isEmpty);
    });
  });

  group('Annuler', () {
    test('should bring the removed number back once', () async {
      phoneWith(_street());
      await settled();
      await edit().remove(n('3'), confirmed: true);

      await edit().undo();
      await edit().undo();

      expect(storedNumbers(), ['1', '2', '3', '3bis', '5', '8', '10']);
      expect(stored().removedHouses, isEmpty);
      // The removal, then its undo; the second « Annuler » did nothing.
      expect(streets.saved, hasLength(2));
    });

    test('should do nothing when nothing was changed yet', () async {
      phoneWith(_street());
      await settled();

      await edit().undo();

      expect(streets.saved, isEmpty);
    });
  });

  group('name', () {
    test('should rename the street when the name is valid and new', () async {
      phoneWith(_street());
      await settled();

      final refusal = await edit().renameStreet('  Rue  des Glycines ');

      expect(refusal, isNull);
      final (_, change) = streets.saved.single;
      expect(
        change,
        StreetRenamed(
          streetId: _id,
          before: 'Rue des Lilas',
          name: 'Rue des Glycines',
        ),
      );
      expect((await shown()).name, 'Rue des Glycines');
    });

    test('should store nothing when the cleaned name is the same', () async {
      phoneWith(_street());
      await settled();

      expect(await edit().renameStreet(' Rue   des Lilas '), isNull);
      expect(streets.saved, isEmpty);
    });

    test('should refuse a blank name', () async {
      phoneWith(_street());
      await settled();

      expect(await edit().renameStreet('   '), StreetNameFailure.blank);
      expect(streets.saved, isEmpty);
    });

    test('should refuse a name longer than the limit', () async {
      phoneWith(_street());
      await settled();

      final atLimit = 'R' * StreetName.maxLength;
      expect(
        await edit().renameStreet('${atLimit}e'),
        StreetNameFailure.tooLong,
      );
      expect(streets.saved, isEmpty);
      expect(await edit().renameStreet(atLimit), isNull);
      expect(stored().name, atLimit);
    });

    test('should store nothing when the street is in the Corbeille', () async {
      phoneWith(_street(deletion: paulAtThree));
      await settled();

      expect(await edit().renameStreet('Rue des Glycines'), isNull);
      expect(streets.saved, isEmpty);
    });

    test('should store nothing when the street is not on the phone', () async {
      phoneWith(null);
      await settled();

      expect(await edit().renameStreet('Rue des Glycines'), isNull);
      expect(streets.saved, isEmpty);
    });
  });

  group('Changer le numéro', () {
    test('should give the house the new number with its marks', () async {
      phoneWith(_street());
      await settled();

      final outcome = await edit().renumber(n('3'), ' 3 TER ');

      expect(outcome, Renumbered(n('3ter')));
      final (_, change) = streets.saved.single;
      expect(
        change,
        NumberRenamed(
          streetId: _id,
          before: _three,
          stamp: leaAtTwo,
          newNumber: n('3ter'),
        ),
      );
      expect(storedNumbers(), ['1', '2', '3bis', '3ter', '5', '8', '10']);
    });

    test('should put the old number back when Annuler is tapped', () async {
      phoneWith(_street());
      await settled();
      await edit().renumber(n('3'), '3ter');

      await edit().undo();

      expect(storedNumbers(), ['1', '2', '3', '3bis', '5', '8', '10']);
    });

    test('should say why when the text is not a number', () async {
      phoneWith(_street());
      await settled();

      expect(
        await edit().renumber(n('3'), 'bis'),
        const RenumberInvalid(HouseNumberFailure.malformed),
      );
      expect(streets.saved, isEmpty);
    });

    test('should do nothing when the number is the same', () async {
      phoneWith(_street());
      await settled();

      expect(await edit().renumber(n('3'), '03'), const RenumberUnchanged());
      expect(streets.saved, isEmpty);
    });

    test('should refuse a number another house shows', () async {
      phoneWith(_street());
      await settled();

      expect(await edit().renumber(n('3'), '5'), RenumberTaken(n('5')));
      expect(streets.saved, isEmpty);
    });

    test('should refuse a number in the Corbeille', () async {
      phoneWith(
        _street(
          removed: [
            RemovedHouse(
              house: House(number: n('7')),
              removal: paulAtThree,
            ),
          ],
        ),
      );
      await settled();

      expect(await edit().renumber(n('3'), '7'), RenumberInCorbeille(n('7')));
      expect(streets.saved, isEmpty);
    });

    test('should fail when the house is no longer shown', () async {
      phoneWith(_street());
      await settled();

      expect(await edit().renumber(n('9'), '9bis'), const RenumberFailed());
      expect(streets.saved, isEmpty);
    });
  });

  group('Redevenir une maison', () {
    test('should make an unmarked building a single house at once', () async {
      phoneWith(_street());
      await settled();

      final outcome = await edit().backToSingleHouse(n('8'));

      expect(outcome, const EditApplied());
      expect(
        stored().houses.singleWhere((h) => h.number == n('8')).building,
        isNull,
      );
      expect((await shown()).even[1], _tile('8'));
    });

    test('should ask first when a door has a mark', () async {
      phoneWith(_street());
      await settled();

      expect(
        await edit().backToSingleHouse(n('10')),
        const EditNeedsConfirmation(),
      );
      expect(streets.saved, isEmpty);
    });

    test('should drop the marked doors when confirmed, with Annuler to put '
        'them back', () async {
      phoneWith(_street());
      await settled();

      final outcome = await edit().backToSingleHouse(n('10'), confirmed: true);

      expect(outcome, const EditApplied());
      expect(stored().houses.last.building, isNull);
      await edit().undo();
      expect(stored().houses.last, _ten);
    });

    test('should fail when the house is not a building', () async {
      phoneWith(_street());
      await settled();

      expect(await edit().backToSingleHouse(n('1')), const EditFailed());
      expect(streets.saved, isEmpty);
    });
  });

  group('Supprimer la rue', () {
    test('should send the street to the Corbeille', () async {
      phoneWith(_street());
      await settled();

      expect(await edit().deleteStreet(), isTrue);
      final (_, change) = streets.saved.single;
      expect(change, StreetDeleted(streetId: _id, deletion: leaAtTwo));
      expect(await settled(), isA<EditStreetGone>());
    });

    test('should fail when the street is not on the phone', () async {
      phoneWith(null);
      await settled();

      expect(await edit().deleteStreet(), isFalse);
      expect(streets.saved, isEmpty);
    });
  });
}
