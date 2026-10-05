import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_state.dart';

import '../../support/street_fixtures.dart';

void main() {
  test('should compare a refused edit by its reason', () {
    const lastDoor = DoorEditRefused(BuildingChangeFailure.lastDwelling);

    expect(
      lastDoor.hashCode,
      const DoorEditRefused(BuildingChangeFailure.lastDwelling).hashCode,
    );
    expect(
      lastDoor,
      isNot(const DoorEditRefused(BuildingChangeFailure.noLabelLeft)),
    );
    expect(
      lastDoor.toString(),
      'DoorEditRefused(BuildingChangeFailure.lastDwelling)',
    );
  });

  test('should compare an invalid label by its reason', () {
    const blank = DoorLabelInvalid(DwellingLabelFailure.blank);

    expect(
      blank.hashCode,
      const DoorLabelInvalid(DwellingLabelFailure.blank).hashCode,
    );
    expect(blank, isNot(const DoorLabelInvalid(DwellingLabelFailure.tooLong)));
    expect(blank.toString(), 'DoorLabelInvalid(DwellingLabelFailure.blank)');
  });

  test('should compare a refused name by its reason', () {
    const taken = DoorRenameRefused(BuildingChangeFailure.duplicateLabel);

    expect(
      taken.hashCode,
      const DoorRenameRefused(BuildingChangeFailure.duplicateLabel).hashCode,
    );
    expect(
      taken,
      isNot(const DoorRenameRefused(BuildingChangeFailure.unknownDwelling)),
    );
    expect(
      taken.toString(),
      'DoorRenameRefused(BuildingChangeFailure.duplicateLabel)',
    );
  });

  test('should compare an applied edit by its door', () {
    final door13 = DoorEditApplied(DwellingKey(escA, 1, d('13')));

    expect(door13, DoorEditApplied(DwellingKey(escA, 1, d('13'))));
    expect(
      door13.hashCode,
      DoorEditApplied(DwellingKey(escA, 1, d('13'))).hashCode,
    );
    expect(door13, isNot(DoorEditApplied(DwellingKey(escA, 1, d('14')))));
    expect(door13.toString(), 'DoorEditApplied(A1-13)');
  });

  test('should compare a rename by the door it gives', () {
    final gauche = DoorRenamed(DwellingKey(escA, 0, d('Gauche')));

    expect(gauche, DoorRenamed(DwellingKey(escA, 0, d('Gauche'))));
    expect(
      gauche.hashCode,
      DoorRenamed(DwellingKey(escA, 0, d('Gauche'))).hashCode,
    );
    expect(gauche, isNot(DoorRenamed(DwellingKey(escA, 0, d('Droite')))));
    expect(gauche.toString(), 'DoorRenamed(A0-Gauche)');
  });
}
