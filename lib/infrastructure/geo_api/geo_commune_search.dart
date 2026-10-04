import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/mappers/commune_search_mapper.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';

/// The [CommuneSearch] backed by the `communes` API of geo.api.gouv.fr
/// (PLAN §9): no key, one GET per search.
///
/// Like `BanAddressDirectory`, this class only does the transport and turns
/// every way it can go wrong into a [CommuneSearchFailure]; reading the
/// JSON is the job of `mappers/commune_search_mapper.dart`.
final class GeoCommuneSearch implements CommuneSearch {
  /// [client] is given so tests can pass a `MockClient` and the composition
  /// root shares one client across services.
  GeoCommuneSearch(http.Client client, {this.timeout = defaultTimeout})
    : _client = client;

  /// The answer is a few hundred bytes: beyond this wait, the user is better
  /// told there is no network than left looking at a spinner.
  static const defaultTimeout = Duration(seconds: 10);

  final http.Client _client;

  /// How long a search waits for its answer before giving up.
  final Duration timeout;

  @override
  Future<Result<List<CommuneMatch>, CommuneSearchFailure>> search(
    String name,
  ) async {
    // `boost=population` puts the large towns first, so « Villefranche »
    // suggests the one most people mean; five fit on the screen above the
    // keyboard.
    final url = Uri.https('geo.api.gouv.fr', '/communes', {
      'nom': name,
      'fields': 'nom,code,codesPostaux',
      'boost': 'population',
      'limit': '5',
    });

    final http.Response response;
    try {
      response = await _client
          .get(
            url,
            headers: {'User-Agent': appUserAgent, 'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on TimeoutException {
      return const Err(CommuneSearchFailure.noNetwork);
    } on http.ClientException {
      return const Err(CommuneSearchFailure.noNetwork);
    } on IOException {
      return const Err(CommuneSearchFailure.noNetwork);
    }

    // Even an unknown name answers 200 with `[]`: any other status is the
    // service failing.
    if (response.statusCode != HttpStatus.ok) {
      return const Err(CommuneSearchFailure.serviceError);
    }
    try {
      // Decoded from the bytes, so « Saône » survives a missing charset.
      return Ok(
        communeMatchesFromJson(jsonDecode(utf8.decode(response.bodyBytes))),
      );
    } on FormatException {
      return const Err(CommuneSearchFailure.serviceError);
    }
  }
}
