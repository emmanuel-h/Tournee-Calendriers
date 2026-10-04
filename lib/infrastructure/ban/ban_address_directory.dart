import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/ban/mappers/ban_lookup_mapper.dart';

/// The [AddressDirectory] backed by the BAN `lookup` API of
/// plateforme.adresse.data.gouv.fr (PLAN §9): no key, one GET per call.
///
/// This class only does the transport (URL, headers, timeout, status code)
/// and turns every way it can go wrong into an [AddressDirectoryFailure];
/// reading the JSON is the job of the pure functions in
/// `mappers/ban_lookup_mapper.dart`.
final class BanAddressDirectory implements AddressDirectory {
  /// [client] is given rather than created here so tests can pass a
  /// `MockClient`, and so the composition root decides when it is closed.
  BanAddressDirectory(http.Client client, {this.timeout = defaultTimeout})
    : _client = client;

  /// How long to wait for a whole answer. A large commune's list is about
  /// 70 kB, a long street's numbers 200 kB: a few seconds on a weak mobile
  /// signal. Beyond this, the user is better told there is no network.
  static const defaultTimeout = Duration(seconds: 15);

  /// Public services ask callers to say who they are, so a misbehaving
  /// client can be identified and contacted rather than blocked.
  static const userAgent =
      'TourneeCalendriers/1.0 '
      '(+https://github.com/emmanuel-h/Tournee-Calendriers)';

  static const _host = 'plateforme.adresse.data.gouv.fr';

  final http.Client _client;

  /// How long this directory waits for an answer before giving up.
  final Duration timeout;

  @override
  Future<Result<CommuneStreets, AddressDirectoryFailure>> streetsOf(
    String inseeCode,
  ) => _lookup(inseeCode, communeStreetsFromJson);

  @override
  Future<Result<StreetNumbers, AddressDirectoryFailure>> numbersOf(
    BanStreetId street,
  ) => _lookup(street.value, streetNumbersFromJson);

  /// GETs `/lookup/[id]` and reads the answer with [read], which throws a
  /// [FormatException] when the document is not what it expects.
  Future<Result<T, AddressDirectoryFailure>> _lookup<T>(
    String id,
    T Function(Object? json) read,
  ) async {
    // `pathSegments` percent-encodes each segment, so an id holding a `/`
    // cannot reach another path of the service.
    final url = Uri(scheme: 'https', host: _host, pathSegments: ['lookup', id]);

    final http.Response response;
    try {
      response = await _client
          .get(
            url,
            headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on TimeoutException {
      return const Err(AddressDirectoryFailure.noNetwork);
    } on http.ClientException {
      // What `http` throws when the connection fails (it wraps the socket
      // error).
      return const Err(AddressDirectoryFailure.noNetwork);
    } on IOException {
      // A socket or TLS error that reached us unwrapped.
      return const Err(AddressDirectoryFailure.noNetwork);
    }

    if (response.statusCode == HttpStatus.notFound) {
      return const Err(AddressDirectoryFailure.notFound);
    }
    if (response.statusCode != HttpStatus.ok) {
      return const Err(AddressDirectoryFailure.serviceError);
    }
    try {
      // The BAN sends UTF-8. Decoding the bytes ourselves does not depend
      // on a charset in the headers (without one, `response.body` would
      // read Latin-1 and garble « Allée »).
      return Ok(read(jsonDecode(utf8.decode(response.bodyBytes))));
    } on FormatException {
      // Not UTF-8, not JSON, or not the expected document.
      return const Err(AddressDirectoryFailure.serviceError);
    }
  }
}
