import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';
import 'package:tournee_calendriers/infrastructure/overpass/mappers/overpass_mapper.dart';
import 'package:tournee_calendriers/infrastructure/overpass/overpass_street_shapes.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'overpass_fixtures.dart';

void main() {
  final freresBonnet = valueOf(StreetName.create('Rue des Freres Bonnet'));

  // A response carrying the [fixture] as UTF-8 bytes, like the real
  // service (which gives no charset).
  http.Response fixtureResponse(String fixture, int status) =>
      http.Response.bytes(
        utf8.encode(overpassFixtureText(fixture)),
        status,
        headers: {'content-type': 'application/json'},
      );

  // Street shapes whose HTTP client always answers [answer], and which keep
  // every request sent in [requests].
  OverpassStreetShapes shapesAnswering(
    Future<http.Response> Function() answer, {
    List<http.Request>? requests,
    Duration timeout = const Duration(seconds: 10),
  }) => OverpassStreetShapes(
    MockClient((request) {
      requests?.add(request);
      return answer();
    }),
    timeout: timeout,
  );

  Future<Object> failureFrom(OverpassStreetShapes shapes) async => failureOf(
    await shapes.shapeOf(name: freresBonnet, commune: insee('69264')),
  );

  test('should post the query for the street to Overpass', () async {
    final requests = <http.Request>[];
    final shapes = shapesAnswering(
      () async => fixtureResponse('rue_des_freres_bonnet.json', 200),
      requests: requests,
    );

    await shapes.shapeOf(name: freresBonnet, commune: insee('69264'));

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(
      requests.single.url,
      Uri.parse('https://overpass-api.de/api/interpreter'),
    );
    expect(requests.single.bodyFields, {
      'data': overpassStreetQuery(freresBonnet, insee('69264')),
    });
    expect(requests.single.headers['User-Agent'], appUserAgent);
    expect(requests.single.headers['Accept'], 'application/json');
  });

  test('should return the roads of the street', () async {
    final shapes = shapesAnswering(
      () async => fixtureResponse('rue_des_freres_bonnet.json', 200),
    );

    final shape = valueOf(
      await shapes.shapeOf(name: freresBonnet, commune: insee('69264')),
    );

    expect(shape.lines, hasLength(3));
    expect(shape.lines.first.first, at(45.9885563, 4.7392065));
    expect(shape.lines.last.last, at(45.9891127, 4.7429775));
  });

  test('should return no shape when no road has the name', () async {
    final shapes = shapesAnswering(
      () async => fixtureResponse('no_way.json', 200),
    );

    expect(
      valueOf(
        await shapes.shapeOf(name: freresBonnet, commune: insee('69264')),
      ),
      StreetShape.none,
    );
  });

  test('should wait a little longer than the server works', () {
    final shapes = OverpassStreetShapes(
      MockClient((request) async => http.Response('{}', 200)),
    );

    expect(shapes.timeout, const Duration(seconds: 20));
    expect(
      shapes.timeout,
      greaterThan(const Duration(seconds: overpassTimeoutSeconds)),
    );
  });

  group('should fail with a service error', () {
    test('when the server stopped on a runtime error', () async {
      final shapes = shapesAnswering(
        () async => fixtureResponse('runtime_error.json', 200),
      );

      expect(await failureFrom(shapes), StreetShapesFailure.serviceError);
    });

    test('when the server is down', () async {
      final shapes = shapesAnswering(
        () async => http.Response.bytes(
          utf8.encode(overpassFixtureText('dispatcher_off.html')),
          504,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );

      expect(await failureFrom(shapes), StreetShapesFailure.serviceError);
    });

    for (final status in [201, 204, 400, 404, 429, 500, 502, 503]) {
      test('when the status is $status', () async {
        final shapes = shapesAnswering(
          () async => http.Response('{"elements": []}', status),
        );

        expect(await failureFrom(shapes), StreetShapesFailure.serviceError);
      });
    }

    test('when the body is not JSON', () async {
      final shapes = shapesAnswering(
        () async => http.Response('<html>Bad gateway</html>', 200),
      );

      expect(await failureFrom(shapes), StreetShapesFailure.serviceError);
    });

    test('when the body is not UTF-8', () async {
      final shapes = shapesAnswering(
        () async => http.Response.bytes([0x7B, 0xFF, 0xFE, 0x7D], 200),
      );

      expect(await failureFrom(shapes), StreetShapesFailure.serviceError);
    });
  });

  group('should fail with no network', () {
    test('when the connection fails', () async {
      final shapes = shapesAnswering(
        () async => throw http.ClientException('Connection refused'),
      );

      expect(await failureFrom(shapes), StreetShapesFailure.noNetwork);
    });

    test('when the socket fails', () async {
      final shapes = shapesAnswering(
        () async => throw const SocketException('Network is unreachable'),
      );

      expect(await failureFrom(shapes), StreetShapesFailure.noNetwork);
    });

    test('when the TLS handshake fails', () async {
      final shapes = shapesAnswering(
        () async => throw const HandshakeException('Connection reset'),
      );

      expect(await failureFrom(shapes), StreetShapesFailure.noNetwork);
    });

    test('when no answer comes in time', () async {
      // A future that never completes: only the timeout can end the call,
      // set to 1 ms so the test stays fast without a fake clock.
      final shapes = shapesAnswering(
        () => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 1),
      );

      expect(await failureFrom(shapes), StreetShapesFailure.noNetwork);
    });
  });
}
