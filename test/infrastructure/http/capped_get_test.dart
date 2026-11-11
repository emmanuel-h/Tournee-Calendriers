import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/http/capped_get.dart';

final _url = Uri.https('geo.api.gouv.fr', '/communes', {'nom': 'Villefranche'});

void main() {
  /// A client answering [chunks] one after the other, with [status] and
  /// without saying the length up front unless [contentLength] is given.
  /// [sent] records what was read, so a test sees the reading stop.
  http.Client streaming(
    List<List<int>> chunks, {
    int status = 200,
    int? contentLength,
    List<int>? sent,
  }) => MockClient.streaming(
    (request, body) async => http.StreamedResponse(
      Stream.fromIterable(chunks).map((chunk) {
        sent?.addAll(chunk);
        return chunk;
      }),
      status,
      contentLength: contentLength,
      headers: {'content-type': 'application/json'},
    ),
  );

  test('should send a GET with the headers to the address', () async {
    http.BaseRequest? asked;
    final client = MockClient((request) async {
      asked = request;
      return http.Response('[]', 200);
    });

    await cappedGet(
      client,
      _url,
      headers: {'User-Agent': 'Test/1.0', 'Accept': 'application/json'},
      maxBytes: 10,
    );

    expect(asked!.method, 'GET');
    expect(asked!.url, _url);
    expect(asked!.headers['User-Agent'], 'Test/1.0');
    expect(asked!.headers['Accept'], 'application/json');
  });

  test('should give the status, headers and bytes of the answer', () async {
    final response = await cappedGet(
      streaming([
        [1, 2],
        [3],
      ], status: 404),
      _url,
      headers: const {},
      maxBytes: 10,
    );

    expect(response.statusCode, 404);
    expect(response.bodyBytes, [1, 2, 3]);
    expect(response.headers['content-type'], 'application/json');
  });

  test('should accept an answer exactly as long as allowed', () async {
    final response = await cappedGet(
      streaming([
        [1, 2],
        [3, 4],
      ]),
      _url,
      headers: const {},
      maxBytes: 4,
    );

    expect(response.bodyBytes, [1, 2, 3, 4]);
  });

  test('should refuse an answer longer than allowed, and stop reading '
      'it', () async {
    final sent = <int>[];

    await expectLater(
      cappedGet(
        streaming([
          [1, 2],
          [3, 4, 5],
          [6],
        ], sent: sent),
        _url,
        headers: const {},
        maxBytes: 4,
      ),
      throwsA(isA<ResponseTooLarge>()),
    );
    expect(sent, [1, 2, 3, 4, 5]);
  });

  test('should refuse an answer announced longer than allowed, before '
      'reading it', () async {
    final sent = <int>[];

    await expectLater(
      cappedGet(
        streaming(
          [
            [1, 2, 3, 4, 5],
          ],
          contentLength: 5,
          sent: sent,
        ),
        _url,
        headers: const {},
        maxBytes: 4,
      ),
      throwsA(isA<ResponseTooLarge>()),
    );
    expect(sent, isEmpty);
  });

  test('should read an answer announced exactly as long as allowed', () async {
    final response = await cappedGet(
      streaming([
        [1, 2, 3, 4],
      ], contentLength: 4),
      _url,
      headers: const {},
      maxBytes: 4,
    );

    expect(response.bodyBytes, [1, 2, 3, 4]);
  });

  test('should pass on an error of the connection mid-answer', () async {
    final client = MockClient.streaming(
      (request, body) async => http.StreamedResponse(
        Stream<List<int>>.error(http.ClientException('Connection closed')),
        200,
      ),
    );

    await expectLater(
      cappedGet(client, _url, headers: const {}, maxBytes: 4),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('should name the address in the refusal', () {
    expect(ResponseTooLarge(_url).toString(), contains('geo.api.gouv.fr'));
  });
}
