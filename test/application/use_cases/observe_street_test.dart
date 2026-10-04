import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/mark_house.dart';
import 'package:tournee_calendriers/application/use_cases/observe_street.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  test('should give the street now and after each change', () async {
    final streets = repositoryWithLilas();
    final observeStreet = ObserveStreet(streets);
    final markHouse = MarkHouse(streets, clockAtTwo(), leaOnThePhone());
    final seen = <Street?>[];
    final subscription = observeStreet(lilasId).listen(seen.add);

    await pumpEventQueue();
    await markHouse(lilasId, n('7'), VisitStatus.done);
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, hasLength(2));
    expect(seen.first, same(lilas));
    expect(houseOf(seen.last!, '7').status, VisitStatus.done);
  });

  test('should give null when the street is unknown', () async {
    final observeStreet = ObserveStreet(repositoryWithLilas());

    expect(await observeStreet(StreetId('rue-inconnue')).first, isNull);
  });
}
