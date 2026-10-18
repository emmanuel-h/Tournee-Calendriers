import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_grid.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/openfreemap_street_shapes.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'vector_tile_builder.dart';

const _template =
    'https://tiles.openfreemap.org/planet/20261011_080001_pt/{z}/{x}/{y}.pbf';

/// Two zoom-14 tiles of Villefranche-sur-Saône, side by side.
const _west = TileId(zoom: 14, x: 8406, y: 5829);
const _east = TileId(zoom: 14, x: 8407, y: 5829);

Uri _urlOf(TileId tile) => Uri.parse(
  'https://tiles.openfreemap.org/planet/20261011_080001_pt/'
  '${tile.zoom}/${tile.x}/${tile.y}.pbf',
);

GeoPoint _at(TileId tile, int x, int y) =>
    geoPointOf(tile, (x: x, y: y), 4096)!;

/// An area inside the tile [tile] only.
GeoBounds _inside(TileId tile) =>
    GeoBounds.around([_at(tile, 500, 500), _at(tile, 3500, 3500)])!;

/// A tile with Rue Nationale running from (1000, 2000) to (3000, 2000).
List<int> _nationaleTile() => tile([
  layer(
    'transportation_name',
    names: ['Rue Nationale'],
    features: [
      TestFeature.road(0, [
        [(1000, 2000), (3000, 2000)],
      ]),
    ],
  ),
]);

final _nationaleInWest = StreetShape([
  [_at(_west, 1000, 2000), _at(_west, 3000, 2000)],
]);

void main() {
  late List<http.Request> requests;

  /// What the server answers to each address; any other tile is empty.
  late Map<Uri, Future<http.Response> Function()> answers;

  setUp(() {
    requests = [];
    answers = {
      OpenFreeMapStreetShapes.tileJsonUrl: () async => http.Response(
        jsonEncode({
          'tiles': [_template],
        }),
        200,
      ),
      _urlOf(_west): () async => http.Response.bytes(_nationaleTile(), 200),
    };
  });

  OpenFreeMapStreetShapes shapes({int tilesKept = 64}) =>
      OpenFreeMapStreetShapes(
        MockClient((request) {
          requests.add(request);
          final answer = answers[request.url];
          return answer == null
              ? Future.value(http.Response.bytes(tile([]), 200))
              : answer();
        }),
        timeout: const Duration(milliseconds: 50),
        tilesKept: tilesKept,
      );

  List<Uri> asked() => [for (final request in requests) request.url];

  test('should read where the tiles are, then the tiles of the area', () async {
    final both = GeoBounds.around([
      _at(_west, 2000, 2000),
      _at(_east, 2000, 2000),
    ])!;

    await shapes().shapeOf(name: streetName('Rue Nationale'), area: both);

    expect(asked(), [
      Uri.parse('https://tiles.openfreemap.org/planet'),
      _urlOf(_west),
      _urlOf(_east),
    ]);
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.headers['User-Agent'], appUserAgent);
    }
  });

  test('should give the roads of the street in the area', () async {
    final shape = await shapes().shapeOf(
      name: streetName('Rue Nationale'),
      area: _inside(_west),
    );

    expect(valueOf(shape), _nationaleInWest);
  });

  test('should read where the tiles are only once', () async {
    final streetShapes = shapes();
    await streetShapes.shapeOf(
      name: streetName('Rue Nationale'),
      area: _inside(_west),
    );

    await streetShapes.shapeOf(
      name: streetName('Rue Nationale'),
      area: _inside(_east),
    );

    expect(asked(), [
      OpenFreeMapStreetShapes.tileJsonUrl,
      _urlOf(_west),
      _urlOf(_east),
    ]);
  });

  test('should keep the tiles read, for the next street', () async {
    final streetShapes = shapes();
    await streetShapes.shapeOf(
      name: streetName('Rue de la Paix'),
      area: _inside(_west),
    );

    final shape = await streetShapes.shapeOf(
      name: streetName('Rue Nationale'),
      area: _inside(_west),
    );

    expect(valueOf(shape), _nationaleInWest);
    expect(asked(), [OpenFreeMapStreetShapes.tileJsonUrl, _urlOf(_west)]);
  });

  test('should forget the oldest tile beyond the tiles kept', () async {
    final streetShapes = shapes(tilesKept: 1);
    final name = streetName('Rue Nationale');
    await streetShapes.shapeOf(name: name, area: _inside(_west));
    await streetShapes.shapeOf(name: name, area: _inside(_east));
    await streetShapes.shapeOf(name: name, area: _inside(_east));

    await streetShapes.shapeOf(name: name, area: _inside(_west));

    expect(asked(), [
      OpenFreeMapStreetShapes.tileJsonUrl,
      _urlOf(_west),
      _urlOf(_east),
      _urlOf(_west),
    ]);
  });

  test('should keep two tiles when two may be kept', () async {
    final streetShapes = shapes(tilesKept: 2);
    final name = streetName('Rue Nationale');
    await streetShapes.shapeOf(name: name, area: _inside(_west));
    await streetShapes.shapeOf(name: name, area: _inside(_east));

    await streetShapes.shapeOf(name: name, area: _inside(_west));

    expect(asked(), hasLength(3));
  });

  group('the area', () {
    /// An area of [columns] tiles side by side, one row.
    GeoBounds wide(int columns) => GeoBounds.around([
      _at(_west, 2000, 2000),
      _at(TileId(zoom: 14, x: _west.x + columns - 1, y: _west.y), 2000, 2000),
    ])!;

    test('should read the 16 tiles of a large area', () async {
      await shapes().shapeOf(name: streetName('Rue Nationale'), area: wide(16));

      // The TileJSON and 16 tiles.
      expect(requests, hasLength(17));
    });

    test('should give no shape, reading nothing, for a larger '
        'area', () async {
      final shape = await shapes().shapeOf(
        name: streetName('Rue Nationale'),
        area: wide(17),
      );

      expect(valueOf(shape), StreetShape.none);
      expect(requests, isEmpty);
    });
  });

  test('should read a tile with nothing on it', () async {
    answers[_urlOf(_west)] = () async => http.Response('', 204);

    final shape = await shapes().shapeOf(
      name: streetName('Rue Nationale'),
      area: _inside(_west),
    );

    expect(valueOf(shape), StreetShape.none);
  });

  group('failures', () {
    Future<Object> failureFor(OpenFreeMapStreetShapes streetShapes) async =>
        failureOf(
          await streetShapes.shapeOf(
            name: streetName('Rue Nationale'),
            area: _inside(_west),
          ),
        );

    test('should be a service error when the TileJSON is refused', () async {
      answers[OpenFreeMapStreetShapes.tileJsonUrl] = () async =>
          http.Response('busy', 502);

      expect(await failureFor(shapes()), StreetShapesFailure.serviceError);
      expect(asked(), [OpenFreeMapStreetShapes.tileJsonUrl]);
    });

    test('should be a service error when the TileJSON is not JSON', () async {
      answers[OpenFreeMapStreetShapes.tileJsonUrl] = () async =>
          http.Response('<html>', 200);

      expect(await failureFor(shapes()), StreetShapesFailure.serviceError);
    });

    test('should be a service error when the TileJSON has no tiles', () async {
      answers[OpenFreeMapStreetShapes.tileJsonUrl] = () async =>
          http.Response('{}', 200);

      expect(await failureFor(shapes()), StreetShapesFailure.serviceError);
    });

    test('should be a service error when a tile is refused, and read the '
        'TileJSON again next time', () async {
      final streetShapes = shapes();
      answers[_urlOf(_west)] = () async => http.Response('gone', 404);
      expect(await failureFor(streetShapes), StreetShapesFailure.serviceError);

      answers[_urlOf(_west)] = () async =>
          http.Response.bytes(_nationaleTile(), 200);
      final shape = await streetShapes.shapeOf(
        name: streetName('Rue Nationale'),
        area: _inside(_west),
      );

      expect(valueOf(shape), _nationaleInWest);
      expect(asked(), [
        OpenFreeMapStreetShapes.tileJsonUrl,
        _urlOf(_west),
        OpenFreeMapStreetShapes.tileJsonUrl,
        _urlOf(_west),
      ]);
    });

    test('should be a service error when a tile is unreadable', () async {
      answers[_urlOf(_west)] = () async => http.Response.bytes([0xff], 200);

      expect(await failureFor(shapes()), StreetShapesFailure.serviceError);
    });

    test('should be no network when the server does not answer in '
        'time', () async {
      answers[OpenFreeMapStreetShapes.tileJsonUrl] = () =>
          Completer<http.Response>().future;

      expect(await failureFor(shapes()), StreetShapesFailure.noNetwork);
    });

    test('should be no network when a tile does not come', () async {
      answers[_urlOf(_west)] = () =>
          Future.error(http.ClientException('Connection closed'));

      expect(await failureFor(shapes()), StreetShapesFailure.noNetwork);
    });

    test('should be no network when the phone is offline', () async {
      answers[OpenFreeMapStreetShapes.tileJsonUrl] = () =>
          Future.error(const SocketException('Failed host lookup'));

      expect(await failureFor(shapes()), StreetShapesFailure.noNetwork);
    });
  });

  test('should read the zoom-14 tiles of the named roads', () {
    expect(OpenFreeMapStreetShapes.zoom, 14);
    expect(OpenFreeMapStreetShapes.roadsLayer, 'transportation_name');
    expect(OpenFreeMapStreetShapes.defaultTimeout, const Duration(seconds: 10));
    expect(OpenFreeMapStreetShapes.defaultTilesKept, 64);
  });
}
