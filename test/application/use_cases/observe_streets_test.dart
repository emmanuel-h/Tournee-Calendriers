import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/observe_streets.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

Street _street(String id, String name) =>
    valueOf(Street.create(id: StreetId(id), name: name, commune: villefranche));

List<String> _ids(List<Street> streets) => [
  for (final street in streets) street.id.value,
];

void main() {
  test('should list the streets by name whatever the case', () async {
    final observeStreets = ObserveStreets(
      FakeStreetRepository([
        _street('lilas', 'Rue des Lilas'),
        _street('roses', 'allée des Roses'),
        _street('avenue', 'Avenue de la Gare'),
      ]),
    );

    final streets = await observeStreets().first;

    expect(_ids(streets), ['roses', 'avenue', 'lilas']);
  });

  test('should sort an accented name with its plain letter', () async {
    final observeStreets = ObserveStreets(
      FakeStreetRepository([
        _street('fleurie', 'Allée Fleurie'),
        _street('emile', 'Allée Émile Zola'),
        _street('dame', 'Allée Dame'),
      ]),
    );

    // Compared character by character, « É » would come after « F ».
    expect(_ids(await observeStreets().first), ['dame', 'emile', 'fleurie']);
  });

  test('should order two streets of the same name by id', () async {
    final observeStreets = ObserveStreets(
      FakeStreetRepository([
        _street('b', 'Grande Rue'),
        _street('a', 'Grande rue'),
      ]),
    );

    expect(_ids(await observeStreets().first), ['a', 'b']);
  });

  test('should leave out the streets in the Corbeille', () async {
    final (deleted, _) = _street(
      'roses',
      'Allée des Roses',
    ).delete(by: lea, at: twoPm);
    final observeStreets = ObserveStreets(
      FakeStreetRepository([_street('lilas', 'Rue des Lilas'), deleted]),
    );

    expect(_ids(await observeStreets().first), ['lilas']);
  });

  test('should give the list again after a street is added', () async {
    final streets = FakeStreetRepository();
    final observeStreets = ObserveStreets(streets);
    final seen = <List<Street>>[];
    final subscription = observeStreets().listen(seen.add);

    await pumpEventQueue();
    await streets.add(_street('lilas', 'Rue des Lilas'));
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen.map(_ids), [
      <String>[],
      ['lilas'],
    ]);
  });

  test('should give a list nobody can change', () async {
    final observeStreets = ObserveStreets(
      FakeStreetRepository([_street('lilas', 'Rue des Lilas')]),
    );

    final streets = await observeStreets().first;

    expect(streets.clear, throwsUnsupportedError);
  });
}
