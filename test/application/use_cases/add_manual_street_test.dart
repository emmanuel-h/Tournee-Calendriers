// « Rue à la main » (PLAN §5.5): a street missing from the map, typed in,
// stored at once without any network.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/add_manual_street.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  late FakeStreetRepository streets;
  late AddManualStreet add;

  setUp(() {
    streets = repositoryWithLilas();
    add = AddManualStreet(streets, FakeIdGenerator('street'), leaOnThePhone());
  });

  test('should store the street with a house to do per number', () async {
    final street = await add(
      name: streetName('Chemin des Vignes'),
      commune: villefranche,
      numbers: [n('3'), n('1'), n('2bis')],
      assignToMe: false,
    );

    expect(streets.added, [same(street)]);
    expect(street.id, StreetId('street-1'));
    expect(street.name, streetName('Chemin des Vignes'));
    expect(street.commune, villefranche);
    expect(street.banId, isNull);
    expect(street.shape, StreetShape.none);
    expect(street.houses, [
      House(number: n('1')),
      House(number: n('2bis')),
      House(number: n('3')),
    ]);
  });

  test('should give the street to the member when asked', () async {
    final street = await add(
      name: streetName('Chemin des Vignes'),
      commune: villefranche,
      numbers: [n('1')],
      assignToMe: true,
    );

    expect(street.assignees, {lea});
  });

  test('should leave the street free when not asked', () async {
    final street = await add(
      name: streetName('Chemin des Vignes'),
      commune: villefranche,
      numbers: [n('1')],
      assignToMe: false,
    );

    expect(street.assignees, isEmpty);
  });

  test('should give each new street its own id', () async {
    await add(
      name: streetName('Chemin des Vignes'),
      commune: villefranche,
      numbers: [n('1')],
      assignToMe: false,
    );

    final second = await add(
      name: streetName('Impasse des Roses'),
      commune: villefranche,
      numbers: const [],
      assignToMe: false,
    );

    expect(second.id, StreetId('street-2'));
    expect(second.houses, isEmpty);
    expect(streets.added, hasLength(2));
  });
}
