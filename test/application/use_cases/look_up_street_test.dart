// What the street card of « Ajouter des rues » shows (PLAN §5.4): the BAN
// street under a tap, or chosen in the search, and whether the tournée has
// it already.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

final _tap = at(45.98800, 4.72500);
final _morinId = BanStreetId('69264_1460');

final _morin = StreetMatch(
  id: _morinId,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  position: at(45.98810, 4.72490),
);

final _morinNumbers = StreetNumbers(
  id: _morinId,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('1'), position: townHallDoor),
    DirectoryNumber(number: n('3')),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

/// The match of the Rue des Lilas, which the tournée has.
final _lilasMatch = StreetMatch(
  id: lilas.banId!,
  name: streetName('Rue des Lilas'),
  commune: villefranche,
  position: northDoor,
);

/// A road of the map running east–west, [metres] north of [_tap].
NamedRoad _roadNorthOfTap(String name, double metres) {
  final latitude = _tap.latitude + metres / metresPerDegree;
  return NamedRoad(
    name: name,
    shape: StreetShape([
      [at(latitude, 4.72400), at(latitude, 4.72600)],
    ]),
  );
}

void main() {
  late FakeStreetRepository streets;
  late FakeStreetShapes shapes;

  setUp(() {
    streets = repositoryWithLilas();
    // By default the map has no road near the tap: the BAN's nearest
    // street is taken.
    shapes = FakeStreetShapes();
  });

  LookUpStreet lookUp(FakeAddressDirectory directory) =>
      LookUpStreet(directory, streets, shapes);

  group('a tap on the map', () {
    test('should give the street under the tap with its numbers when the '
        'tournée does not have it', () async {
      final directory = FakeAddressDirectory(
        places: {_tap: Ok(_morin)},
        streets: {_morinId: Ok(_morinNumbers)},
      );

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found, isA<StreetToAdd>());
      found as StreetToAdd;
      expect(found.match, _morin);
      expect(found.numbers, same(_morinNumbers));
      expect(found.numberCount, 2);
      expect(directory.pointsAsked, [_tap]);
      expect(directory.streetsAsked, [_morinId]);
    });

    test('should give the street of the tournée when it has it, without '
        'asking its numbers', () async {
      final directory = FakeAddressDirectory(places: {_tap: Ok(_lilasMatch)});

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found, isA<StreetOfTheSector>());
      found as StreetOfTheSector;
      expect(found.match, _lilasMatch);
      expect(found.street, same(lilas));
      expect(directory.streetsAsked, isEmpty);
    });

    test('should offer to add again a street of the Corbeille', () async {
      final (deleted, change) = lilas.delete(by: lea, at: twoPm);
      await streets.save(deleted, change);
      final directory = FakeAddressDirectory(
        places: {_tap: Ok(_lilasMatch)},
        streets: {lilas.banId!: Ok(_morinNumbers)},
      );

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found, isA<StreetToAdd>());
      expect(directory.streetsAsked, [lilas.banId]);
    });

    test('should say no street is there when the BAN has no match', () async {
      final directory = FakeAddressDirectory();

      final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(failure, AddressDirectoryFailure.notFound);
      expect(directory.streetsAsked, isEmpty);
    });

    test('should say the network is missing when offline', () async {
      final directory = FakeAddressDirectory(
        places: {_tap: const Err(AddressDirectoryFailure.noNetwork)},
      );

      final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(failure, AddressDirectoryFailure.noNetwork);
    });

    test('should say the network is missing when it goes before the '
        'numbers come', () async {
      final directory = FakeAddressDirectory(
        places: {_tap: Ok(_morin)},
        streets: {_morinId: const Err(AddressDirectoryFailure.noNetwork)},
      );

      final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(failure, AddressDirectoryFailure.noNetwork);
    });
  });

  group('the road under the finger', () {
    // The geocoder answers the street whose one point is nearest the tap,
    // not the road under the finger: here the Rue des Lilas, whose middle
    // is nearer than the Rue Pierre Morin's, which the finger is on.
    late FakeAddressDirectory directory;

    setUp(() {
      directory = FakeAddressDirectory(
        places: {_tap: Ok(_lilasMatch)},
        searches: {
          'Rue Pierre Morin': Ok([_morin]),
        },
        streets: {_morinId: Ok(_morinNumbers)},
      );
    });

    test('should look for the roads of the map around the tap', () async {
      await lookUp(directory)(StreetAtPoint(_tap));

      expect(shapes.zonesAsked, [
        GeoBounds.around([_tap])!.expandedBy(LookUpStreet.tapReachMetres),
      ]);
    });

    test('should give the BAN street named as the road under the finger '
        'when the nearest BAN street is another one', () async {
      shapes.roads = Ok([_roadNorthOfTap('Rue Pierre Morin', 2)]);

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found, isA<StreetToAdd>());
      expect(found.match, _morin);
      expect(directory.searchesAsked, [('Rue Pierre Morin', '69264')]);
      expect(directory.streetsAsked, [_morinId]);
    });

    test('should take the nearest of the roads around the tap', () async {
      shapes.roads = Ok([
        _roadNorthOfTap('Rue des Lilas', 20),
        _roadNorthOfTap('Rue Pierre Morin', 5),
        _roadNorthOfTap('Rue du Moulin', 25),
      ]);

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found.match, _morin);
    });

    test('should take a road just within reach', () async {
      shapes.roads = Ok([
        _roadNorthOfTap('Rue Pierre Morin', LookUpStreet.tapReachMetres - 1),
      ]);

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found.match, _morin);
    });

    test('should give the nearest BAN street when no road is within '
        'reach', () async {
      shapes.roads = Ok([
        _roadNorthOfTap('Rue Pierre Morin', LookUpStreet.tapReachMetres + 1),
      ]);

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found, isA<StreetOfTheSector>());
      expect(found.match, _lilasMatch);
      expect(directory.searchesAsked, isEmpty);
    });

    test('should give the nearest BAN street when the map cannot '
        'answer', () async {
      shapes.roads = const Err(StreetShapesFailure.noNetwork);

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found.match, _lilasMatch);
      expect(directory.searchesAsked, isEmpty);
    });

    test('should not search when the nearest BAN street is the road under '
        'the finger, written without its accents', () async {
      final musee = StreetMatch(
        id: BanStreetId('69264_1300'),
        name: streetName('Rue du Musee'),
        commune: villefranche,
        position: at(45.98820, 4.72490),
      );
      final museeNumbers = StreetNumbers(
        id: musee.id,
        name: musee.name,
        commune: villefranche,
        numbers: [DirectoryNumber(number: n('2'))],
        invalidNumbers: 0,
        duplicateNumbers: 0,
      );
      final directory = FakeAddressDirectory(
        places: {_tap: Ok(musee)},
        streets: {musee.id: Ok(museeNumbers)},
      );
      shapes.roads = Ok([_roadNorthOfTap('Rue du Musée', 3)]);

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found.match, musee);
      expect(directory.searchesAsked, isEmpty);
    });

    test('should say no street is there when the BAN has none named as the '
        'road under the finger', () async {
      final directory = FakeAddressDirectory(
        places: {_tap: Ok(_lilasMatch)},
        // The search is loose: it finds a longer name, which is not the
        // road's.
        searches: {
          'Rue Pierre': Ok([_morin]),
        },
      );
      shapes.roads = Ok([_roadNorthOfTap('Rue Pierre', 2)]);

      final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(failure, AddressDirectoryFailure.notFound);
      expect(directory.searchesAsked, [('Rue Pierre', '69264')]);
      expect(directory.streetsAsked, isEmpty);
    });

    group('a road misspelt on the map', () {
      // The map's road says « Rue de le Paix », the BAN « Rue de la Paix »
      // (#134: « Aucune rue connue ici. » although the street exists).
      final paix = StreetMatch(
        id: BanStreetId('69264_1500'),
        name: streetName('Rue de la Paix'),
        commune: villefranche,
        position: at(45.98805, 4.72495),
      );
      final paixNumbers = StreetNumbers(
        id: paix.id,
        name: paix.name,
        commune: villefranche,
        numbers: [DirectoryNumber(number: n('4'))],
        invalidNumbers: 0,
        duplicateNumbers: 0,
      );
      final gare = StreetMatch(
        id: BanStreetId('69264_1510'),
        name: streetName('Rue de la Gare'),
        commune: villefranche,
        position: at(45.98900, 4.72400),
      );

      setUp(() {
        shapes.roads = Ok([_roadNorthOfTap('Rue de le Paix', 2)]);
      });

      test('should give the BAN street of the commune whose name is that '
          'road misspelt', () async {
        final directory = FakeAddressDirectory(
          places: {_tap: Ok(_lilasMatch)},
          searches: {
            'Rue de le Paix': Ok([gare, paix]),
          },
          streets: {paix.id: Ok(paixNumbers)},
        );

        final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

        expect(found, isA<StreetToAdd>());
        expect(found.match, paix);
        expect(directory.searchesAsked, [('Rue de le Paix', '69264')]);
        expect(directory.streetsAsked, [paix.id]);
      });

      test('should give the nearest BAN street when its name is that road '
          'misspelt and the search does not find it', () async {
        final directory = FakeAddressDirectory(
          places: {_tap: Ok(paix)},
          searches: {
            'Rue de le Paix': Ok([gare]),
          },
          streets: {paix.id: Ok(paixNumbers)},
        );

        final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

        expect(found.match, paix);
        expect(directory.streetsAsked, [paix.id]);
      });

      test('should prefer a BAN street named exactly as the road to a '
          'nearest street that is close', () async {
        final dePaix = StreetMatch(
          id: BanStreetId('69264_1520'),
          name: streetName('Rue de Paix'),
          commune: villefranche,
          position: at(45.98806, 4.72496),
        );
        final duPaix = StreetMatch(
          id: BanStreetId('69264_1530'),
          name: streetName('Rue du Paix'),
          commune: villefranche,
          position: at(45.98807, 4.72497),
        );
        shapes.roads = Ok([_roadNorthOfTap('Rue du Paix', 2)]);
        final directory = FakeAddressDirectory(
          places: {_tap: Ok(dePaix)},
          searches: {
            'Rue du Paix': Ok([duPaix]),
          },
          streets: {duPaix.id: Ok(paixNumbers)},
        );

        final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

        expect(found.match, duPaix);
      });

      test('should say no street is there when two BAN streets are as close '
          'to the road\'s name', () async {
        final dePaix = StreetMatch(
          id: BanStreetId('69264_1520'),
          name: streetName('Rue de Paix'),
          commune: villefranche,
          position: at(45.98806, 4.72496),
        );
        final duPaix = StreetMatch(
          id: BanStreetId('69264_1530'),
          name: streetName('Rue du Paix'),
          commune: villefranche,
          position: at(45.98807, 4.72497),
        );
        shapes.roads = Ok([_roadNorthOfTap('Rue d Paix', 2)]);
        final directory = FakeAddressDirectory(
          places: {_tap: Ok(_lilasMatch)},
          searches: {
            'Rue d Paix': Ok([dePaix, duPaix]),
          },
        );

        final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

        expect(failure, AddressDirectoryFailure.notFound);
        expect(directory.streetsAsked, isEmpty);
      });

      test('should say no street is there when the only BAN street near the '
          'name is another one', () async {
        shapes.roads = Ok([_roadNorthOfTap('Rue de la Mare', 2)]);
        final directory = FakeAddressDirectory(
          places: {_tap: Ok(gare)},
          searches: {
            'Rue de la Mare': Ok([gare]),
          },
        );

        final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

        expect(failure, AddressDirectoryFailure.notFound);
      });
    });

    test('should pass on a search that fails', () async {
      final directory = FakeAddressDirectory(
        places: {_tap: Ok(_lilasMatch)},
        searches: {
          'Rue Pierre Morin': const Err(AddressDirectoryFailure.noNetwork),
        },
      );
      shapes.roads = Ok([_roadNorthOfTap('Rue Pierre Morin', 2)]);

      final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(failure, AddressDirectoryFailure.noNetwork);
    });

    test('should not ask the map for a street found by the search', () async {
      await lookUp(directory)(FoundStreet(_morin));

      expect(shapes.zonesAsked, isEmpty);
    });
  });

  group('a street found by the search', () {
    test('should give its numbers without asking the geocoder', () async {
      final directory = FakeAddressDirectory(
        streets: {_morinId: Ok(_morinNumbers)},
      );

      final found = valueOf(await lookUp(directory)(FoundStreet(_morin)));

      expect(found, isA<StreetToAdd>());
      found as StreetToAdd;
      expect(found.match, _morin);
      expect(found.numberCount, 2);
      expect(directory.pointsAsked, isEmpty);
    });

    test('should give the street of the tournée when it has it', () async {
      final directory = FakeAddressDirectory();

      final found = valueOf(await lookUp(directory)(FoundStreet(_lilasMatch)));

      expect((found as StreetOfTheSector).street.id, lilasId);
      expect(directory.streetsAsked, isEmpty);
    });

    test('should pass on a BAN that cannot answer', () async {
      final directory = FakeAddressDirectory(
        streets: {_morinId: const Err(AddressDirectoryFailure.serviceError)},
      );

      final failure = failureOf(await lookUp(directory)(FoundStreet(_morin)));

      expect(failure, AddressDirectoryFailure.serviceError);
    });
  });

  test('should not change any street', () async {
    final directory = FakeAddressDirectory(
      places: {_tap: Ok(_morin)},
      streets: {_morinId: Ok(_morinNumbers)},
    );

    await lookUp(directory)(StreetAtPoint(_tap));

    expect(streets.added, isEmpty);
    expect(streets.saved, isEmpty);
    expect(await streets.findByBanId(_morinId), isNull);
    expect(streets[lilasId], isA<Street>());
  });
}
