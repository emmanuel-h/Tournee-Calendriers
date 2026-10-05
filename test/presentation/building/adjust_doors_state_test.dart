import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_state.dart';

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
}
