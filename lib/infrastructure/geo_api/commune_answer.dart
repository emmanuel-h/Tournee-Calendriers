import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';
import 'package:tournee_calendriers/infrastructure/http/no_network.dart';

/// GETs [url] with [client] and reads the answer with [read], turning every
/// way it can go wrong into a [CommuneSearchFailure]: the transport shared
/// by `GeoCommuneSearch` and `GeopfCommuneSearch`, which only differ by
/// their URL and their JSON.
///
/// [read] throws a [FormatException] when the document is not what it
/// expects.
Future<Result<List<CommuneMatch>, CommuneSearchFailure>> getCommunes(
  http.Client client,
  Uri url, {
  required Duration timeout,
  required List<CommuneMatch> Function(Object? json) read,
}) async {
  final http.Response response;
  try {
    response = await client
        .get(
          url,
          headers: {'User-Agent': appUserAgent, 'Accept': 'application/json'},
        )
        .timeout(timeout);
  } on TimeoutException {
    return const Err(CommuneSearchFailure.noNetwork);
  } on http.ClientException catch (error) {
    // What `http` throws when the connection fails (it wraps the socket
    // error).
    return Err(_transportFailure(error));
  } on IOException catch (error) {
    // A socket or TLS error that reached us unwrapped.
    return Err(_transportFailure(error));
  }

  // Even an unknown name answers 200 with no commune: any other status is
  // the service failing.
  if (response.statusCode != HttpStatus.ok) {
    return const Err(CommuneSearchFailure.serviceError);
  }
  try {
    // Decoded from the bytes, so « Saône » survives a missing charset.
    return Ok(read(jsonDecode(utf8.decode(response.bodyBytes))));
  } on FormatException {
    return const Err(CommuneSearchFailure.serviceError);
  }
}

/// No network only when the phone found no way out; a service that refused
/// or cut the connection is a service error (#137).
CommuneSearchFailure _transportFailure(Object error) => meansNoNetwork(error)
    ? CommuneSearchFailure.noNetwork
    : CommuneSearchFailure.serviceError;
