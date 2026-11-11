import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/unreadable_streets.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/unreadable_street.dart';

import '../../support/fakes/fake_unreadable_streets.dart';
import '../../support/results.dart';

void main() {
  final pasteur = UnreadableStreet(
    id: StreetId('pasteur'),
    name: valueOf(StreetName.create('Rue Pasteur')),
  );
  final nameless = UnreadableStreet(id: StreetId('x7'));

  test('should give the unreadable streets, then again after each '
      'change', () async {
    final streets = FakeUnreadableStreets([pasteur]);
    final seen = <List<UnreadableStreet>>[];
    final subscription = ObserveUnreadableStreets(streets)().listen(seen.add);
    await pumpEventQueue();

    streets.add(nameless);
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, [
      [pasteur],
      [pasteur, nameless],
    ]);
  });

  test('should delete the street it is given', () async {
    final streets = FakeUnreadableStreets([pasteur, nameless]);

    await DeleteUnreadableStreet(streets)(StreetId('pasteur'));

    expect(streets.deleted, [StreetId('pasteur')]);
    expect(await streets.watchUnreadable().first, [nameless]);
  });
}
