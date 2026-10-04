// Translation of the geo.api.gouv.fr `communes` answer (already decoded from
// JSON) into the values of the CommuneSearch port. A pure function, tested
// alone on the captured fixtures (test/fixtures/geo_api/).
//
// As for the BAN: a document of the wrong shape fails the whole call (the
// adapter turns the FormatException into a service error), while one
// unreadable entry is only left out, so the other suggestions still show.
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

final _postcodeShape = RegExp(r'^\d{5}$');

/// Reads the answer of `/communes?nom=…`: a list of `{nom, code,
/// codesPostaux}`, in the service's order.
///
/// An entry without a valid [Commune] (INSEE `code`, non-blank `nom`) is
/// left out; so is a postcode that is not five digits. A missing
/// `codesPostaux` means none.
///
/// Throws a [FormatException] when [json] is not a list.
List<CommuneMatch> communeMatchesFromJson(Object? json) {
  if (json is! List<Object?>) {
    throw const FormatException('Not a list of communes');
  }
  return [for (final entry in json) ?_match(entry)];
}

/// The commune of one entry, or null when it cannot be read.
CommuneMatch? _match(Object? entry) {
  if (entry case {'nom': final String name, 'code': final String code}) {
    return switch (Commune.create(inseeCode: code, name: name)) {
      Ok(:final value) => CommuneMatch(
        commune: value,
        postcodes: _postcodes(entry['codesPostaux']),
      ),
      Err() => null,
    };
  }
  return null;
}

/// The five-digit strings of [json] when it is a list; none otherwise.
List<String> _postcodes(Object? json) => [
  if (json is List<Object?>)
    for (final postcode in json)
      if (postcode is String && _postcodeShape.hasMatch(postcode)) postcode,
];
