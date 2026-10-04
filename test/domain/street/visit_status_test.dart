import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

void main() {
  test('should list the three statuses in tap-cycle order', () {
    expect(VisitStatus.values, [
      VisitStatus.toDo,
      VisitStatus.done,
      VisitStatus.nobodyHome,
    ]);
  });

  test('should become done when a house to do is tapped', () {
    expect(VisitStatus.toDo.next, VisitStatus.done);
  });

  test('should become nobody home when a done house is tapped', () {
    expect(VisitStatus.done.next, VisitStatus.nobodyHome);
  });

  test('should go back to do when a nobody-home house is tapped', () {
    expect(VisitStatus.nobodyHome.next, VisitStatus.toDo);
  });

  test('should come back to the start when tapped three times', () {
    for (final status in VisitStatus.values) {
      expect(status.next.next.next, status, reason: '$status');
    }
  });
}
