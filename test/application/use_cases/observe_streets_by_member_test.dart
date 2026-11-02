import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/observe_streets_by_member.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/streets_by_member.dart';

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

List<String> _names(StreetsByMember byMember, MemberId member) => [
  for (final name in byMember.streetsOf(member)) name.text,
];

void main() {
  late FakeStreetRepository streets;
  late ObserveStreetsByMember observeStreetsByMember;

  setUp(() {
    streets = FakeStreetRepository([
      _street('lilas', 'Rue des Lilas', assignees: {lea}),
      _street('emile', 'Allée Émile Zola'),
      _street('fleurie', 'Allée Fleurie', assignees: {lea, paul}),
      _street('gare', 'Avenue de la Gare', assignees: {paul}),
    ]);
    observeStreetsByMember = ObserveStreetsByMember(streets);
  });

  test('should give each member\'s streets in French order', () async {
    final byMember = await observeStreetsByMember().first;

    expect(_names(byMember, lea), ['Allée Fleurie', 'Rue des Lilas']);
    expect(_names(byMember, paul), ['Allée Fleurie', 'Avenue de la Gare']);
  });

  test('should follow the streets as they change', () async {
    final seen = <List<String>>[];
    final subscription = observeStreetsByMember().listen(
      (byMember) => seen.add(_names(byMember, lea)),
    );
    await pumpEventQueue();

    final emile = valueOf(
      await streets.find(StreetId('emile')).then((s) => s!.take(lea)),
    );
    await streets.save(emile.$1, emile.$2);
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, [
      ['Allée Fleurie', 'Rue des Lilas'],
      ['Allée Émile Zola', 'Allée Fleurie', 'Rue des Lilas'],
    ]);
  });
}
