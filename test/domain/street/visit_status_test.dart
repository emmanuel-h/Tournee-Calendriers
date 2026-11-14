import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

void main() {
  test('should list the five statuses', () {
    expect(VisitStatus.values, [
      VisitStatus.toDo,
      VisitStatus.done,
      VisitStatus.refused,
      VisitStatus.nobodyHome,
      VisitStatus.comeBack,
    ]);
  });

  test('should take ✓ and ⊘ as visited, nothing else', () {
    expect(VisitStatus.done.isVisited, isTrue);
    expect(VisitStatus.refused.isVisited, isTrue);
    expect(VisitStatus.toDo.isVisited, isFalse);
    expect(VisitStatus.nobodyHome.isVisited, isFalse);
    expect(VisitStatus.comeBack.isVisited, isFalse);
  });
}
