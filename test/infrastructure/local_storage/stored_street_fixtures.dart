// A street holding every kind of data the phone storage must keep: a
// position and none, every status, « repasser » with and without hint (a
// building's own too),
// notes, last changes, buildings of every shape (two staircases, unknown
// floors, free labels, an emptied floor), a removed number and a deletion.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// Staircase A: 1er with doors 11 (done, Léa) and 12 (« repasser » with a
/// hint, a note), RdC emptied. Staircase B: RdC door 01 (« repasser »
/// without hint).
final twoStaircases = valueOf(
  Building.create(
    style: DoorLabelStyle.floorAndNumber,
    staircases: [
      Staircase(
        name: escB,
        floors: [
          Floor(
            level: 0,
            dwellings: [Dwelling(label: d('01'), status: VisitStatus.comeBack)],
          ),
        ],
      ),
      Staircase(
        name: escA,
        floors: [
          Floor(
            level: 1,
            dwellings: [
              Dwelling(
                label: d('11'),
                status: VisitStatus.done,
                lastChange: leaAtTwo,
              ),
              Dwelling(
                label: d('12'),
                status: VisitStatus.comeBack,
                comeBack: comeBack('le soir'),
                note: note('interphone cassé'),
                lastChange: paulAtThree,
              ),
            ],
          ),
          Floor(level: 0, dwellings: const []),
        ],
      ),
    ],
  ),
);

/// Floors unknown, free labels « Gauche » and « Droite ».
final unknownFloors = valueOf(
  Building.create(
    style: DoorLabelStyle.free,
    staircases: [
      Staircase(
        name: escA,
        floors: [
          Floor(
            level: null,
            dwellings: [
              Dwelling(label: d('Gauche'), status: VisitStatus.done),
              Dwelling(label: d('Droite')),
            ],
          ),
        ],
      ),
    ],
  ),
);

/// The letter style, one floor.
final lettered = valueOf(
  Building.create(
    style: DoorLabelStyle.floorAndLetter,
    staircases: [
      Staircase(
        name: escA,
        floors: [
          Floor(level: 2, dwellings: [Dwelling(label: d('2A'))]),
        ],
      ),
    ],
  ),
);

final everyKindOfHouse = [
  House(number: n('1'), position: townHallDoor),
  House(
    number: n('3bis'),
    status: VisitStatus.comeBack,
    comeBack: comeBack('après 19h'),
    note: note('chien\ndans le jardin 🐕'),
    lastChange: leaAtTwo,
    position: northDoor,
  ),
  House(number: n('3A'), status: VisitStatus.done, lastChange: paulAtThree),
  House(number: n('5'), status: VisitStatus.nobodyHome),
  House(
    number: n('8'),
    comeBack: comeBack('gardien'),
    note: note('digicode'),
    lastChange: leaAtTwo,
    building: twoStaircases,
    position: townHallDoor,
  ),
  House(number: n('10'), building: unknownFloors),
  House(number: n('12'), building: lettered),
];

final removedFourteen = RemovedHouse(
  house: House(
    number: n('14ter'),
    status: VisitStatus.done,
    note: note('fermé'),
    lastChange: leaAtTwo,
    building: unknownFloors,
  ),
  removal: paulAtThree,
);

/// The Rue des Lilas with every kind of house, in the Corbeille.
final richStreet = valueOf(
  Street.create(
    id: StreetId('aB3dE5gH7jK9mN1pQ2sT'),
    name: 'Rue des Lilas',
    commune: villefranche,
    banId: BanStreetId('69264_0420'),
    houses: everyKindOfHouse,
    removedHouses: [removedFourteen],
    deletion: leaAtTwo,
  ),
);

/// A street typed in by hand: no BAN id, no position, not deleted.
final manualStreet = valueOf(
  Street.create(
    id: StreetId('manual-1'),
    name: 'Chemin des Vignes',
    commune: villefranche,
    houses: [House(number: n('2'))],
  ),
);

/// Checks every field of [actual] against [expected] (a `Street` has no
/// `==`: two streets are compared field by field).
void expectSameStreet(Street actual, Street expected) {
  expect(actual.id, expected.id);
  expect(actual.name, expected.name);
  expect(actual.commune, expected.commune);
  expect(actual.banId, expected.banId);
  expect(actual.houses, expected.houses);
  expect(actual.removedHouses, expected.removedHouses);
  expect(actual.deletion, expected.deletion);
}
