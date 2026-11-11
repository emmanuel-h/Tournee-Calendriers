// The streets of a zone drawn on « Ajouter des rues » (PLAN §5.14): the
// named roads of the map's tiles in it, each matched to its BAN street by
// name in the secteur's communes.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/use_cases/find_zone_streets.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

/// A zone of Villefranche-sur-Saône, 45.98–45.99 N, 4.71–4.73 E.
final _zone = GeoBounds.of(south: 45.98, west: 4.71, north: 45.99, east: 4.73)!;

final _morinId = BanStreetId('69264_1460');
final _pasteurId = BanStreetId('69264_1200');
final _gleizeMorinId = BanStreetId('69092_0100');

/// A road across the zone at [latitude], from 4.712 to 4.716 E: its mark
/// is at 4.714 E.
StreetShape _roadAt(double latitude) => StreetShape([
  [at(latitude, 4.712), at(latitude, 4.716)],
]);

NamedRoad _road(String name, double latitude) =>
    NamedRoad(name: name, shape: _roadAt(latitude));

final _gleize = valueOf(Commune.create(inseeCode: '69092', name: 'Gleizé'));

CommuneStreets _listing(Commune commune, Map<BanStreetId, String> streets) =>
    CommuneStreets(
      commune: commune,
      streets: [
        for (final MapEntry(key: id, value: name) in streets.entries)
          DirectoryStreet(id: id, name: streetName(name), numberCount: 19),
      ],
      skippedStreets: 0,
    );

void main() {
  late FakeStreetShapes shapes;
  late FakeAddressDirectory directory;
  late FakeStreetRepository streets;

  FindZoneStreets find() => FindZoneStreets(shapes, directory, streets);

  setUp(() {
    shapes = FakeStreetShapes();
    streets = repositoryWithLilas();
    directory = FakeAddressDirectory(
      communes: {
        '69264': Ok(
          _listing(villefranche, {
            _morinId: 'Rue Pierre Morin',
            _pasteurId: 'Rue Pasteur',
            lilas.banId!: 'Rue des Lilas',
          }),
        ),
        '69092': Ok(_listing(_gleize, {_gleizeMorinId: 'Rue Pierre Morin'})),
      },
    );
  });

  Future<List<ZoneStreet>> found({List<String> communes = const ['69264']}) =>
      find()(
        _zone,
        communes: [for (final code in communes) insee(code)],
      ).then(valueOf);

  test('should offer a road named like a BAN street the secteur does not '
      'have, with its numbers and its mark in the zone', () async {
    shapes.roads = Ok([_road('Rue Pierre Morin', 45.985)]);

    final street = (await found()).single;

    expect(
      street,
      ZoneStreetToAdd(
        match: StreetMatch(
          id: _morinId,
          name: streetName('Rue Pierre Morin'),
          commune: villefranche,
          position: at(45.985, 4.714),
        ),
        numberCount: 19,
        road: _roadAt(45.985),
        mark: at(45.985, 4.714),
      ),
    );
    expect(street.name, 'Rue Pierre Morin');
    expect(shapes.zonesAsked, [_zone]);
    expect(directory.communesAsked, ['69264']);
  });

  test('should match a name written without its accents', () async {
    shapes.roads = Ok([_road('Rue Pierre Morin', 45.985)]);
    directory = FakeAddressDirectory(
      communes: {
        '69264': Ok(_listing(villefranche, {_morinId: 'RUE PIERRE MÖRIN'})),
      },
    );

    final street = (await found()).single as ZoneStreetToAdd;

    expect(street.match.id, _morinId);
  });

  test('should grey a street the secteur has already', () async {
    shapes.roads = Ok([_road('Rue des Lilas', 45.985)]);

    final street = (await found()).single;

    expect(
      street,
      ZoneStreetInSector(
        match: StreetMatch(
          id: lilas.banId!,
          name: streetName('Rue des Lilas'),
          commune: villefranche,
          position: at(45.985, 4.714),
        ),
        road: _roadAt(45.985),
        mark: at(45.985, 4.714),
      ),
    );
    expect(street.name, 'Rue des Lilas');
  });

  test('should offer again a street of the Corbeille', () async {
    final (deleted, change) = lilas.delete(by: lea, at: twoPm);
    await streets.save(deleted, change);
    shapes.roads = Ok([_road('Rue des Lilas', 45.985)]);

    final street = (await found()).single;
    expect(street, isA<ZoneStreetToAdd>());
    expect((street as ZoneStreetToAdd).fromCorbeille, isTrue);
  });

  test('should grey a road no BAN street is named after', () async {
    shapes.roads = Ok([_road('Chemin de Halage', 45.985)]);

    final street = (await found()).single;

    expect(
      street,
      ZoneRoadWithoutAddress(
        name: 'Chemin de Halage',
        road: _roadAt(45.985),
        mark: at(45.985, 4.714),
      ),
    );
  });

  test('should list the streets to add, then those of the secteur, then '
      'the roads without address, each in French order', () async {
    shapes.roads = Ok([
      _road('Chemin de Halage', 45.981),
      _road('Rue des Lilas', 45.982),
      _road('Rue Pierre Morin', 45.983),
      _road('Allée des Écoles', 45.984),
      _road('Rue Pasteur', 45.985),
    ]);

    final names = [for (final street in await found()) street.name];

    expect(names, [
      'Rue Pasteur',
      'Rue Pierre Morin',
      'Rue des Lilas',
      'Allée des Écoles',
      'Chemin de Halage',
    ]);
  });

  test('should show two roads naming one BAN street as one row with both '
      'roads', () async {
    shapes.roads = Ok([
      _road('Rue Pierre Morin', 45.985),
      _road('Rue Pasteur', 45.986),
      _road('Rue Pierre Mörin', 45.987),
    ]);

    final streets = await found();

    expect(streets, hasLength(2));
    final morin = streets[1] as ZoneStreetToAdd;
    expect(morin.match.id, _morinId);
    expect(
      morin.road,
      StreetShape([..._roadAt(45.985).lines, ..._roadAt(45.987).lines]),
    );
    expect(morin.mark, at(45.985, 4.714));
  });

  test('should merge the roads of a street of the secteur too', () async {
    shapes.roads = Ok([
      _road('Rue des Lilas', 45.985),
      _road('Rue des Lilás', 45.987),
    ]);

    final street = (await found()).single as ZoneStreetInSector;

    expect(street.road.lines, hasLength(2));
  });

  test('should leave out a road that does not run inside the zone', () async {
    shapes.roads = Ok([
      _road('Rue Pierre Morin', 45.985),
      _road('Rue Pasteur', 45.995),
    ]);

    expect(
      [for (final street in await found()) street.name],
      ['Rue Pierre Morin'],
    );
  });

  group('a road misspelt on the map', () {
    // The map's road says « Rue de le Paix », the BAN « Rue de la Paix »
    // (#134).
    final paixId = BanStreetId('69264_1500');
    final gleizePaixId = BanStreetId('69092_0200');

    test('should match the BAN street whose name is the road\'s '
        'misspelt', () async {
      shapes.roads = Ok([_road('Rue de le Paix', 45.985)]);
      directory = FakeAddressDirectory(
        communes: {
          '69264': Ok(
            _listing(villefranche, {
              _pasteurId: 'Rue Pasteur',
              paixId: 'Rue de la Paix',
            }),
          ),
        },
      );

      final street = (await found()).single as ZoneStreetToAdd;

      expect(street.match.id, paixId);
      expect(street.name, 'Rue de la Paix');
      expect(street.road, _roadAt(45.985));
    });

    test(
      'should grey a road whose name is only near another street\'s',
      () async {
        shapes.roads = Ok([_road('Rue de la Mare', 45.985)]);
        directory = FakeAddressDirectory(
          communes: {
            '69264': Ok(_listing(villefranche, {paixId: 'Rue de la Gare'})),
          },
        );

        expect((await found()).single, isA<ZoneRoadWithoutAddress>());
      },
    );

    test('should grey a road two streets are as near to', () async {
      shapes.roads = Ok([_road('Rue d Paix', 45.985)]);
      directory = FakeAddressDirectory(
        communes: {
          '69264': Ok(
            _listing(villefranche, {
              paixId: 'Rue de Paix',
              _pasteurId: 'Rue du Paix',
            }),
          ),
        },
      );

      expect((await found()).single, isA<ZoneRoadWithoutAddress>());
    });

    test('should take an exact name in a later commune before a near one in '
        'the first', () async {
      shapes.roads = Ok([_road('Rue de le Paix', 45.985)]);
      directory = FakeAddressDirectory(
        communes: {
          '69092': Ok(_listing(_gleize, {gleizePaixId: 'Rue de la Paix'})),
          '69264': Ok(_listing(villefranche, {paixId: 'Rue de le Paix'})),
        },
      );

      final street =
          (await found(communes: ['69092', '69264'])).single as ZoneStreetToAdd;

      expect(street.match.id, paixId);
      expect(directory.communesAsked, ['69092', '69264']);
    });

    test('should take a near name in the first commune read', () async {
      shapes.roads = Ok([_road('Rue de le Paix', 45.985)]);
      directory = FakeAddressDirectory(
        communes: {
          '69092': Ok(_listing(_gleize, {gleizePaixId: 'Rue de la Paix'})),
          '69264': Ok(_listing(villefranche, {paixId: 'Rue de la Paix'})),
        },
      );

      final street =
          (await found(communes: ['69092', '69264'])).single as ZoneStreetToAdd;

      expect(street.match.id, gleizePaixId);
      expect(street.match.commune, _gleize);
    });

    test('should show a misspelt road and the road named exactly as one '
        'row', () async {
      shapes.roads = Ok([
        _road('Rue de la Paix', 45.985),
        _road('Rue de le Paix', 45.987),
      ]);
      directory = FakeAddressDirectory(
        communes: {
          '69264': Ok(_listing(villefranche, {paixId: 'Rue de la Paix'})),
        },
      );

      final street = (await found()).single as ZoneStreetToAdd;

      expect(street.match.id, paixId);
      expect(
        street.road,
        StreetShape([..._roadAt(45.985).lines, ..._roadAt(45.987).lines]),
      );
    });
  });

  group('the communes', () {
    test('should take a name found in two communes in the first', () async {
      shapes.roads = Ok([_road('Rue Pierre Morin', 45.985)]);

      final street =
          (await found(communes: ['69092', '69264'])).single as ZoneStreetToAdd;

      expect(street.match.id, _gleizeMorinId);
      expect(street.match.commune, _gleize);
      expect(directory.communesAsked, ['69092']);
    });

    test('should read the next commune while a road is unmatched', () async {
      shapes.roads = Ok([
        _road('Rue Pierre Morin', 45.985),
        _road('Rue Pasteur', 45.986),
      ]);

      final streets = await found(communes: ['69092', '69264']);

      expect(directory.communesAsked, ['69092', '69264']);
      expect(
        [for (final street in streets) (street as ZoneStreetToAdd).match.id],
        [_pasteurId, _gleizeMorinId],
      );
    });

    test('should read at most three communes', () async {
      shapes.roads = Ok([_road('Chemin de Halage', 45.985)]);

      await found(communes: ['69001', '69002', '69003', '69264']);

      expect(FindZoneStreets.communesAsked, 3);
      expect(directory.communesAsked, ['69001', '69002', '69003']);
    });

    test('should read no commune for a zone without road', () async {
      final streets = await found();

      expect(streets, isEmpty);
      expect(directory.communesAsked, isEmpty);
    });

    test('should skip a commune the BAN does not know', () async {
      shapes.roads = Ok([_road('Rue Pierre Morin', 45.985)]);

      final street =
          (await found(communes: ['69001', '69264'])).single as ZoneStreetToAdd;

      expect(street.match.id, _morinId);
    });
  });

  group('the size of the zone', () {
    List<NamedRoad> roads(int count) => [
      for (var i = 0; i < count; i++) _road('Chemin $i', 45.981 + i * 0.0001),
    ];

    test('should keep 50 streets', () async {
      shapes.roads = Ok(roads(50));

      expect(await found(), hasLength(50));
    });

    test('should refuse 51 streets, asking no commune', () async {
      shapes.roads = Ok(roads(51));

      final result = await find()(_zone, communes: [insee('69264')]);

      expect(failureOf(result), FindZoneFailure.tooManyStreets);
      expect(directory.communesAsked, isEmpty);
    });

    test('should count only the roads inside the zone', () async {
      shapes.roads = Ok([...roads(50), _road('Rue Pasteur', 45.995)]);

      expect(await found(), hasLength(50));
    });
  });

  group('failures', () {
    Future<FindZoneFailure> failure() async =>
        failureOf(await find()(_zone, communes: [insee('69264')]));

    test('should be no network when the map cannot be reached', () async {
      shapes.roads = const Err(StreetShapesFailure.noNetwork);

      expect(await failure(), FindZoneFailure.noNetwork);
    });

    test('should be a service error when the map answers one', () async {
      shapes.roads = const Err(StreetShapesFailure.serviceError);

      expect(await failure(), FindZoneFailure.serviceError);
    });

    test('should be too many streets when the zone spans too many of the '
        'map\'s tiles', () async {
      shapes.roads = const Err(StreetShapesFailure.tooLarge);

      expect(await failure(), FindZoneFailure.tooManyStreets);
      expect(directory.communesAsked, isEmpty);
    });

    test('should be no network when the BAN cannot be reached', () async {
      shapes.roads = Ok([_road('Rue Pierre Morin', 45.985)]);
      directory = FakeAddressDirectory(
        communes: {'69264': const Err(AddressDirectoryFailure.noNetwork)},
      );

      expect(await failure(), FindZoneFailure.noNetwork);
    });

    test('should be a service error when the BAN answers one', () async {
      shapes.roads = Ok([_road('Rue Pierre Morin', 45.985)]);
      directory = FakeAddressDirectory(
        communes: {'69264': const Err(AddressDirectoryFailure.serviceError)},
      );

      expect(await failure(), FindZoneFailure.serviceError);
    });
  });

  group('values', () {
    final match = StreetMatch(
      id: _morinId,
      name: streetName('Rue Pierre Morin'),
      commune: villefranche,
      position: at(45.985, 4.714),
    );

    test('should tell streets to add apart by each field', () {
      ZoneStreetToAdd make({
        int count = 19,
        double latitude = 45.985,
        bool fromCorbeille = false,
      }) => ZoneStreetToAdd(
        match: match,
        numberCount: count,
        road: _roadAt(latitude),
        mark: at(latitude, 4.714),
        fromCorbeille: fromCorbeille,
      );

      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make(count: 20), isNot(make()));
      expect(make(fromCorbeille: true), isNot(make()));
      expect(make(fromCorbeille: true).fromCorbeille, isTrue);
      expect(make(latitude: 45.986), isNot(make()));
      expect(
        make().toString(),
        'ZoneStreetToAdd(69264_1460, Rue Pierre Morin)',
      );
    });

    test('should tell streets of the secteur apart by each field', () {
      ZoneStreetInSector make({double latitude = 45.985}) => ZoneStreetInSector(
        match: match,
        road: _roadAt(latitude),
        mark: at(latitude, 4.714),
      );

      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make(latitude: 45.986), isNot(make()));
      expect(
        make().toString(),
        'ZoneStreetInSector(69264_1460, Rue Pierre Morin)',
      );
    });

    test('should tell roads without address apart by each field', () {
      ZoneRoadWithoutAddress make({String name = 'Chemin de Halage'}) =>
          ZoneRoadWithoutAddress(
            name: name,
            road: _roadAt(45.985),
            mark: at(45.985, 4.714),
          );

      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make(name: 'Chemin des Vignes'), isNot(make()));
      expect(make().toString(), 'ZoneRoadWithoutAddress(Chemin de Halage)');
    });
  });
}
