import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/picker_step.dart';

void main() {
  test('should ask when to come back after « Repasser »', () {
    expect(stepAfter(VisitStatus.comeBack), PickerStep.comeBackTime);
  });

  for (final status in [
    VisitStatus.toDo,
    VisitStatus.done,
    VisitStatus.refused,
    VisitStatus.nobodyHome,
  ]) {
    test('should close the picker after $status', () {
      expect(stepAfter(status), isNull);
    });
  }
}
