import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/observe_my_streets.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

Street _street(String id, String name, {Set<MemberId> assignees = const {}}) =>
    valueOf(
      Street.create(
        id: StreetId(id),
        name: name,
        commune: villefranche,
        assignees: assignees,
      ),
    );

List<String> _ids(List<Street> streets) => [
  for (final street in streets) street.id.value,
];

void main() {
  late FakeStreetRepository streets;
  late ObserveMyStreets observeMyStreets;

  setUp(() {
    streets = FakeStreetRepository([
      _street('lilas', 'Rue des Lilas', assignees: {lea}),
      _street('emile', 'Allée Émile Zola'),
      _street('fleurie', 'Allée Fleurie', assignees: {lea, paul}),
      _street('gare', 'Avenue de la Gare', assignees: {paul}),
    ]);
    observeMyStreets = ObserveMyStreets(streets, FakeIdentity(lea));
  });

  test('should give the member\'s streets in French order', () async {
    final mine = await observeMyStreets().first;

    expect(_ids(mine.mine), ['fleurie', 'lilas']);
  });

  test('should give the other streets in French order', () async {
    final mine = await observeMyStreets().first;

    // « Émile » sorts with E, before « Fleurie »'s neighbour « Gare ».
    expect(_ids(mine.others), ['emile', 'gare']);
    expect(_ids(mine.all), ['emile', 'fleurie', 'gare', 'lilas']);
  });

  test('should follow the streets as they change', () async {
    final seen = <List<String>>[];
    final subscription = observeMyStreets().listen(
      (mine) => seen.add(_ids(mine.mine)),
    );
    await pumpEventQueue();

    final emile = valueOf(
      await streets.find(StreetId('emile')).then((s) => s!.take(lea)),
    );
    await streets.save(emile.$1, emile.$2);
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, [
      ['fleurie', 'lilas'],
      ['emile', 'fleurie', 'lilas'],
    ]);
  });
}
