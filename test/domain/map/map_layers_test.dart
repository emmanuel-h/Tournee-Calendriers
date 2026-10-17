import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _nationale = StreetId('rue-nationale');
final _paix = StreetId('rue-de-la-paix');

final _nationaleShape = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
]);
final _paixShape = StreetShape([
  [at(45.98500, 4.72000), at(45.98600, 4.72100)],
  [at(45.98600, 4.72100), at(45.98700, 4.72100)],
]);

final _door1 = at(45.98920, 4.71860);
final _door2 = at(45.98930, 4.71850);
final _door3 = at(45.98940, 4.71840);

/// Rue Nationale, covered by Léa: 1 done, 2 to do, both placed; 4 typed in
/// by hand (no position).
final _nationaleStreet = valueOf(
  Street.create(
    id: _nationale,
    name: 'Rue Nationale',
    commune: villefranche,
    shape: _nationaleShape,
    assignees: {lea},
    houses: [
      House(number: n('1'), status: VisitStatus.done, position: _door1),
      House(number: n('2'), position: _door2),
      House(number: n('4')),
    ],
  ),
);

/// Rue de la Paix: one house, to do; nobody covers it.
final _paixStreet = valueOf(
  Street.create(
    id: _paix,
    name: 'Rue de la Paix',
    commune: villefranche,
    shape: _paixShape,
    houses: [House(number: n('3'), position: _door3)],
  ),
);

void main() {
  group('lines', () {
    test('should draw each street with its shape and its level', () {
      final layers = MapLayers.of([_nationaleStreet, _paixStreet]);

      expect(layers.lines, [
        StreetLine(
          street: _nationale,
          shape: _nationaleShape,
          level: ProgressLevel.partial,
        ),
        StreetLine(street: _paix, shape: _paixShape, level: ProgressLevel.free),
      ]);
    });

    test('should be « à faire » when taken and nothing visited', () {
      final (taken, _) = valueOf(_paixStreet.take(paul));

      final layers = MapLayers.of([taken]);

      expect(layers.lines.single.level, ProgressLevel.toDo);
    });

    test('should draw no line for a street without shape', () {
      final manual = Street.manual(
        id: StreetId('chemin-neuf'),
        name: streetName('Chemin Neuf'),
        commune: villefranche,
        numbers: [n('1')],
      );

      final layers = MapLayers.of([manual, _paixStreet]);

      expect(layers.lines.map((line) => line.street), [_paix]);
    });

    test('should leave out a street in the Corbeille', () {
      final (deleted, _) = _nationaleStreet.delete(by: lea, at: twoPm);

      final layers = MapLayers.of([deleted, _paixStreet]);

      expect(layers.lines.map((line) => line.street), [_paix]);
      expect(layers.dots.map((dot) => dot.street), [_paix]);
    });
  });

  group('dots', () {
    test('should place each house that has a position, with its status', () {
      final layers = MapLayers.of([_nationaleStreet, _paixStreet]);

      expect(layers.dots, [
        HouseDot(
          street: _nationale,
          number: n('1'),
          position: _door1,
          status: HouseDotStatus.done,
        ),
        HouseDot(
          street: _nationale,
          number: n('2'),
          position: _door2,
          status: HouseDotStatus.toDo,
        ),
        HouseDot(
          street: _paix,
          number: n('3'),
          position: _door3,
          status: HouseDotStatus.toDo,
        ),
      ]);
    });

    final singles = <(VisitStatus, HouseDotStatus)>[
      (VisitStatus.toDo, HouseDotStatus.toDo),
      (VisitStatus.done, HouseDotStatus.done),
      (VisitStatus.nobodyHome, HouseDotStatus.nobodyHome),
      (VisitStatus.comeBack, HouseDotStatus.comeBack),
    ];
    for (final (status, dotStatus) in singles) {
      test('should show ${dotStatus.name} when a house is ${status.name}', () {
        final street = _withHouse(
          House(number: n('7'), status: status, position: _door1),
        );

        expect(_dotOf(street).status, dotStatus);
      });
    }

    group('of a building', () {
      // A building of two doors on the ground floor: 01 and 02.
      final street = _withHouse(
        House(
          number: n('7'),
          position: _door1,
          building: building(topFloor: 0, doors: 2),
        ),
      );
      final door01 = DwellingKey(escA, 0, d('01'));
      final door02 = DwellingKey(escA, 0, d('02'));

      Street marked(Street street, DwellingKey door) => valueOf(
        street.markDwelling(n('7'), door, VisitStatus.done, by: lea, at: twoPm),
      ).$1;

      test('should show to do when no door is done', () {
        expect(_dotOf(street).status, HouseDotStatus.toDo);
      });

      test('should show partial when some doors are done', () {
        expect(_dotOf(marked(street, door01)).status, HouseDotStatus.partial);
      });

      test('should show done when every door is done', () {
        final done = marked(marked(street, door01), door02);

        expect(_dotOf(done).status, HouseDotStatus.done);
      });

      test('should show come back when the building has its own', () {
        final done = marked(marked(street, door01), door02);
        final (comingBack, _) = valueOf(
          done.setComeBack(n('7'), comeBack('soir'), by: lea, at: twoPm),
        );

        expect(_dotOf(comingBack).status, HouseDotStatus.comeBack);
      });
    });
  });

  test('should show the dots from zoom 16', () {
    expect(MapLayers.houseDotsMinZoom, 16);
  });

  test('should give lists that cannot be modified', () {
    final layers = MapLayers.of([_paixStreet]);

    expect(layers.lines.clear, throwsUnsupportedError);
    expect(layers.dots.clear, throwsUnsupportedError);
  });

  group('StreetLine equality', () {
    final line = StreetLine(
      street: _paix,
      shape: _paixShape,
      level: ProgressLevel.done,
    );

    test('should be equal with the same fields', () {
      final same = StreetLine(
        street: _paix,
        shape: _paixShape,
        level: ProgressLevel.done,
      );

      expect(line, same);
      expect(line.hashCode, same.hashCode);
    });

    final others = <(String, StreetLine)>[
      (
        'street',
        StreetLine(
          street: _nationale,
          shape: _paixShape,
          level: ProgressLevel.done,
        ),
      ),
      (
        'shape',
        StreetLine(
          street: _paix,
          shape: _nationaleShape,
          level: ProgressLevel.done,
        ),
      ),
      (
        'level',
        StreetLine(
          street: _paix,
          shape: _paixShape,
          level: ProgressLevel.partial,
        ),
      ),
    ];
    for (final (field, other) in others) {
      test('should differ with another $field', () {
        expect(line, isNot(other));
      });
    }

    test('should print its street and level', () {
      expect(line.toString(), 'StreetLine(rue-de-la-paix, done)');
    });
  });

  group('HouseDot equality', () {
    final dot = HouseDot(
      street: _paix,
      number: n('3'),
      position: _door3,
      status: HouseDotStatus.done,
    );

    test('should be equal with the same fields', () {
      final same = HouseDot(
        street: _paix,
        number: n('3'),
        position: _door3,
        status: HouseDotStatus.done,
      );

      expect(dot, same);
      expect(dot.hashCode, same.hashCode);
    });

    final others = <(String, HouseDot)>[
      (
        'street',
        HouseDot(
          street: _nationale,
          number: n('3'),
          position: _door3,
          status: HouseDotStatus.done,
        ),
      ),
      (
        'number',
        HouseDot(
          street: _paix,
          number: n('3bis'),
          position: _door3,
          status: HouseDotStatus.done,
        ),
      ),
      (
        'position',
        HouseDot(
          street: _paix,
          number: n('3'),
          position: _door1,
          status: HouseDotStatus.done,
        ),
      ),
      (
        'status',
        HouseDot(
          street: _paix,
          number: n('3'),
          position: _door3,
          status: HouseDotStatus.toDo,
        ),
      ),
    ];
    for (final (field, other) in others) {
      test('should differ with another $field', () {
        expect(dot, isNot(other));
      });
    }

    test('should print its street, number and status', () {
      expect(dot.toString(), 'HouseDot(rue-de-la-paix, 3, done)');
    });
  });

  group('showsHouseDots', () {
    test('should show the dots from street zoom', () {
      expect(MapLayers.showsHouseDots(16), isTrue);
      expect(MapLayers.showsHouseDots(17.5), isTrue);
    });

    test('should not show them under street zoom', () {
      expect(MapLayers.showsHouseDots(15.99), isFalse);
      expect(MapLayers.showsHouseDots(12), isFalse);
    });
  });
}

/// A street of one [house].
Street _withHouse(House house) => valueOf(
  Street.create(
    id: _paix,
    name: 'Rue de la Paix',
    commune: villefranche,
    houses: [house],
  ),
);

/// The only dot of [street].
HouseDot _dotOf(Street street) => MapLayers.of([street]).dots.single;
