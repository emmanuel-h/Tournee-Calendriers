import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

void main() {
  test('should list the four statuses', () {
    expect(VisitStatus.values, [
      VisitStatus.toDo,
      VisitStatus.done,
      VisitStatus.nobodyHome,
      VisitStatus.comeBack,
    ]);
  });
}
