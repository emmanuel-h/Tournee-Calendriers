import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';
import 'package:tournee_calendriers/infrastructure/overpass/mappers/overpass_mapper.dart';

/// The [StreetShapes] backed by the Overpass API of OpenStreetMap
/// (overpass-api.de, PLAN §9): no key, one query per street added.
///
/// Like `BanAddressDirectory`, this class only does the transport and turns
/// every way it can go wrong into a [StreetShapesFailure]; writing the
/// query and reading the answer is the job of `mappers/overpass_mapper.dart`.
final class OverpassStreetShapes implements StreetShapes {
  /// [client] is given so tests can pass a `MockClient` and the composition
  /// root shares one client across services.
  OverpassStreetShapes(http.Client client, {this.timeout = defaultTimeout})
    : _client = client;

  /// The server may work [overpassTimeoutSeconds] on the query; a few
  /// seconds more cover the trip on a weak mobile signal.
  static const defaultTimeout = Duration(seconds: 20);

  static final _interpreter = Uri.https('overpass-api.de', '/api/interpreter');

  final http.Client _client;

  /// How long a query waits for its answer before giving up.
  final Duration timeout;

  @override
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required StreetName name,
    required InseeCode commune,
  }) async {
    final http.Response response;
    try {
      // POSTed as a form field rather than put in the URL, as Overpass
      // advises for a long query (this one holds a long regular
      // expression). Giving a map as the body makes `http` encode it as
      // `application/x-www-form-urlencoded`.
      response = await _client
          .post(
            _interpreter,
            headers: {'User-Agent': appUserAgent, 'Accept': 'application/json'},
            body: {'data': overpassStreetQuery(name, commune)},
          )
          .timeout(timeout);
    } on TimeoutException {
      return const Err(StreetShapesFailure.noNetwork);
    } on http.ClientException {
      return const Err(StreetShapesFailure.noNetwork);
    } on IOException {
      return const Err(StreetShapesFailure.noNetwork);
    }

    // A busy server answers 429 (too many requests) or 504 (it gave up
    // waiting for a slot): a service error, worth trying again later.
    if (response.statusCode != HttpStatus.ok) {
      return const Err(StreetShapesFailure.serviceError);
    }
    try {
      // Overpass sends UTF-8 without saying so in its headers.
      return Ok(
        streetShapeFromJson(jsonDecode(utf8.decode(response.bodyBytes))),
      );
    } on FormatException {
      return const Err(StreetShapesFailure.serviceError);
    }
  }
}
