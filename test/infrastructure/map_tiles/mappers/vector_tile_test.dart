import 'dart:io' show gzip;

import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/vector_tile.dart';

import '../vector_tile_builder.dart';

const _roads = 'transportation_name';

/// The name and lines of each road of [layer], as lists the matcher
/// compares item by item (it compares records by identity).
List<List<Object>> _read(TileLayer layer) => [
  for (final road in layer.roads) [road.name, road.lines],
];

TilePoint _p(int x, int y) => (x: x, y: y);

void main() {
  test('should read the named lines of the layer, and its extent', () {
    final bytes = tile([
      layer(
        _roads,
        names: ['Rue Nationale', 'Rue de la Paix'],
        extent: 512,
        features: [
          TestFeature.road(0, [
            [(10, 20), (30, 25), (60, 5)],
          ]),
          TestFeature.road(1, [
            [(100, 200), (90, 210)],
          ]),
        ],
      ),
    ]);

    final read = namedLinesOf(bytes, _roads);

    expect(read.extent, 512);
    expect(_read(read), [
      [
        'Rue Nationale',
        [
          [_p(10, 20), _p(30, 25), _p(60, 5)],
        ],
      ],
      [
        'Rue de la Paix',
        [
          [_p(100, 200), _p(90, 210)],
        ],
      ],
    ]);
  });

  test('should read every line of a road drawn in several, from where '
      'the last one ended', () {
    final bytes = tile([
      layer(
        _roads,
        names: ['Rue Nationale'],
        features: [
          TestFeature.road(0, [
            [(10, 20), (30, 25)],
            [(40, 40), (50, 60), (70, 65)],
          ]),
        ],
      ),
    ]);

    expect(_read(namedLinesOf(bytes, _roads)), [
      [
        'Rue Nationale',
        [
          [_p(10, 20), _p(30, 25)],
          [_p(40, 40), _p(50, 60), _p(70, 65)],
        ],
      ],
    ]);
  });

  test('should give the usual extent when the layer does not say', () {
    final bytes = tile([layer(_roads)]);

    expect(namedLinesOf(bytes, _roads).extent, 4096);
  });

  test('should leave out the other layers', () {
    final bytes = tile([
      layer(
        'transportation',
        names: ['Rue Nationale'],
        features: [
          TestFeature.road(0, [
            [(1, 1), (2, 2)],
          ]),
        ],
      ),
      layer(
        _roads,
        names: ['Rue de la Paix'],
        features: [
          TestFeature.road(0, [
            [(3, 3), (4, 4)],
          ]),
        ],
      ),
    ]);

    expect(_read(namedLinesOf(bytes, _roads)), [
      [
        'Rue de la Paix',
        [
          [_p(3, 3), _p(4, 4)],
        ],
      ],
    ]);
  });

  test('should give an empty layer when the tile has not the layer', () {
    final read = namedLinesOf(tile([layer('water')]), _roads);

    expect(read.extent, 4096);
    expect(read.roads, isEmpty);
  });

  test('should read the keys and values written before the features', () {
    final bytes = tile([
      layer(
        _roads,
        names: ['Rue Nationale'],
        featuresFirst: false,
        features: [
          TestFeature.road(0, [
            [(1, 1), (2, 2)],
          ]),
        ],
      ),
    ]);

    expect(namedLinesOf(bytes, _roads).roads.single.name, 'Rue Nationale');
  });

  test('should leave out a feature that is not a line', () {
    final bytes = tile([
      layer(
        _roads,
        names: ['Place du Marché'],
        features: [
          TestFeature(
            tags: [0, 0],
            type: 3,
            geometry: lineCommands([
              [(1, 1), (2, 2)],
            ]),
          ),
        ],
      ),
    ]);

    expect(namedLinesOf(bytes, _roads).roads, isEmpty);
  });

  test('should leave out a line without a name', () {
    final bytes = tile([
      layer(
        _roads,
        keys: ['name', 'class'],
        names: ['Rue Nationale', 'minor'],
        features: [
          TestFeature(
            tags: [1, 1],
            geometry: lineCommands([
              [(1, 1), (2, 2)],
            ]),
          ),
        ],
      ),
    ]);

    expect(namedLinesOf(bytes, _roads).roads, isEmpty);
  });

  test('should leave out every line of a layer without the key name', () {
    final bytes = tile([
      layer(
        _roads,
        keys: ['class'],
        names: ['minor'],
        features: [
          TestFeature(
            tags: [0, 0],
            geometry: lineCommands([
              [(1, 1), (2, 2)],
            ]),
          ),
        ],
      ),
    ]);

    expect(namedLinesOf(bytes, _roads).roads, isEmpty);
  });

  test('should leave out a line whose name is a number', () {
    final bytes = tile([
      layer(
        _roads,
        numbers: [12],
        features: [
          TestFeature.road(0, [
            [(1, 1), (2, 2)],
          ]),
        ],
      ),
    ]);

    expect(namedLinesOf(bytes, _roads).roads, isEmpty);
  });

  test('should find the name among the other tags of the line', () {
    final bytes = tile([
      layer(
        _roads,
        keys: ['class', 'name'],
        names: ['minor', 'Rue Nationale'],
        features: [
          TestFeature(
            tags: [0, 0, 1, 1],
            geometry: lineCommands([
              [(1, 1), (2, 2)],
            ]),
          ),
        ],
      ),
    ]);

    expect(namedLinesOf(bytes, _roads).roads.single.name, 'Rue Nationale');
  });

  test('should read tags and geometry written one number a field', () {
    final bytes = tile([
      layer(
        _roads,
        names: ['Rue Nationale'],
        features: [
          TestFeature(
            tags: [0, 0],
            geometry: lineCommands([
              [(5, 6), (7, 8)],
            ]),
            packed: false,
          ),
        ],
      ),
    ]);

    expect(_read(namedLinesOf(bytes, _roads)), [
      [
        'Rue Nationale',
        [
          [_p(5, 6), _p(7, 8)],
        ],
      ],
    ]);
  });

  test('should step over a « close path » command', () {
    final bytes = tile([
      layer(
        _roads,
        names: ['Rue Nationale'],
        features: [
          TestFeature(
            tags: [0, 0],
            geometry: [
              ...lineCommands([
                [(5, 6), (7, 8)],
              ]),
              7 | 1 << 3,
            ],
          ),
        ],
      ),
    ]);

    expect(namedLinesOf(bytes, _roads).roads.single.lines, [
      [_p(5, 6), _p(7, 8)],
    ]);
  });

  test('should read a gzipped tile', () {
    final bytes = gzip.encode(
      tile([
        layer(
          _roads,
          names: ['Rue Nationale'],
          features: [
            TestFeature.road(0, [
              [(1, 1), (2, 2)],
            ]),
          ],
        ),
      ]),
    );

    expect(namedLinesOf(bytes, _roads).roads.single.name, 'Rue Nationale');
  });

  test('should step over fields of the tile it does not need', () {
    final writer = ProtobufWriter()
      // A field 3 that is not a layer, then a field of eight bytes.
      ..varintField(3, 1)
      ..key(9, 1)
      ..bytes.addAll(List.filled(8, 0));
    final bytes = [
      ...writer.bytes,
      ...tile([
        layer(_roads, names: ['Rue Nationale']),
      ]),
    ];

    expect(namedLinesOf(bytes, _roads).extent, 4096);
  });

  test('should step over a value of a number in another format', () {
    final value = ProtobufWriter()
      ..key(2, 5)
      ..bytes.addAll([0, 0, 0, 0]);
    final layerBytes = [
      ...layer(
        _roads,
        names: ['Rue Nationale'],
        features: [
          TestFeature.road(0, [
            [(1, 1), (2, 2)],
          ]),
        ],
      ),
      ...(ProtobufWriter()..bytesField(4, value.bytes)).bytes,
    ];

    expect(
      namedLinesOf(tile([layerBytes]), _roads).roads.single.name,
      'Rue Nationale',
    );
  });

  group('damaged tiles', () {
    test('should refuse a tile cut short', () {
      final bytes = tile([
        layer(
          _roads,
          names: ['Rue Nationale'],
          features: [
            TestFeature.road(0, [
              [(1, 1), (2, 2)],
            ]),
          ],
        ),
      ]);

      expect(
        () => namedLinesOf(bytes.sublist(0, bytes.length - 3), _roads),
        throwsFormatException,
      );
    });

    test('should refuse a tag pointing past the values', () {
      final bytes = tile([
        layer(
          _roads,
          names: ['Rue Nationale'],
          features: [
            TestFeature.road(1, [
              [(1, 1), (2, 2)],
            ]),
          ],
        ),
      ]);

      expect(() => namedLinesOf(bytes, _roads), throwsFormatException);
    });

    test('should refuse an unknown geometry command', () {
      final bytes = tile([
        layer(
          _roads,
          names: ['Rue Nationale'],
          features: [
            const TestFeature(tags: [0, 0], geometry: [3 | 1 << 3, 2, 2]),
          ],
        ),
      ]);

      expect(() => namedLinesOf(bytes, _roads), throwsFormatException);
    });

    test('should refuse a geometry cut short', () {
      final bytes = tile([
        layer(
          _roads,
          names: ['Rue Nationale'],
          features: [
            const TestFeature(tags: [0, 0], geometry: [1 | 1 << 3, 2]),
          ],
        ),
      ]);

      expect(() => namedLinesOf(bytes, _roads), throwsFormatException);
    });

    test('should refuse a line drawn before any move', () {
      final bytes = tile([
        layer(
          _roads,
          names: ['Rue Nationale'],
          features: [
            const TestFeature(tags: [0, 0], geometry: [2 | 1 << 3, 2, 2]),
          ],
        ),
      ]);

      expect(() => namedLinesOf(bytes, _roads), throwsFormatException);
    });

    test('should accept a geometry using exactly its numbers', () {
      final bytes = tile([
        layer(
          _roads,
          names: ['Rue Nationale'],
          features: [
            const TestFeature(
              tags: [0, 0],
              geometry: [1 | 1 << 3, 2, 4, 2 | 1 << 3, 2, 2],
            ),
          ],
        ),
      ]);

      expect(namedLinesOf(bytes, _roads).roads.single.lines, [
        [_p(1, 2), _p(2, 3)],
      ]);
    });
  });
}
