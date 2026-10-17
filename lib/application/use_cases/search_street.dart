import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// The search box of « Ajouter des rues » (PLAN §5.4): the streets whose
/// name looks like the text typed, in the communes of the tournée. Needs
/// the network.
///
/// A tournée may cover several communes (#78): each is asked in turn, and
/// the results follow the order of the communes, each commune's best
/// first. Until the tournée stores its communes, the caller passes them.
final class SearchStreet {
  const SearchStreet(this._directory);

  final AddressDirectory _directory;

  /// The streets of [communes] whose name looks like [text]; none, without
  /// asking, when there is no commune. A text too short or too long finds
  /// nothing either, without a request (`AddressDirectory.searchStreets`).
  ///
  /// The first commune that fails fails the search: offline, the next
  /// would fail too, each after its own timeout.
  Future<Result<List<StreetMatch>, AddressDirectoryFailure>> call(
    String text, {
    required Iterable<InseeCode> communes,
  }) async {
    final found = <StreetMatch>[];
    final seen = <BanStreetId>{};
    for (final commune in communes) {
      switch (await _directory.searchStreets(text, commune: commune)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final matches):
          // `add` answers whether the id was new: a street a neighbouring
          // commune's search gives again is listed once.
          found.addAll(matches.where((match) => seen.add(match.id)));
      }
    }
    return Ok(List.unmodifiable(found));
  }
}
