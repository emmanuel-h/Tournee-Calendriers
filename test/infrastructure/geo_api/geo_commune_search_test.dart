import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geo_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'geo_api_fixtures.dart';

void main() {
  // A response carrying [text] as UTF-8 bytes, like the real service.
  http.Response bytes(String text, int status) => http.Response.bytes(
    utf8.encode(text),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  GeoCommuneSearch searchAnswering(
    Future<http.Response> Function() answer, {
    List<http.Request>? requests,
    Duration timeout = const Duration(seconds: 10),
  }) => GeoCommuneSearch(
    MockClient((request) {
      requests?.add(request);
      return answer();
    }),
    timeout: timeout,
  );

  test('should ask geo.api.gouv.fr for five communes by name', () async {
    final requests = <http.Request>[];
    final search = searchAnswering(
      () async => bytes(geoApiFixtureText('communes_villefranche.json'), 200),
      requests: requests,
    );

    await search.search('Villefranche sur');

    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(
      requests.single.url,
      Uri.parse(
        'https://geo.api.gouv.fr/communes?nom=Villefranche+sur'
        '&fields=nom%2Ccode%2CcodesPostaux&boost=population&limit=5',
      ),
    );
    expect(requests.single.headers['User-Agent'], appUserAgent);
    expect(requests.single.headers['Accept'], 'application/json');
  });

  test('should give the communes found, accents read as UTF-8', () async {
    final search = searchAnswering(
      () async => http.Response.bytes(
        utf8.encode(geoApiFixtureText('communes_villefranche.json')),
        200,
      ),
    );

    expect(valueOf(await search.search('Villefranche')), [
      CommuneMatch(commune: villefranche, postcodes: const ['69400']),
    ]);
  });

  test('should give no commune when the service finds none', () async {
    final search = searchAnswering(
      () async => bytes(geoApiFixtureText('communes_none.json'), 200),
    );

    expect(valueOf(await search.search('zzzzqx')), isEmpty);
  });

  group('failures', () {
    final cases = <String, (Future<http.Response> Function(), Object)>{
      'a status other than 200': (
        () async => bytes('[]', 500),
        CommuneSearchFailure.serviceError,
      ),
      'a 404': (
        () async => bytes('[]', 404),
        CommuneSearchFailure.serviceError,
      ),
      'a body that is not JSON': (
        () async => bytes('<html>', 200),
        CommuneSearchFailure.serviceError,
      ),
      'a body that is not UTF-8': (
        () async => http.Response.bytes([0xff, 0xfe], 200),
        CommuneSearchFailure.serviceError,
      ),
      'a document that is not a list': (
        () async => bytes('{"nom":"x"}', 200),
        CommuneSearchFailure.serviceError,
      ),
      'a refused connection': (
        () async => throw http.ClientException('Connection refused'),
        CommuneSearchFailure.noNetwork,
      ),
      'a socket error': (
        () async => throw const SocketException('Network is unreachable'),
        CommuneSearchFailure.noNetwork,
      ),
    };
    cases.forEach((name, test_) {
      final (answer, failure) = test_;
      test('should fail with $failure when given $name', () async {
        expect(failureOf(await searchAnswering(answer).search('Vi')), failure);
      });
    });

    test('should fail with no network when no answer comes in time', () async {
      // A future that never completes: only the timeout can end the call.
      final search = searchAnswering(
        () => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 1),
      );

      expect(
        failureOf(await search.search('Vi')),
        CommuneSearchFailure.noNetwork,
      );
    });
  });

  test('should wait ten seconds by default', () {
    expect(
      GeoCommuneSearch(MockClient((_) async => bytes('[]', 200))).timeout,
      const Duration(seconds: 10),
    );
  });
}
