import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geopf_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../ban/ban_fixtures.dart';

/// An answer finding no commune, in ASCII: as many bytes as characters.
const _noFeature = '{"features":[]}';

void main() {
  // A response carrying [text] as UTF-8 bytes, like the real service.
  http.Response bytes(String text, int status) => http.Response.bytes(
    utf8.encode(text),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  GeopfCommuneSearch searchAnswering(
    Future<http.Response> Function() answer, {
    List<http.Request>? requests,
    Duration timeout = const Duration(seconds: 10),
    int maxAnswerBytes = GeopfCommuneSearch.defaultMaxAnswerBytes,
  }) => GeopfCommuneSearch(
    MockClient((request) {
      requests?.add(request);
      return answer();
    }),
    timeout: timeout,
    maxAnswerBytes: maxAnswerBytes,
  );

  test('should ask the Géoplateforme geocoder for five communes', () async {
    final requests = <http.Request>[];
    final search = searchAnswering(
      () async =>
          bytes(geopfFixtureText('municipality_villefranche.json'), 200),
      requests: requests,
    );

    await search.search('Villefranche sur');

    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(
      requests.single.url,
      Uri.parse(
        'https://data.geopf.fr/geocodage/search?q=Villefranche+sur'
        '&type=municipality&limit=5',
      ),
    );
    expect(requests.single.headers['User-Agent'], appUserAgent);
    expect(requests.single.headers['Accept'], 'application/json');
  });

  test('should give the communes found, accents read as UTF-8', () async {
    final search = searchAnswering(
      () async => http.Response.bytes(
        utf8.encode(geopfFixtureText('municipality_villefranche.json')),
        200,
      ),
    );

    expect(valueOf(await search.search('Villefranche')), [
      CommuneMatch(
        commune: villefranche,
        postcodes: const ['69400'],
        centre: at(45.985089, 4.724382),
      ),
    ]);
  });

  test('should give no commune when the service finds none', () async {
    final search = searchAnswering(
      () async => bytes(geopfFixtureText('municipality_none.json'), 200),
    );

    expect(valueOf(await search.search('zzzzqx')), isEmpty);
  });

  group('failures', () {
    final cases = <String, (Future<http.Response> Function(), Object)>{
      // The geocoder refuses fewer than three characters.
      'a refused query': (
        () async => bytes(geopfFixtureText('search_too_short.json'), 400),
        CommuneSearchFailure.serviceError,
      ),
      'a document that is not a feature collection': (
        () async => bytes('[]', 200),
        CommuneSearchFailure.serviceError,
      ),
      'a body that is not JSON': (
        () async => bytes('<html>', 200),
        CommuneSearchFailure.serviceError,
      ),
      'a refused connection': (
        () async => throw const SocketException(
          'Connection refused',
          osError: OSError('Connection refused', 111),
        ),
        CommuneSearchFailure.serviceError,
      ),
      'a failed host lookup': (
        () async =>
            throw const SocketException("Failed host lookup: 'data.geopf.fr'"),
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
      final search = searchAnswering(
        () => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 1),
      );

      expect(
        failureOf(await search.search('Vil')),
        CommuneSearchFailure.noNetwork,
      );
    });
  });

  test('should wait ten seconds by default', () {
    expect(
      GeopfCommuneSearch(MockClient((_) async => bytes('{}', 200))).timeout,
      const Duration(seconds: 10),
    );
  });

  test('should read an answer exactly as long as allowed', () async {
    final search = searchAnswering(
      () async => bytes(_noFeature, 200),
      maxAnswerBytes: _noFeature.length,
    );

    expect(valueOf(await search.search('Villefranche')), isEmpty);
  });

  test('should fail with a service error when the answer is longer than '
      'allowed', () async {
    final search = searchAnswering(
      () async => bytes('$_noFeature ', 200),
      maxAnswerBytes: _noFeature.length,
    );

    expect(
      failureOf(await search.search('Villefranche')),
      CommuneSearchFailure.serviceError,
    );
  });

  test('should read answers of up to 1 MB by default', () {
    expect(
      GeopfCommuneSearch(MockClient((_) async => bytes('{}', 200)))
          .maxAnswerBytes,
      1 << 20,
    );
  });
}
