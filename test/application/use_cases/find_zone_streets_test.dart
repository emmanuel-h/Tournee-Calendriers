// The streets of a zone drawn on « Ajouter des rues » (PLAN §5.14, §5.18):
// the stretches of IGN BD TOPO in it, grouped by the BAN street they carry.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/use_cases/find_zone_streets.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/geometry/road_side.dart';
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

/// A street of a neighbouring commune, made up (no real place but
/// Villefranche in tests).
final _neighbourId = BanStreetId('69400_0100');
final _neighbour = valueOf(
  Commune.create(inseeCode: '69400', name: 'Commune voisine'),
);

/// A stretch across the zone at [latitude], from 4.712 to 4.716 E: its
/// mark is at 4.714 E.
StreetShape _roadAt(double latitude) => StreetShape([
  [at(latitude, 4.712), at(latitude, 4.716)],
]);

/// A stretch of BD TOPO at [latitude] carrying the BAN street [id], named
/// [name] (by BD TOPO), in [commune].
BanRoad _stretch(
  BanStreetId? id,
  double latitude, {
  String name = 'Nom BD TOPO',
  String? commune = '69264',
  RoadSide? side,
}) => BanRoad(
  banId: id,
  name: name,
  commune: commune == null ? null : insee(commune),
  shape: _roadAt(latitude),
  side: side,
);

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
        '69400': Ok(_listing(_neighbour, {_neighbourId: 'Rue du Moulin'})),
      },
    );
  });

  Future<List<ZoneStreet>> found() => find()(_zone).then(valueOf);

  test('should offer a BAN street the secteur does not have, as the BAN '
      'names it, with its numbers and its mark in the zone', () async {
    shapes.banRoads = Ok([_stretch(_morinId, 45.985)]);

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
    expect(shapes.areasAsked, [_zone]);
    expect(directory.communesAsked, ['69264']);
  });

  test('should not ask the map\'s roads by name', () async {
    shapes.banRoads = Ok([_stretch(_morinId, 45.985)]);

    await found();

    expect(shapes.namedAreasAsked, isEmpty);
  });

  test('should grey a street the secteur has already', () async {
    shapes.banRoads = Ok([_stretch(lilas.banId, 45.985)]);

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
    shapes.banRoads = Ok([_stretch(lilas.banId, 45.985)]);

    final street = (await found()).single;
    expect(street, isA<ZoneStreetToAdd>());
    expect((street as ZoneStreetToAdd).fromCorbeille, isTrue);
  });

  test('should grey a named road without BAN street, by its own '
      'name', () async {
    shapes.banRoads = Ok([_stretch(null, 45.985, name: 'ESP PAUL BERT')]);

    final street = (await found()).single;

    expect(
      street,
      ZoneRoadWithoutAddress(
        name: 'ESP PAUL BERT',
        road: _roadAt(45.985),
        mark: at(45.985, 4.714),
      ),
    );
    expect(directory.communesAsked, isEmpty);
  });

  test('should show the stretches of one road without BAN street as one '
      'row', () async {
    shapes.banRoads = Ok([
      _stretch(null, 45.985, name: 'ESP PAUL BERT'),
      _stretch(null, 45.987, name: 'ESP PAUL BERT'),
    ]);

    final street = (await found()).single as ZoneRoadWithoutAddress;

    expect(
      street.road,
      StreetShape([..._roadAt(45.985).lines, ..._roadAt(45.987).lines]),
    );
    expect(street.mark, at(45.985, 4.714));
  });

  test('should grey a BAN street the BAN no longer lists, by the name BD '
      'TOPO gives it', () async {
    shapes.banRoads = Ok([
      _stretch(BanStreetId('69264_9999'), 45.985, name: 'Rue Disparue'),
    ]);

    final street = (await found()).single;

    expect(
      street,
      ZoneRoadWithoutAddress(
        name: 'Rue Disparue',
        road: _roadAt(45.985),
        mark: at(45.985, 4.714),
      ),
    );
  });

  test('should grey a BAN street of a commune the BAN does not '
      'know', () async {
    shapes.banRoads = Ok([
      _stretch(BanStreetId('69401_0001'), 45.985, commune: '69401'),
      _stretch(_morinId, 45.986),
    ]);

    final streets = await found();

    expect(streets.map((street) => street.runtimeType), [
      ZoneStreetToAdd,
      ZoneRoadWithoutAddress,
    ]);
    expect(directory.communesAsked, ['69401', '69264']);
  });

  test('should grey a BAN street without commune, asking no '
      'commune', () async {
    shapes.banRoads = Ok([_stretch(_morinId, 45.985, commune: null)]);

    expect((await found()).single, isA<ZoneRoadWithoutAddress>());
    expect(directory.communesAsked, isEmpty);
  });

  test('should list the streets to add, then those of the secteur, then '
      'the roads without address, each in French order', () async {
    shapes.banRoads = Ok([
      _stretch(null, 45.981, name: 'Chemin de Halage'),
      _stretch(lilas.banId, 45.982),
      _stretch(_morinId, 45.983),
      _stretch(null, 45.984, name: 'Allée des Écoles'),
      _stretch(_pasteurId, 45.985),
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

  test('should show the stretches of one BAN street as one row with all '
      'of them, its mark on the first', () async {
    shapes.banRoads = Ok([
      _stretch(_morinId, 45.985),
      _stretch(_pasteurId, 45.986),
      _stretch(_morinId, 45.987, name: 'Autre nom'),
    ]);

    final streets = await found();

    expect(streets, hasLength(2));
    final morin = streets[1] as ZoneStreetToAdd;
    expect(morin.match.id, _morinId);
    expect(morin.name, 'Rue Pierre Morin');
    expect(
      morin.road,
      StreetShape([..._roadAt(45.985).lines, ..._roadAt(45.987).lines]),
    );
    expect(morin.mark, at(45.985, 4.714));
  });

  test('should give a row to each side of a stretch between two '
      'streets', () async {
    shapes.banRoads = Ok([
      _stretch(_morinId, 45.985, side: RoadSide.left),
      _stretch(_pasteurId, 45.985, side: RoadSide.right),
    ]);

    final streets = await found();

    expect(streets.map((street) => street.name), [
      'Rue Pasteur',
      'Rue Pierre Morin',
    ]);
    expect(streets.map((street) => street.road), [
      _roadAt(45.985),
      _roadAt(45.985),
    ]);
  });

  test('should read each commune of the zone once, in the order its '
      'streets come', () async {
    shapes.banRoads = Ok([
      _stretch(_neighbourId, 45.984, commune: '69400'),
      _stretch(_morinId, 45.985),
      _stretch(_pasteurId, 45.986),
    ]);

    final streets = await found();

    expect(directory.communesAsked, ['69400', '69264']);
    final moulin = streets.whereType<ZoneStreetToAdd>().firstWhere(
      (street) => street.match.id == _neighbourId,
    );
    expect(moulin.match.commune, _neighbour);
    expect(moulin.name, 'Rue du Moulin');
  });

  test('should leave out a stretch that does not run inside the '
      'zone', () async {
    shapes.banRoads = Ok([
      _stretch(_morinId, 45.985),
      _stretch(_pasteurId, 45.995),
      _stretch(null, 45.995, name: 'ESP PAUL BERT'),
    ]);

    expect(
      [for (final street in await found()) street.name],
      ['Rue Pierre Morin'],
    );
  });

  test('should read no commune for a zone without road', () async {
    expect(await found(), isEmpty);
    expect(directory.communesAsked, isEmpty);
  });

  group('the size of the zone', () {
    List<BanRoad> stretches(int count) => [
      for (var i = 0; i < count; i++)
        _stretch(
          BanStreetId('69264_${1000 + i}'),
          45.981 + i * 0.0001,
          name: 'Chemin $i',
        ),
    ];

    test('should keep 50 streets', () async {
      shapes.banRoads = Ok(stretches(50));

      expect(await found(), hasLength(50));
    });

    test('should refuse 51 streets, asking no commune', () async {
      shapes.banRoads = Ok(stretches(51));

      final result = await find()(_zone);

      expect(failureOf(result), FindZoneFailure.tooManyStreets);
      expect(directory.communesAsked, isEmpty);
    });

    test('should count each street once, however many its '
        'stretches', () async {
      shapes.banRoads = Ok([
        ...stretches(50),
        _stretch(BanStreetId('69264_1000'), 45.989),
      ]);

      expect(await found(), hasLength(50));
    });

    test('should not count the roads without BAN street', () async {
      shapes.banRoads = Ok([
        ...stretches(50),
        _stretch(null, 45.989, name: 'ESP PAUL BERT'),
      ]);

      expect(await found(), hasLength(51));
    });

    test('should count only the streets inside the zone', () async {
      shapes.banRoads = Ok([
        ...stretches(50),
        _stretch(BanStreetId('69264_2000'), 45.995),
      ]);

      expect(await found(), hasLength(50));
    });
  });

  group('failures', () {
    Future<FindZoneFailure> failure() async => failureOf(await find()(_zone));

    test('should be no network when BD TOPO cannot be reached', () async {
      shapes.banRoads = const Err(StreetShapesFailure.noNetwork);

      expect(await failure(), FindZoneFailure.noNetwork);
    });

    test('should be a service error when BD TOPO answers one', () async {
      shapes.banRoads = const Err(StreetShapesFailure.serviceError);

      expect(await failure(), FindZoneFailure.serviceError);
    });

    test('should be too many streets when the zone holds too many '
        'stretches', () async {
      shapes.banRoads = const Err(StreetShapesFailure.tooLarge);

      expect(await failure(), FindZoneFailure.tooManyStreets);
      expect(directory.communesAsked, isEmpty);
    });

    test('should be no network when the BAN cannot be reached', () async {
      shapes.banRoads = Ok([_stretch(_morinId, 45.985)]);
      directory = FakeAddressDirectory(
        communes: {'69264': const Err(AddressDirectoryFailure.noNetwork)},
      );

      expect(await failure(), FindZoneFailure.noNetwork);
    });

    test('should be a service error when the BAN answers one', () async {
      shapes.banRoads = Ok([_stretch(_morinId, 45.985)]);
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
