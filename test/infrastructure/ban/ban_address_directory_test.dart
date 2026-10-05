import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/infrastructure/ban/ban_address_directory.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'ban_fixtures.dart';

void main() {
  final villefranche = valueOf(
    Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
  );

  // A response carrying [fixture] as UTF-8 bytes, like the real service.
  http.Response fixtureResponse(String fixture, int status) =>
      http.Response.bytes(
        utf8.encode(banFixtureText(fixture)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  // A directory whose HTTP client always answers [answer], and which keeps
  // every request it sent in [requests].
  BanAddressDirectory directoryAnswering(
    Future<http.Response> Function() answer, {
    List<http.Request>? requests,
    Duration timeout = const Duration(seconds: 10),
  }) => BanAddressDirectory(
    MockClient((request) {
      requests?.add(request);
      return answer();
    }),
    timeout: timeout,
  );

  group('streetsOf', () {
    test('should ask the BAN lookup for the commune code', () async {
      final requests = <http.Request>[];
      final directory = directoryAnswering(
        () async => fixtureResponse('lookup_69264.json', 200),
        requests: requests,
      );

      await directory.streetsOf(insee('69264'));

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(
        requests.single.url,
        Uri.parse('https://plateforme.adresse.data.gouv.fr/lookup/69264'),
      );
      expect(
        requests.single.headers['User-Agent'],
        BanAddressDirectory.userAgent,
      );
      expect(requests.single.headers['Accept'], 'application/json');
    });

    test('should name the app and how to reach it in the User-Agent', () {
      expect(
        BanAddressDirectory.userAgent,
        'TourneeCalendriers/1.0 '
        '(+https://github.com/emmanuel-h/Tournee-Calendriers)',
      );
    });

    test('should return the streets of the commune when found', () async {
      final directory = directoryAnswering(
        () async => fixtureResponse('lookup_69264.json', 200),
      );

      final streets = valueOf(await directory.streetsOf(insee('69264')));

      expect(streets.commune, villefranche);
      expect(streets.streets, hasLength(6));
      expect(
        streets.streets.first,
        DirectoryStreet(
          id: BanStreetId('69264_1460'),
          name: valueOf(StreetName.create('Rue Pierre Morin')),
          numberCount: 19,
        ),
      );
      expect(streets.skippedStreets, 0);
    });

    test(
      'should fail with not found when the BAN knows no such commune',
      () async {
        final directory = directoryAnswering(
          () async => fixtureResponse('lookup_unknown_commune.json', 404),
        );

        expect(
          failureOf(await directory.streetsOf(insee('69999'))),
          AddressDirectoryFailure.notFound,
        );
      },
    );

    test(
      'should fail with a service error when given a street document',
      () async {
        final directory = directoryAnswering(
          () async => fixtureResponse('lookup_69264_0246.json', 200),
        );

        expect(
          failureOf(await directory.streetsOf(insee('69264'))),
          AddressDirectoryFailure.serviceError,
        );
      },
    );
  });

  group('numbersOf', () {
    test('should ask the BAN lookup for the street id', () async {
      final requests = <http.Request>[];
      final directory = directoryAnswering(
        () async => fixtureResponse('lookup_69264_0246.json', 200),
        requests: requests,
      );

      await directory.numbersOf(BanStreetId('69264_0246'));

      expect(requests.single.method, 'GET');
      expect(
        requests.single.url,
        Uri.parse('https://plateforme.adresse.data.gouv.fr/lookup/69264_0246'),
      );
      expect(
        requests.single.headers['User-Agent'],
        BanAddressDirectory.userAgent,
      );
      expect(requests.single.headers['Accept'], 'application/json');
    });

    test('should return the numbers of the street when found', () async {
      final directory = directoryAnswering(
        () async => fixtureResponse('lookup_69264_0246.json', 200),
      );

      final numbers = valueOf(
        await directory.numbersOf(BanStreetId('69264_0246')),
      );

      expect(numbers.id, BanStreetId('69264_0246'));
      expect(
        numbers.name,
        valueOf(StreetName.create('Petit Chemin de Bordelan')),
      );
      expect(numbers.commune, villefranche);
      expect(numbers.numbers, hasLength(13));
      expect(
        numbers.numbers.first,
        DirectoryNumber(
          number: HouseNumber.plain(89),
          position: valueOf(
            GeoPoint.create(latitude: 45.974052, longitude: 4.744337),
          ),
        ),
      );
      expect(numbers.duplicateNumbers, 1);
      expect(numbers.invalidNumbers, 0);
    });

    test('should return an empty street when the BAN has no number', () async {
      final directory = directoryAnswering(
        () async => fixtureResponse('lookup_69264_1781_no_numbers.json', 200),
      );

      final numbers = valueOf(
        await directory.numbersOf(BanStreetId('69264_1781')),
      );

      expect(numbers.name, valueOf(StreetName.create('Allée du Square')));
      expect(numbers.numbers, isEmpty);
    });

    test('should read the body as UTF-8 when no charset is given', () async {
      // Without a charset, `Response.body` would decode Latin-1 and turn
      // « Allée » into « AllÃ©e ».
      final directory = directoryAnswering(
        () async => http.Response.bytes(
          utf8.encode(banFixtureText('lookup_69264_1781_no_numbers.json')),
          200,
        ),
      );

      final numbers = valueOf(
        await directory.numbersOf(BanStreetId('69264_1781')),
      );

      expect(numbers.name.text, 'Allée du Square');
    });

    test(
      'should fail with not found when the BAN knows no such street',
      () async {
        final directory = directoryAnswering(
          () async => fixtureResponse('lookup_unknown_street.json', 404),
        );

        expect(
          failureOf(await directory.numbersOf(BanStreetId('69264_zzzz'))),
          AddressDirectoryFailure.notFound,
        );
      },
    );

    test(
      'should fail with a service error when given a commune document',
      () async {
        final directory = directoryAnswering(
          () async => fixtureResponse('lookup_69264.json', 200),
        );

        expect(
          failureOf(await directory.numbersOf(BanStreetId('69264'))),
          AddressDirectoryFailure.serviceError,
        );
      },
    );
  });

  // The same transport rules for both calls: each case is run on both.
  final calls =
      <String, Future<Object> Function(BanAddressDirectory directory)>{
        'streetsOf': (directory) async =>
            failureOf(await directory.streetsOf(insee('69264'))),
        'numbersOf': (directory) async =>
            failureOf(await directory.numbersOf(BanStreetId('69264_0246'))),
      };

  calls.forEach((name, failureFrom) {
    group('$name transport', () {
      for (final status in [201, 204, 301, 400, 403, 429, 500, 503]) {
        test(
          'should fail with a service error when the status is $status',
          () async {
            final directory = directoryAnswering(
              () async => http.Response('{}', status),
            );

            expect(
              await failureFrom(directory),
              AddressDirectoryFailure.serviceError,
            );
          },
        );
      }

      test(
        'should fail with a service error when the body is not JSON',
        () async {
          final directory = directoryAnswering(
            () async => http.Response('<html>Bad gateway</html>', 200),
          );

          expect(
            await failureFrom(directory),
            AddressDirectoryFailure.serviceError,
          );
        },
      );

      test(
        'should fail with a service error when the body is not UTF-8',
        () async {
          final directory = directoryAnswering(
            () async => http.Response.bytes([0x7B, 0xFF, 0xFE, 0x7D], 200),
          );

          expect(
            await failureFrom(directory),
            AddressDirectoryFailure.serviceError,
          );
        },
      );

      test('should fail with no network when the connection fails', () async {
        final directory = directoryAnswering(
          () async => throw http.ClientException('Connection refused'),
        );

        expect(await failureFrom(directory), AddressDirectoryFailure.noNetwork);
      });

      test('should fail with no network when the socket fails', () async {
        final directory = directoryAnswering(
          () async => throw const SocketException('Network is unreachable'),
        );

        expect(await failureFrom(directory), AddressDirectoryFailure.noNetwork);
      });

      test(
        'should fail with no network when the TLS handshake fails',
        () async {
          final directory = directoryAnswering(
            () async => throw const HandshakeException('Connection reset'),
          );

          expect(
            await failureFrom(directory),
            AddressDirectoryFailure.noNetwork,
          );
        },
      );

      test(
        'should fail with no network when no answer comes in time',
        () async {
          // A future that never completes: only the timeout can end the call.
          // The timeout is 1 ms so the test stays fast without a fake clock.
          final directory = directoryAnswering(
            () => Completer<http.Response>().future,
            timeout: const Duration(milliseconds: 1),
          );

          expect(
            await failureFrom(directory),
            AddressDirectoryFailure.noNetwork,
          );
        },
      );
    });
  });

  test('should wait 15 seconds for an answer when not told otherwise', () {
    final directory = BanAddressDirectory(
      MockClient((request) async => http.Response('{}', 200)),
    );

    expect(directory.timeout, const Duration(seconds: 15));
  });
}
