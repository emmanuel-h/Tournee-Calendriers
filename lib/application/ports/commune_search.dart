import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// Finds French communes by name, as the « Commune » field of the import
/// screen suggests them while the user types (« Villefranche » →
/// Villefranche-sur-Saône (69400), …).
///
/// An outbound port: an adapter in `infrastructure/geo_api/` implements it
/// over HTTP (geo.api.gouv.fr, PLAN §9), tests use a fake. Every call needs
/// the network; a failure comes back as an [Err] holding a
/// [CommuneSearchFailure], never as an exception.
abstract interface class CommuneSearch {
  /// The communes whose name looks like [name], most populated first, at
  /// most a handful. An empty list when none does.
  Future<Result<List<CommuneMatch>, CommuneSearchFailure>> search(String name);
}

/// Why the [CommuneSearch] could not answer. The import screen says each
/// in French.
enum CommuneSearchFailure {
  /// The phone could not reach the service, or it did not answer in time.
  noNetwork,

  /// The service answered with an error or with something unreadable.
  serviceError,
}

/// A commune the [CommuneSearch] found, with its postcodes so two communes
/// of the same name can be told apart (« Villefranche-sur-Saône (69400) »).
final class CommuneMatch {
  /// [postcodes] is copied, so changing the list given here afterwards does
  /// not change this value.
  CommuneMatch({required this.commune, required List<String> postcodes})
    : postcodes = List.unmodifiable(postcodes);

  final Commune commune;

  /// The five-digit postcodes of the commune, in the service's order;
  /// several for a large town, possibly none. Read-only.
  final List<String> postcodes;

  @override
  bool operator ==(Object other) =>
      other is CommuneMatch &&
      other.commune == commune &&
      sameItems(other.postcodes, postcodes);

  @override
  int get hashCode => Object.hash(commune, Object.hashAll(postcodes));

  @override
  String toString() => 'CommuneMatch(${commune.name}, $postcodes)';
}
