import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';

/// The communes suggested under the « Commune » field of the import screen
/// as the user types. Needs the network.
final class SearchCommunes {
  const SearchCommunes(this._search);

  final CommuneSearch _search;

  /// Below this many characters a name would match thousands of communes:
  /// nothing is suggested and the service is not asked.
  static const minLength = 2;

  /// The communes whose name looks like [text], trimmed; none, without
  /// asking, when it is shorter than [minLength].
  Future<Result<List<CommuneMatch>, CommuneSearchFailure>> call(
    String text,
  ) async {
    final name = text.trim();
    if (characterCount(name) < minLength) return const Ok([]);
    return _search.search(name);
  }
}
