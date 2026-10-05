// The street most use-case tests start from, and the fakes wired around it.
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final lilasId = StreetId('rue-des-lilas');

/// Number 5 « repasser » with a hint and a note (Paul's change),
/// number 7 to do, number 8 a building RdC 01 02 whose door 01 is done.
final five = House(
  number: n('5'),
  status: VisitStatus.comeBack,
  comeBack: comeBack('après 19h'),
  note: note('chien'),
  lastChange: paulAtThree,
  position: townHallDoor,
);
final seven = House(number: n('7'));
final doorOne = Dwelling(
  label: d('01'),
  status: VisitStatus.done,
  lastChange: paulAtThree,
);
final eight = House(
  number: n('8'),
  building: building(topFloor: 0, doors: 2).withDwelling(escA, 0, doorOne),
);
final lilas = valueOf(
  Street.create(
    id: lilasId,
    name: 'Rue des Lilas',
    commune: villefranche,
    banId: BanStreetId('69264_0420'),
    houses: [five, seven, eight],
  ),
);

/// The RdC door [label] of staircase A.
DwellingKey rdc(String label) => DwellingKey(escA, 0, d(label));

/// The house numbered [label] in [street].
House houseOf(Street street, String label) =>
    street.houses.singleWhere((house) => house.number == n(label));

/// A clock at two o'clock and Léa on the phone: every change they make is
/// stamped `leaAtTwo`.
FakeClock clockAtTwo() => FakeClock(twoPm);
FakeIdentity leaOnThePhone() => FakeIdentity(lea);

/// A repository holding the Rue des Lilas.
FakeStreetRepository repositoryWithLilas() => FakeStreetRepository([lilas]);
