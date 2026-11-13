import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/geometry/join_lines.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/geopf/ign_street_shapes.dart';
import 'package:tournee_calendriers/infrastructure/geopf/mappers/bdtopo_roads_mapper.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/roads_by_name.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'bdtopo_fixtures.dart';

/// The map's roads by name, as the test sets them, recording each call.
final class _FakeRoadsByName implements RoadsByName {
  Result<StreetShape, StreetShapesFailure> shape = const Ok(StreetShape.none);
  Result<List<NamedRoad>, StreetShapesFailure> roads = const Ok([]);
  final shapesAsked = <(String, GeoBounds)>[];
  final roadsAsked = <GeoBounds>[];

  @override
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required StreetName name,
    required GeoBounds area,
  }) async {
    shapesAsked.add((name.text, area));
    return shape;
  }

  @override
  Future<Result<List<NamedRoad>, StreetShapesFailure>> roadsIn(
    GeoBounds area,
  ) async {
    roadsAsked.add(area);
    return roads;
  }
}

/// The houses of Rue Nationale, about: where its line is looked for.
final _nationaleArea = GeoBounds.of(
  south: 45.9890,
  west: 4.7170,
  north: 45.9960,
  east: 4.7200,
)!;

/// The centre of Villefranche: the zone of `zone_centre.json`.
final _centre = GeoBounds.of(
  south: 45.9900,
  west: 4.7160,
  north: 45.9925,
  east: 4.7195,
)!;

final _nationaleId = BanStreetId('69264_1270');

/// A road of the map, for the fallback.
final _mapRoad = StreetShape([
  [at(45.9900, 4.7180), at(45.9910, 4.7180)],
]);

void main() {
  late _FakeRoadsByName byName;
  late List<http.Request> requests;

  setUp(() {
    byName = _FakeRoadsByName();
    requests = [];
  });

  // A response carrying [text] as UTF-8 bytes, like the real service.
  http.Response answer(String text, [int status = 200]) => http.Response.bytes(
    utf8.encode(text),
    status,
    headers: {'content-type': 'application/json;charset=UTF-8'},
  );

  // Shapes whose HTTP client always answers [respond], keeping every
  // request it sent in `requests`.
  IgnStreetShapes shapesAnswering(
    Future<http.Response> Function() respond, {
    Duration timeout = const Duration(seconds: 10),
    int maxAnswerBytes = IgnStreetShapes.defaultMaxAnswerBytes,
  }) => IgnStreetShapes(
    MockClient((request) {
      requests.add(request);
      return respond();
    }),
    byName: byName,
    timeout: timeout,
    maxAnswerBytes: maxAnswerBytes,
  );

  IgnStreetShapes shapesWith(String fixture) =>
      shapesAnswering(() async => answer(bdTopoFixtureText(fixture)));

  Future<Result<StreetShape, StreetShapesFailure>> nationaleOf(
    IgnStreetShapes shapes,
  ) => shapes.shapeOf(
    banId: _nationaleId,
    name: streetName('Rue Nationale'),
    area: _nationaleArea,
  );

  /// The query of the only request sent.
  Map<String, String> sentQuery() => requests.single.url.queryParameters;

  group('shapeOf', () {
    test('should ask BD TOPO for the stretches of the BAN id near the '
        'houses', () async {
      await nationaleOf(shapesWith('by_id_rue_nationale.json'));

      final url = requests.single.url;
      expect(requests.single.method, 'GET');
      expect(
        '${url.scheme}://${url.host}${url.path}',
        'https://data.geopf.fr/wfs/ows',
      );
      final searched = _nationaleArea.expandedBy(
        IgnStreetShapes.idSearchMarginMetres,
      );
      String degrees(double value) => value.toStringAsFixed(7);
      expect(sentQuery(), {
        'SERVICE': 'WFS',
        'VERSION': '2.0.0',
        'REQUEST': 'GetFeature',
        'TYPENAMES': 'BDTOPO_V3:troncon_de_route',
        'OUTPUTFORMAT': 'application/json',
        'SRSNAME': 'EPSG:4326',
        'PROPERTYNAME':
            'identifiant_voie_ban_gauche,identifiant_voie_ban_droite,'
            'nom_voie_ban_gauche,nom_voie_ban_droite,'
            'insee_commune_gauche,insee_commune_droite,'
            'nom_collaboratif_gauche,nom_collaboratif_droite,geometrie',
        'COUNT': '1000',
        'CQL_FILTER':
            'BBOX(geometrie,${degrees(searched.south)},'
            '${degrees(searched.west)},${degrees(searched.north)},'
            "${degrees(searched.east)},'urn:ogc:def:crs:EPSG::4326') AND "
            "(identifiant_voie_ban_gauche='69264_1270' OR "
            "identifiant_voie_ban_droite='69264_1270')",
      });
      expect(requests.single.headers['User-Agent'], appUserAgent);
      expect(requests.single.headers['Accept'], 'application/json');
    });

    test('should look 2 km around the houses', () {
      expect(IgnStreetShapes.idSearchMarginMetres, 2000);
    });

    test('should give the stretches of the street joined, not '
        'simplified', () async {
      final shape = valueOf(
        await nationaleOf(shapesWith('by_id_rue_nationale.json')),
      );

      final stretches = banRoadsFromJson(
        bdTopoFixture('by_id_rue_nationale.json'),
      ).roads;
      expect(
        shape,
        StreetShape(
          joinLines([
            for (final road in stretches) ...road.shape.lines,
          ], toleranceMetres: IgnStreetShapes.joinToleranceMetres),
        ),
      );
      // 26 stretches end to end make far fewer lines.
      expect(shape.lines.length, lessThan(stretches.length));
      expect(shape.points.length, greaterThan(shape.lines.length * 2));
      expect(byName.shapesAsked, isEmpty);
    });

    test('should join stretches whose ends are 1 m apart', () {
      expect(IgnStreetShapes.joinToleranceMetres, 1.0);
    });

    test('should keep only the stretches carrying the BAN id', () async {
      final shapes = shapesAnswering(
        () async => answer(
          jsonEncode({
            'type': 'FeatureCollection',
            'numberMatched': 2,
            'features': [
              for (final (id, longitude) in [
                ('69264_0290', 4.7180),
                ('69264_1270', 4.7190),
              ])
                {
                  'type': 'Feature',
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': [
                      [longitude, 45.9930],
                      [longitude, 45.9940],
                    ],
                  },
                  'properties': {
                    'identifiant_voie_ban_gauche': '69264_0290',
                    'identifiant_voie_ban_droite': id,
                    'nom_voie_ban_gauche': 'Rue Caroline Blondeau',
                    'nom_voie_ban_droite': 'Rue Nationale',
                    'insee_commune_gauche': '69264',
                    'insee_commune_droite': '69264',
                  },
                },
            ],
          }),
        ),
      );

      expect(
        valueOf(await nationaleOf(shapes)),
        StreetShape([
          [at(45.9930, 4.7190), at(45.9940, 4.7190)],
        ]),
      );
    });

    test('should double a quote in the BAN id', () async {
      await shapesWith('by_id_none.json').shapeOf(
        banId: BanStreetId("69264_l'a"),
        name: streetName('Rue Nationale'),
        area: _nationaleArea,
      );

      expect(
        sentQuery()['CQL_FILTER'],
        endsWith(
          "(identifiant_voie_ban_gauche='69264_l''a' OR "
          "identifiant_voie_ban_droite='69264_l''a')",
        ),
      );
    });

    test('should ask the map by name when BD TOPO has no stretch of the '
        'street', () async {
      byName.shape = Ok(_mapRoad);

      final shape = await nationaleOf(shapesWith('by_id_none.json'));

      expect(valueOf(shape), _mapRoad);
      expect(byName.shapesAsked, [('Rue Nationale', _nationaleArea)]);
    });

    test("should give the map's failure when BD TOPO has nothing and the "
        'map cannot answer', () async {
      byName.shape = const Err(StreetShapesFailure.noNetwork);

      expect(
        failureOf(await nationaleOf(shapesWith('by_id_none.json'))),
        StreetShapesFailure.noNetwork,
      );
    });

    test('should ask only the map by name for a street without BAN '
        'id', () async {
      byName.shape = Ok(_mapRoad);
      final shapes = shapesWith('by_id_rue_nationale.json');

      final shape = await shapes.shapeOf(
        banId: null,
        name: streetName('Rue Nationale'),
        area: _nationaleArea,
      );

      expect(valueOf(shape), _mapRoad);
      expect(requests, isEmpty);
      expect(byName.shapesAsked, [('Rue Nationale', _nationaleArea)]);
    });

    test('should fail without asking the map when BD TOPO cannot '
        'answer', () async {
      final shapes = shapesAnswering(() async => answer('', 503));

      expect(
        failureOf(await nationaleOf(shapes)),
        StreetShapesFailure.serviceError,
      );
      expect(byName.shapesAsked, isEmpty);
    });
  });

  group('roadsIn', () {
    test('should ask BD TOPO for the stretches in the area, latitude '
        'first', () async {
      await shapesWith('zone_centre.json').roadsIn(_centre);

      final query = sentQuery();
      expect(
        query['BBOX'],
        '45.9900000,4.7160000,45.9925000,4.7195000,'
        'urn:ogc:def:crs:EPSG::4326',
      );
      expect(query['COUNT'], '1000');
      expect(query['TYPENAMES'], 'BDTOPO_V3:troncon_de_route');
      expect(query['OUTPUTFORMAT'], 'application/json');
      expect(query['SRSNAME'], 'EPSG:4326');
      expect(query['PROPERTYNAME'], startsWith('identifiant_voie_ban_gauche,'));
      expect(query.containsKey('CQL_FILTER'), isFalse);
      expect(requests.single.headers['User-Agent'], appUserAgent);
    });

    test('should give every road read from the answer', () async {
      final roads = valueOf(
        await shapesWith('zone_centre.json').roadsIn(_centre),
      );

      expect(roads, banRoadsFromJson(bdTopoFixture('zone_centre.json')).roads);
      expect(roads, hasLength(35));
    });

    test('should be too large when the area holds more than 1000 '
        'stretches', () async {
      expect(IgnStreetShapes.maxStretches, 1000);
      expect(
        failureOf(await shapesWith('zone_too_many.json').roadsIn(_centre)),
        StreetShapesFailure.tooLarge,
      );
    });

    Future<Result<List<BanRoad>, StreetShapesFailure>> roadsWithMatched(
      int matched,
    ) => shapesAnswering(
      () async => answer(
        jsonEncode({
          'type': 'FeatureCollection',
          'numberMatched': matched,
          'features': <Object?>[],
        }),
      ),
    ).roadsIn(_centre);

    test('should read an area of exactly 1000 stretches', () async {
      expect(valueOf(await roadsWithMatched(1000)), isEmpty);
    });

    test('should be too large at 1001 stretches', () async {
      expect(
        failureOf(await roadsWithMatched(1001)),
        StreetShapesFailure.tooLarge,
      );
    });
  });

  group('namedRoadsIn', () {
    test("should give the map's named roads, without asking BD "
        'TOPO', () async {
      final roads = [NamedRoad(name: 'Rue Nationale', shape: _mapRoad)];
      byName.roads = Ok(roads);

      final named = await shapesWith('zone_centre.json').namedRoadsIn(_centre);

      expect(valueOf(named), roads);
      expect(byName.roadsAsked, [_centre]);
      expect(requests, isEmpty);
    });
  });

  group('failures', () {
    Future<StreetShapesFailure> failureFor(IgnStreetShapes shapes) async =>
        failureOf(await shapes.roadsIn(_centre));

    test('should be a service error on any status but 200', () async {
      for (final status in [204, 400, 404, 500]) {
        expect(
          await failureFor(
            shapesAnswering(
              () async => answer(bdTopoFixtureText('zone_centre.json'), status),
            ),
          ),
          StreetShapesFailure.serviceError,
          reason: 'status $status',
        );
      }
    });

    test('should be a service error when the answer is not JSON', () async {
      // What the WFS sends for a filter it refuses.
      expect(
        await failureFor(
          shapesAnswering(() async => answer('<ows:ExceptionReport/>')),
        ),
        StreetShapesFailure.serviceError,
      );
    });

    test('should be a service error when the answer is not UTF-8', () async {
      expect(
        await failureFor(
          shapesAnswering(() async => http.Response.bytes([0xff, 0xfe], 200)),
        ),
        StreetShapesFailure.serviceError,
      );
    });

    test('should be a service error when the answer is not a collection of '
        'stretches', () async {
      expect(
        await failureFor(shapesAnswering(() async => answer('[]'))),
        StreetShapesFailure.serviceError,
      );
    });

    test('should be a service error when the answer is longer than '
        'allowed', () async {
      final text = bdTopoFixtureText('zone_centre.json');
      final length = utf8.encode(text).length;

      expect(
        await failureFor(
          shapesAnswering(() async => answer(text), maxAnswerBytes: length - 1),
        ),
        StreetShapesFailure.serviceError,
      );
      expect(
        valueOf(
          await shapesAnswering(
            () async => answer(text),
            maxAnswerBytes: length,
          ).roadsIn(_centre),
        ),
        hasLength(35),
      );
    });

    test('should be no network when the service does not answer in '
        'time', () async {
      expect(
        await failureFor(
          shapesAnswering(
            () => Completer<http.Response>().future,
            timeout: const Duration(milliseconds: 1),
          ),
        ),
        StreetShapesFailure.noNetwork,
      );
    });

    test('should be no network when the phone is offline', () async {
      expect(
        await failureFor(
          shapesAnswering(
            () => Future.error(const SocketException('Failed host lookup')),
          ),
        ),
        StreetShapesFailure.noNetwork,
      );
    });

    test('should be no network when the network is unreachable', () async {
      expect(
        await failureFor(
          shapesAnswering(
            () => Future.error(
              const SocketException(
                'Connection failed',
                osError: OSError('Network is unreachable', 101),
              ),
            ),
          ),
        ),
        StreetShapesFailure.noNetwork,
      );
    });

    test('should be a service error when the connection is cut', () async {
      // The connection worked, so the phone has a network (#137).
      expect(
        await failureFor(
          shapesAnswering(
            () => Future.error(http.ClientException('Connection closed')),
          ),
        ),
        StreetShapesFailure.serviceError,
      );
    });

    test('should be a service error when the connection is refused', () async {
      expect(
        await failureFor(
          shapesAnswering(
            () => Future.error(
              const SocketException(
                'Connection refused',
                osError: OSError('Connection refused', 111),
              ),
            ),
          ),
        ),
        StreetShapesFailure.serviceError,
      );
    });
  });

  test('should wait 15 s and read 8 MB at most by default, like the BAN', () {
    expect(IgnStreetShapes.defaultTimeout, const Duration(seconds: 15));
    expect(IgnStreetShapes.defaultMaxAnswerBytes, 8 << 20);
    final shapes = IgnStreetShapes(
      MockClient((_) async => http.Response('', 200)),
      byName: _FakeRoadsByName(),
    );
    expect(shapes.timeout, IgnStreetShapes.defaultTimeout);
    expect(shapes.maxAnswerBytes, IgnStreetShapes.defaultMaxAnswerBytes);
  });
}
