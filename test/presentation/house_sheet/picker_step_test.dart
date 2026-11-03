import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/picker_step.dart';

void main() {
  for (final (roundOn, stored) in [
    (false, false),
    (false, true),
    (true, false),
    (true, true),
  ]) {
    test('should ask when to come back after « Repasser » when roundOn is '
        '$roundOn and stored is $stored', () {
      expect(
        stepAfter(VisitStatus.comeBack, roundOn: roundOn, stored: stored),
        PickerStep.comeBackTime,
      );
    });
  }

  test('should ask for the don when « Fait » is stored during a tournée', () {
    expect(
      stepAfter(VisitStatus.done, roundOn: true, stored: true),
      PickerStep.donation,
    );
  });

  test('should close the picker when « Fait » is stored and no tournée is '
      'on', () {
    expect(stepAfter(VisitStatus.done, roundOn: false, stored: true), isNull);
  });

  test('should close the picker when « Fait » is tapped on a house already '
      'done during a tournée', () {
    expect(stepAfter(VisitStatus.done, roundOn: true, stored: false), isNull);
  });

  for (final status in [
    VisitStatus.toDo,
    VisitStatus.refused,
    VisitStatus.nobodyHome,
  ]) {
    test('should close the picker after $status, even during a tournée', () {
      expect(stepAfter(status, roundOn: true, stored: true), isNull);
      expect(stepAfter(status, roundOn: false, stored: true), isNull);
    });
  }
}
