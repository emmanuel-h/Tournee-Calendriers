import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/commune_answer.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/mappers/commune_search_mapper.dart';

/// The [CommuneSearch] backed by the Géoplateforme geocoder asked for
/// municipalities (PLAN §9): the stand-in for geo.api.gouv.fr when it
/// fails (#137), behind `FallbackCommuneSearch`.
///
/// It gives one postcode per commune where geo.api.gouv.fr gives them all,
/// ranks by its own score rather than by population, and refuses a name of
/// fewer than three characters (a service error, so with the network up
/// the screen says the search is not possible for now).
final class GeopfCommuneSearch implements CommuneSearch {
  /// [client] is given so tests can pass a `MockClient` and the composition
  /// root shares one client across services.
  GeopfCommuneSearch(
    http.Client client, {
    this.timeout = defaultTimeout,
    this.maxAnswerBytes = defaultMaxAnswerBytes,
  }) : _client = client;

  /// As long as `GeoCommuneSearch`: the answer is a few kilobytes.
  static const defaultTimeout = Duration(seconds: 10);

  /// The longest answer read: as for `GeoCommuneSearch`, so far
  /// beyond is not a list of communes.
  static const defaultMaxAnswerBytes = 1 << 20;

  final http.Client _client;

  /// How long a search waits for its answer before giving up.
  final Duration timeout;

  /// How many bytes of an answer a search reads at most.
  final int maxAnswerBytes;

  @override
  Future<Result<List<CommuneMatch>, CommuneSearchFailure>> search(
    String name,
  ) => getCommunes(
    _client,
    Uri.https('data.geopf.fr', '/geocodage/search', {
      'q': name,
      'type': 'municipality',
      'limit': '5',
    }),
    timeout: timeout,
    maxBytes: maxAnswerBytes,
    read: communeMatchesFromGeocoderJson,
  );
}
