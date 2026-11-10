import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// A [CommuneSearch] that asks a second search only when the first fails
/// (#137: geo.api.gouv.fr refused connections for a minute while the
/// Géoplateforme answered). Composed in `bootstrap/` from
/// `GeoCommuneSearch` then `GeopfCommuneSearch`; the screens see one port.
final class FallbackCommuneSearch implements CommuneSearch {
  const FallbackCommuneSearch(this.first, this.then);

  /// The search asked first, every time.
  final CommuneSearch first;

  /// The search asked only when [first] fails.
  final CommuneSearch then;

  @override
  Future<Result<List<CommuneMatch>, CommuneSearchFailure>> search(
    String name,
  ) async {
    final answer = await first.search(name);
    if (answer case Err(failure: final firstFailure)) {
      return switch (await then.search(name)) {
        Ok() && final found => found,
        // No network only when neither reached a working connection: if one
        // did, the phone has a network and a service is down.
        Err(failure: final thenFailure) =>
          firstFailure == CommuneSearchFailure.noNetwork &&
                  thenFailure == CommuneSearchFailure.noNetwork
              ? const Err(CommuneSearchFailure.noNetwork)
              : const Err(CommuneSearchFailure.serviceError),
      };
    }
    return answer;
  }
}
