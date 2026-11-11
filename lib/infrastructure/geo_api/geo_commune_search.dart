import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/commune_answer.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/mappers/commune_search_mapper.dart';

/// The [CommuneSearch] backed by the `communes` API of geo.api.gouv.fr
/// (PLAN §9): no key, one GET per search.
///
/// Like `BanAddressDirectory`, this class only builds the request; the
/// transport and its failures are `getCommunes`, reading the JSON is the
/// job of `mappers/commune_search_mapper.dart`.
final class GeoCommuneSearch implements CommuneSearch {
  /// [client] is given so tests can pass a `MockClient` and the composition
  /// root shares one client across services.
  GeoCommuneSearch(
    http.Client client, {
    this.timeout = defaultTimeout,
    this.maxAnswerBytes = defaultMaxAnswerBytes,
  }) : _client = client;

  /// The answer is a few hundred bytes: beyond this wait, the user is better
  /// told there is no network than left looking at a spinner.
  static const defaultTimeout = Duration(seconds: 10);

  /// The longest answer read: five communes are a few kilobytes, so far
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
  ) =>
      // `boost=population` puts the large towns first, so « Villefranche »
      // suggests the one most people mean; five fit on the screen above the
      // keyboard. `centre` is where the map of a tournée covering the
      // commune starts (PLAN §5.4).
      getCommunes(
        _client,
        Uri.https('geo.api.gouv.fr', '/communes', {
          'nom': name,
          'fields': 'nom,code,codesPostaux,centre',
          'boost': 'population',
          'limit': '5',
        }),
        timeout: timeout,
        maxBytes: maxAnswerBytes,
        read: communeMatchesFromJson,
      );
}
